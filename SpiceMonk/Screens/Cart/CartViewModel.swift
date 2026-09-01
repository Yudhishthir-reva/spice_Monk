//
//  CartViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

/// Shared cart. `POST customer/cart/add` **sets** `qty` (it does not increment), so every add
/// from a card or product page sends the target total, not `1`.
final class CartStore: ObservableObject {

    static let shared = CartStore()

    @Published var items: [CartItem] = []
    @Published var summary: CartSummary = .empty
    @Published var charges: [CartCharge] = []
    @Published var couponDiscount: Double = 0
    @Published var deliveryInfo: CartDeliveryInfo? = nil
    @Published var grandTotal: Double = 0
    @Published var appliedCoupon: AppliedCouponData? = nil
    @Published var paymentMethod: PaymentMethod = .cod
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var loadError: String?
    @Published var toastMessage = ""
    @Published var isShowToastView = false
    @Published var isClearing = false
    @Published var isRepeatingOrder = false
    @Published private var mutationTick = 0

    private var didLoadOnce = false
    private var pendingAfterLoad: [() -> Void] = []
    private var removingIds = Set<Int>()
    private var updatingIds = Set<Int>()
    private var addingKeys = Set<String>()
    private var pendingAddKeys = Set<String>()
    private var pendingOptimisticQty: [String: Int] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var pendingQtyTimers: [String: DispatchWorkItem] = [:]
    private var pendingAddTapCount: [String: Int] = [:]
    private let qtyDebounceInterval: TimeInterval = 0.35
    private let debounceQueue = DispatchQueue.main
    var serviceManagable = CartServiceManager()

    var isEmpty: Bool { items.isEmpty && pendingOptimisticQty.isEmpty }

    /// Item count including optimistic first-add taps not yet on the server.
    var displayItemCount: Int {
        items.reduce(0) { $0 + $1.qty } + pendingOptimisticQty.values.reduce(0, +)
    }

    /// Customer subtotal from local line items (reflects optimistic qty patches).
    var displayCustomerTotal: Double {
        items.reduce(0) { $0 + $1.subtotal }
    }

    private init() {}

    func line(productId: Int, variantId: Int) -> CartItem? {
        items.first { $0.productId == productId && $0.variantId == variantId }
    }

    func quantity(productId: Int, variantId: Int) -> Int {
        let key = Self.key(productId: productId, variantId: variantId)
        let base = line(productId: productId, variantId: variantId)?.qty ?? 0
        if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
            return base
        }
        return base + (pendingOptimisticQty[key] ?? 0)
    }

    func isBusy(productId: Int, variantId: Int) -> Bool {
        _ = mutationTick
        guard let cartId = line(productId: productId, variantId: variantId)?.cartId, cartId > 0 else {
            let key = Self.key(productId: productId, variantId: variantId)
            return addingKeys.contains(key)
        }
        return updatingIds.contains(cartId) || removingIds.contains(cartId)
    }

    func canIncrement(productId: Int, variantId: Int, availableQty: Int) -> Bool {
        let qty = quantity(productId: productId, variantId: variantId)
        var limit = Int.max
        if availableQty > 0 { limit = min(limit, availableQty) }
        if let maxQty = line(productId: productId, variantId: variantId)?.maxOrderQty, maxQty > 0 {
            limit = min(limit, maxQty)
        }
        return qty < limit
    }

    /// Catalog + stepper: debounced first-add, or debounced `changeQty` when the line already exists.
    func incrementOrAdd(productId: Int, variantId: Int, availableQty: Int, maxOrderQty: Int? = nil) {
        runWhenReady { [weak self] in
            guard let self else { return }
            if let item = self.line(productId: productId, variantId: variantId), item.cartId > 0 {
                self.changeQty(item, by: 1)
            } else {
                self.addOrIncrement(
                    productId: productId,
                    variantId: variantId,
                    availableQty: availableQty,
                    maxOrderQty: maxOrderQty
                )
            }
        }
    }

    func isRemoving(_ item: CartItem) -> Bool {
        _ = mutationTick
        return removingIds.contains(item.cartId)
    }

    func isUpdating(_ item: CartItem) -> Bool {
        _ = mutationTick
        return updatingIds.contains(item.cartId)
    }

    func loadIfNeeded() {
        guard !didLoadOnce, !isLoading else { return }
        load()
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        fetch()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        fetch()
    }

    func reset() {
        cancellables.removeAll()
        pendingAfterLoad.removeAll()
        items = []
        summary = .empty
        charges = []
        couponDiscount = 0
        deliveryInfo = nil
        grandTotal = 0
        appliedCoupon = nil
        paymentMethod = .cod
        isLoading = false
        isRefreshing = false
        loadError = nil
        isClearing = false
        isRepeatingOrder = false
        didLoadOnce = false
        removingIds.removeAll()
        updatingIds.removeAll()
        addingKeys.removeAll()
        pendingAddKeys.removeAll()
        pendingOptimisticQty.removeAll()
        pendingQtyTimers.values.forEach { $0.cancel() }
        pendingQtyTimers.removeAll()
        pendingAddTapCount.removeAll()
        bump()
    }

    func placeOrder(addressId: Int, notes: String = "Please call before delivery") {
        guard !isClearing && !isLoading else { return }
        isLoading = true

        let apiPaymentType = paymentMethod == .cod ? "cod" : "prepaid"
        let couponCode = appliedCoupon?.code
        OrderServiceManager().placeOrder(addressId: addressId, paymentType: apiPaymentType, notes: notes, couponCode: couponCode)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    self.isShowToastView = true
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status == true, let placedData = response.data {
                    if apiPaymentType == "cod" {
                        self.toastMessage = response.message ?? "Order placed successfully!"
                        self.isShowToastView = true
                        
                        // Clear cart
                        self.items = []
                        self.summary = .empty
                        self.appliedCoupon = nil
                        self.paymentMethod = .cod
                        
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OrderPlacedSuccessfully"),
                            object: placedData
                        )
                    } else {
                        // Prepaid flow: initiate payment!
                        self.initiatePaymentFlow(placedData: placedData)
                    }
                } else {
                    self.toastMessage = response.message ?? "Could not place order."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }

    private func initiatePaymentFlow(placedData: OrderPlaceData) {
        isLoading = true
        OrderServiceManager().initiatePayment(orderId: placedData.orderId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    self.isShowToastView = true
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status == true, let initiateData = response.data {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OrderInitiatedPrepaidPayment"),
                        object: initiateData,
                        userInfo: ["orderPlaceData": placedData]
                    )
                } else {
                    self.toastMessage = response.message ?? "Payment initiation failed."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }

    func clearCartAfterPrepaidSuccess() {
        self.items = []
        self.summary = .empty
        self.charges = []
        self.couponDiscount = 0
        self.deliveryInfo = nil
        self.grandTotal = 0
        self.appliedCoupon = nil
        self.paymentMethod = .cod
    }

    /// First add sends `qty: 1`. Later taps send the new total (`2`, `3`, …) via update when we
    /// already have a `cart_id`, or via add if we only know product + variant.
    /// Debounced so rapid taps on the same product collapse into a single API call.
    func addOrIncrement(productId: Int, variantId: Int, availableQty: Int, maxOrderQty: Int? = nil) {
        let key = Self.key(productId: productId, variantId: variantId)

        runWhenReady { [weak self] in
            guard let self = self else { return }

            let current = self.quantity(productId: productId, variantId: variantId)
            let effectiveMax = maxOrderQty ?? self.line(productId: productId, variantId: variantId)?.maxOrderQty

            if availableQty > 0, current >= availableQty {
                self.toastMessage = "Only \(availableQty) units available in stock."
                self.isShowToastView = true
                return
            }
            if let maxQty = effectiveMax, maxQty > 0, current >= maxQty {
                self.toastMessage = "Maximum limit for this item is \(maxQty) units."
                self.isShowToastView = true
                return
            }

            self.pendingQtyTimers[key]?.cancel()
            self.pendingAddTapCount[key, default: 0] += 1
            self.pendingAddKeys.insert(key)

            let optimisticQty = current + 1
            if let item = self.line(productId: productId, variantId: variantId), item.cartId > 0 {
                self.patch(cartId: item.cartId) { $0.setQty(optimisticQty) }
                self.syncSummaryFromItems()
            } else {
                self.pendingOptimisticQty[key] = (self.pendingOptimisticQty[key] ?? 0) + 1
            }
            self.bump()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.pendingQtyTimers[key] = nil
                self.pendingAddKeys.remove(key)
                let count = self.pendingAddTapCount[key] ?? 0
                self.pendingAddTapCount[key] = nil
                guard count > 0 else { return }
                self.performAddOrIncrement(
                    productId: productId,
                    variantId: variantId,
                    availableQty: availableQty,
                    maxOrderQty: effectiveMax,
                    tapCount: count
                )
            }
            self.pendingQtyTimers[key] = workItem
            self.debounceQueue.asyncAfter(deadline: .now() + self.qtyDebounceInterval, execute: workItem)
        }
    }

    func decrement(productId: Int, variantId: Int) {
        runWhenReady { [weak self] in
            guard let self, let item = self.line(productId: productId, variantId: variantId) else { return }
            self.changeQty(item, by: -1)
        }
    }

    /// Optimistically updates the local qty and debounces the API call.
    /// Rapid +/- taps on the same item collapse into a single network request with the final qty.
    func changeQty(_ item: CartItem, by delta: Int) {
        guard let current = line(productId: item.productId, variantId: item.variantId),
              current.cartId == item.cartId else { return }
        let next = current.qty + delta
        if next < 1 {
            debouncedRemove(item)
            return
        }
        if current.availableQty > 0, next > current.availableQty {
            toastMessage = "Only \(current.availableQty) units available in stock."
            isShowToastView = true
            return
        }
        if let maxQty = current.maxOrderQty, maxQty > 0, next > maxQty {
            toastMessage = "Maximum limit for this item is \(maxQty) units."
            isShowToastView = true
            return
        }

        // Optimistic local update
        patch(cartId: current.cartId) { $0.setQty(next) }
        syncSummaryFromItems()
        bump()

        // Debounce the API call
        let key = String(current.cartId)
        pendingQtyTimers[key]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingQtyTimers[key] = nil
            if let latest = self.line(productId: current.productId, variantId: current.variantId),
               latest.cartId == current.cartId {
                self.updateQty(latest, qty: latest.qty)
            }
        }
        pendingQtyTimers[key] = workItem
        debounceQueue.asyncAfter(deadline: .now() + qtyDebounceInterval, execute: workItem)
    }

    private func debouncedRemove(_ item: CartItem) {
        guard item.cartId > 0, !removingIds.contains(item.cartId) else { return }

        let key = String(item.cartId)
        pendingQtyTimers[key]?.cancel()
        pendingQtyTimers[key] = nil

        // Optimistic local removal
        removingIds.insert(item.cartId)
        bump()
        let snapshot = items
        items.removeAll { $0.cartId == item.cartId }
        if items.isEmpty { summary = .empty }

        serviceManagable.removeFromCart(cartId: item.cartId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.removingIds.remove(item.cartId)
                self.bump()
                guard case .failure(let error) = completion else { return }
                self.items = snapshot
                self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                self.isShowToastView = true
                self.load()
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.removingIds.remove(item.cartId)
                self.bump()
                if response.status == true {
                    self.toastMessage = response.message ?? "Item removed from cart."
                    self.isShowToastView = true
                    if self.items.isEmpty {
                        self.summary = .empty
                    } else {
                        self.refresh()
                    }
                } else {
                    self.items = snapshot
                    self.toastMessage = response.message ?? "Could not remove this item."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }

    func clear() {
        guard !isClearing, !items.isEmpty else { return }
        isClearing = true
        pendingQtyTimers.values.forEach { $0.cancel() }
        pendingQtyTimers.removeAll()
        pendingAddTapCount.removeAll()
        pendingAddKeys.removeAll()
        pendingOptimisticQty.removeAll()
        let snapshot = items
        let snapshotSummary = summary
        items = []
        summary = .empty

        serviceManagable.clearCart()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isClearing = false
                guard case .failure(let error) = completion else { return }
                self.items = snapshot
                self.summary = snapshotSummary
                self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                self.isShowToastView = true
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isClearing = false
                if response.status == true {
                    self.items = []
                    self.summary = .empty
                    self.charges = []
                    self.couponDiscount = 0
                    self.deliveryInfo = nil
                    self.grandTotal = 0
                    self.appliedCoupon = nil
                    self.paymentMethod = .cod
                    self.toastMessage = response.message ?? "Cart cleared successfully."
                } else {
                    self.items = snapshot
                    self.summary = snapshotSummary
                    self.toastMessage = response.message ?? "Could not clear the cart."
                }
                self.isShowToastView = true
            }
            .store(in: &cancellables)
    }

    private func performAddOrIncrement(
        productId: Int,
        variantId: Int,
        availableQty: Int,
        maxOrderQty: Int? = nil,
        tapCount: Int = 1
    ) {
        let key = Self.key(productId: productId, variantId: variantId)
        let current = quantity(productId: productId, variantId: variantId)
        let target = current > 0 ? current : tapCount
        let effectiveMax = maxOrderQty ?? line(productId: productId, variantId: variantId)?.maxOrderQty

        if availableQty > 0, target > availableQty {
            pendingOptimisticQty[key] = nil
            toastMessage = "Only \(availableQty) units available in stock."
            isShowToastView = true
            if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
                patch(cartId: item.cartId) { $0.setQty(min(current, availableQty)) }
                bump()
            }
            return
        }
        if let maxQty = effectiveMax, maxQty > 0, target > maxQty {
            pendingOptimisticQty[key] = nil
            toastMessage = "Maximum limit for this item is \(maxQty) units."
            isShowToastView = true
            if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
                patch(cartId: item.cartId) { $0.setQty(min(current, maxQty)) }
                bump()
            }
            return
        }
        if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
            updateQty(item, qty: target)
        } else {
            add(productId: productId, variantId: variantId, qty: max(target, 1))
        }
    }

    private func add(productId: Int, variantId: Int, qty: Int) {
        let key = Self.key(productId: productId, variantId: variantId)
        if addingKeys.contains(key) {
            schedulePendingAddSync(productId: productId, variantId: variantId)
            return
        }
        addingKeys.insert(key)
        bump()

        serviceManagable.addToCart(productId: productId, variantId: variantId, qty: qty)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.addingKeys.remove(key)
                self.bump()
                guard case .failure(let error) = completion else { return }
                self.pendingOptimisticQty[key] = nil
                self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                self.isShowToastView = true
                self.load()
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.addingKeys.remove(key)
                self.bump()
                let desiredQty = self.quantity(productId: productId, variantId: variantId)
                if response.status == true {
                    if let added = response.item {
                        self.upsert(added)
                    }
                    self.pendingOptimisticQty[key] = nil
                    self.reconcileLocalQty(
                        productId: productId,
                        variantId: variantId,
                        desiredQty: desiredQty
                    )
                } else {
                    self.pendingOptimisticQty[key] = nil
                    self.toastMessage = response.message ?? "Unable to add this product."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }

    private func updateQty(_ item: CartItem, qty: Int) {
        guard item.cartId > 0, !removingIds.contains(item.cartId) else { return }
        if updatingIds.contains(item.cartId) {
            schedulePendingQtySync(for: item)
            return
        }
        updatingIds.insert(item.cartId)
        bump()
        let snapshot = items

        serviceManagable.updateCart(cartId: item.cartId, qty: qty)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.updatingIds.remove(item.cartId)
                self.bump()
                guard case .failure(let error) = completion else { return }
                self.items = snapshot
                self.syncSummaryFromItems()
                self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                self.isShowToastView = true
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.updatingIds.remove(item.cartId)
                self.bump()
                let desiredQty = self.line(productId: item.productId, variantId: item.variantId)?.qty ?? qty
                if response.status == true {
                    if let updated = response.item {
                        self.upsert(updated)
                    }
                    self.reconcileLocalQty(
                        productId: item.productId,
                        variantId: item.variantId,
                        desiredQty: desiredQty
                    )
                } else {
                    self.items = snapshot
                    self.syncSummaryFromItems()
                    self.toastMessage = response.message ?? "Could not update quantity."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }

    private func upsert(_ added: CartAddItem) {
        if let index = indexOf(productId: added.productId, variantId: added.variantId, cartId: added.cartId) {
            let existing = items[index]
            items[index] = CartItem(
                from: added,
                productName: existing.productName,
                productImage: existing.productImage,
                variantName: existing.variantName
            )
        } else {
            items.insert(CartItem(from: added), at: 0)
        }
    }

    private func indexOf(productId: Int, variantId: Int, cartId: Int) -> Int? {
        if cartId > 0, let index = items.firstIndex(where: { $0.cartId == cartId }) {
            return index
        }
        return items.firstIndex { $0.productId == productId && $0.variantId == variantId }
    }

    private func patch(cartId: Int, _ body: (inout CartItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.cartId == cartId }) else { return }
        body(&items[index])
    }

    private func runWhenReady(_ action: @escaping () -> Void) {
        if didLoadOnce {
            action()
            return
        }
        pendingAfterLoad.append(action)
        if !isLoading {
            load()
        }
    }

    struct RepeatOrderItem {
        let productId: Int
        let variantId: Int
        let qty: Int
    }

    /// Adds order items to cart sequentially, bypassing debounce. Calls `completion` on the main queue.
    func repeatOrder(items: [RepeatOrderItem], completion: @escaping (Int, String?) -> Void) {
        guard !isRepeatingOrder else { return }
        isRepeatingOrder = true

        runWhenReady { [weak self] in
            self?.processRepeatOrder(items: items, index: 0, addedCount: 0, completion: completion)
        }
    }

    private func processRepeatOrder(
        items: [RepeatOrderItem],
        index: Int,
        addedCount: Int,
        completion: @escaping (Int, String?) -> Void
    ) {
        guard index < items.count else {
            isRepeatingOrder = false
            refresh()
            completion(addedCount, nil)
            return
        }

        let orderItem = items[index]
        let current = quantity(productId: orderItem.productId, variantId: orderItem.variantId)
        let target = current + orderItem.qty

        if let line = line(productId: orderItem.productId, variantId: orderItem.variantId), line.cartId > 0 {
            setQtyDirect(line, qty: target) { [weak self] success in
                guard let self else { return }
                self.processRepeatOrder(
                    items: items,
                    index: index + 1,
                    addedCount: addedCount + (success ? 1 : 0),
                    completion: completion
                )
            }
        } else {
            addDirect(productId: orderItem.productId, variantId: orderItem.variantId, qty: target) { [weak self] success in
                guard let self else { return }
                self.processRepeatOrder(
                    items: items,
                    index: index + 1,
                    addedCount: addedCount + (success ? 1 : 0),
                    completion: completion
                )
            }
        }
    }

    private func addDirect(productId: Int, variantId: Int, qty: Int, completion: @escaping (Bool) -> Void) {
        serviceManagable.addToCart(productId: productId, variantId: variantId, qty: qty)
            .receive(on: RunLoop.main)
            .sink { result in
                if case .failure = result {
                    completion(false)
                }
            } receiveValue: { [weak self] response in
                guard let self else {
                    completion(false)
                    return
                }
                if response.status == true {
                    if let added = response.item {
                        self.upsert(added)
                    }
                    completion(true)
                } else {
                    completion(false)
                }
            }
            .store(in: &cancellables)
    }

    private func setQtyDirect(_ item: CartItem, qty: Int, completion: @escaping (Bool) -> Void) {
        guard item.cartId > 0 else {
            completion(false)
            return
        }
        serviceManagable.updateCart(cartId: item.cartId, qty: qty)
            .receive(on: RunLoop.main)
            .sink { result in
                if case .failure = result {
                    completion(false)
                }
            } receiveValue: { [weak self] response in
                guard let self else {
                    completion(false)
                    return
                }
                if response.status == true {
                    if let updated = response.item {
                        self.upsert(updated)
                    }
                    completion(true)
                } else {
                    completion(false)
                }
            }
            .store(in: &cancellables)
    }

    private func fetch() {
        serviceManagable.fetchCart()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false
                guard case .failure(let error) = completion else { return }
                let message = (error as? RequestError)?.errorString ?? error.localizedDescription
                if self.items.isEmpty {
                    self.loadError = message
                } else {
                    self.toastMessage = message
                    self.isShowToastView = true
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false
                self.didLoadOnce = true
                self.items = response.items.filter { $0.productId > 0 }
                self.summary = response.summary
                self.charges = response.charges
                self.couponDiscount = response.couponDiscount
                self.deliveryInfo = response.deliveryInfo
                self.grandTotal = response.grandTotal
                if let coupon = response.coupon {
                    self.appliedCoupon = coupon
                } else {
                    self.appliedCoupon = nil
                }
                self.loadError = nil
                if self.appliedCoupon != nil {
                    self.validateAppliedCoupon()
                }
                let pending = self.pendingAfterLoad
                self.pendingAfterLoad.removeAll()
                pending.forEach { $0() }
            }
            .store(in: &cancellables)
    }

    func removeCoupon() {
        guard appliedCoupon != nil else { return }
        serviceManagable.removeCoupon()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case .failure(let error) = completion {
                    self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    self.isShowToastView = true
                    self.refresh()
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status == true {
                    self.appliedCoupon = nil
                    self.couponDiscount = 0
                    self.toastMessage = response.message ?? "Coupon removed successfully."
                    self.isShowToastView = true
                    self.refresh()
                } else {
                    self.toastMessage = response.message ?? "Could not remove coupon."
                    self.isShowToastView = true
                    self.refresh()
                }
            }
            .store(in: &cancellables)
    }

    func validateAppliedCoupon() {
        guard let coupon = appliedCoupon else { return }
        serviceManagable.validateCoupon(couponId: coupon.couponId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    // If network fails during background validation, retain existing state
                    #if DEBUG
                    print("Coupon validation failed: \(error)")
                    #endif
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status == true {
                    if response.discountAmount != coupon.discountAmount {
                        self.appliedCoupon = coupon.updating(discountAmount: response.discountAmount)
                    }
                } else {
                    self.appliedCoupon = nil
                    self.toastMessage = response.message ?? "Coupon is no longer valid for your updated cart."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }

    private func bump() {
        mutationTick += 1
    }

    private func syncSummaryFromItems() {
        var totalItems = 0
        var totalMrp = 0.0
        var totalCustomer = 0.0
        for item in items {
            totalItems += item.qty
            totalMrp += item.mrp * Double(item.qty)
            totalCustomer += item.subtotal
        }
        summary = CartSummary(
            totalItems: totalItems,
            totalMrp: totalMrp,
            totalCustomerPrice: totalCustomer,
            totalSavings: max(totalMrp - totalCustomer, 0)
        )
    }

    private func schedulePendingQtySync(for item: CartItem) {
        let key = String(item.cartId)
        pendingQtyTimers[key]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingQtyTimers[key] = nil
            if let latest = self.line(productId: item.productId, variantId: item.variantId),
               latest.cartId == item.cartId {
                self.updateQty(latest, qty: latest.qty)
            }
        }
        pendingQtyTimers[key] = workItem
        debounceQueue.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func schedulePendingAddSync(productId: Int, variantId: Int) {
        let key = Self.key(productId: productId, variantId: variantId)
        pendingQtyTimers[key]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingQtyTimers[key] = nil
            let target = self.quantity(productId: productId, variantId: variantId)
            guard target > 0 else { return }
            if let line = self.line(productId: productId, variantId: variantId), line.cartId > 0 {
                self.updateQty(line, qty: target)
            } else {
                self.add(productId: productId, variantId: variantId, qty: target)
            }
        }
        pendingQtyTimers[key] = workItem
        debounceQueue.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func reconcileLocalQty(productId: Int, variantId: Int, desiredQty: Int) {
        guard let line = line(productId: productId, variantId: variantId), line.cartId > 0 else {
            syncSummaryFromItems()
            return
        }
        if line.qty < desiredQty {
            patch(cartId: line.cartId) { $0.setQty(desiredQty) }
            syncSummaryFromItems()
            bump()
            let timerKey = String(line.cartId)
            if pendingQtyTimers[timerKey] == nil,
               let latest = self.line(productId: productId, variantId: variantId) {
                updateQty(latest, qty: desiredQty)
            }
        } else {
            syncSummaryFromItems()
        }
    }

    private static func key(productId: Int, variantId: Int) -> String {
        "\(productId)-\(variantId)"
    }
}

private struct CartStoreToastModifier: ViewModifier {
    @ObservedObject var cart = CartStore.shared

    func body(content: Content) -> some View {
        content.toast(isPresenting: $cart.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: cart.toastMessage)
        }, onTap: nil, completion: nil)
    }
}

extension View {
    func cartStoreToast() -> some View {
        modifier(CartStoreToastModifier())
    }
}
