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
    @Published var appliedCoupon: AppliedCouponData? = nil
    @Published var paymentMethod: PaymentMethod = .cod
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var loadError: String?
    @Published var toastMessage = ""
    @Published var isShowToastView = false
    @Published var isClearing = false
    @Published private var mutationTick = 0

    private var didLoadOnce = false
    private var pendingAfterLoad: [() -> Void] = []
    private var removingIds = Set<Int>()
    private var updatingIds = Set<Int>()
    private var addingKeys = Set<String>()
    private var cancellables = Set<AnyCancellable>()
    private var pendingQtyTimers: [String: DispatchWorkItem] = [:]
    private var pendingAddTapCount: [String: Int] = [:]
    private let qtyDebounceInterval: TimeInterval = 0.35
    private let debounceQueue = DispatchQueue.main
    var serviceManagable = CartServiceManager()

    var isEmpty: Bool { items.isEmpty }

    private init() {}

    func line(productId: Int, variantId: Int) -> CartItem? {
        items.first { $0.productId == productId && $0.variantId == variantId }
    }

    func quantity(productId: Int, variantId: Int) -> Int {
        line(productId: productId, variantId: variantId)?.qty ?? 0
    }

    func isBusy(productId: Int, variantId: Int) -> Bool {
        _ = mutationTick
        if addingKeys.contains(Self.key(productId: productId, variantId: variantId)) {
            return true
        }
        guard let cartId = line(productId: productId, variantId: variantId)?.cartId, cartId > 0 else {
            return false
        }
        return updatingIds.contains(cartId) || removingIds.contains(cartId)
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
        appliedCoupon = nil
        paymentMethod = .cod
        isLoading = false
        isRefreshing = false
        loadError = nil
        isClearing = false
        didLoadOnce = false
        removingIds.removeAll()
        updatingIds.removeAll()
        addingKeys.removeAll()
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
        self.appliedCoupon = nil
        self.paymentMethod = .cod
    }

    /// First add sends `qty: 1`. Later taps send the new total (`2`, `3`, …) via update when we
    /// already have a `cart_id`, or via add if we only know product + variant.
    /// Debounced so rapid taps on the same product collapse into a single API call.
    func addOrIncrement(productId: Int, variantId: Int, availableQty: Int) {
        let key = Self.key(productId: productId, variantId: variantId)

        runWhenReady { [weak self] in
            guard let self = self else { return }

            // Cancel any pending add-tap timer for this item
            self.pendingQtyTimers[key]?.cancel()

            // Track how many taps came in before debounce fires
            self.pendingAddTapCount[key, default: 0] += 1
            let tapCount = self.pendingAddTapCount[key]!

            // Optimistically bump local state now (per tap)
            let current = self.quantity(productId: productId, variantId: variantId)
            let optimisticQty = current + tapCount
            if let item = self.line(productId: productId, variantId: variantId), item.cartId > 0 {
                self.patch(cartId: item.cartId) { $0.setQty(optimisticQty) }
                self.bump()
            }

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.pendingQtyTimers[key] = nil
                let count = self.pendingAddTapCount[key] ?? 0
                self.pendingAddTapCount[key] = nil
                guard count > 0 else { return }
                self.performAddOrIncrement(
                    productId: productId,
                    variantId: variantId,
                    availableQty: availableQty,
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
        let next = item.qty + delta
        if next < 1 {
            debouncedRemove(item)
            return
        }
        if item.availableQty > 0, next > item.availableQty {
            toastMessage = "Only \(item.availableQty) units available in stock."
            isShowToastView = true
            return
        }

        // Optimistic local update
        patch(cartId: item.cartId) { $0.setQty(next) }
        bump()

        // Debounce the API call
        let key = String(item.cartId)
        pendingQtyTimers[key]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingQtyTimers[key] = nil
            if let current = self.line(productId: item.productId, variantId: item.variantId), current.cartId == item.cartId {
                self.updateQty(current, qty: current.qty)
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

    private func performAddOrIncrement(productId: Int, variantId: Int, availableQty: Int, tapCount: Int = 1) {
        let current = quantity(productId: productId, variantId: variantId)
        let next = current + tapCount
        if availableQty > 0, next > availableQty {
            toastMessage = "Only \(availableQty) units available in stock."
            isShowToastView = true
            // Roll back optimistic UI to actual qty
            if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
                patch(cartId: item.cartId) { $0.setQty(current) }
                bump()
            }
            return
        }
        if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
            updateQty(item, qty: next)
        } else {
            add(productId: productId, variantId: variantId, qty: max(next, 1), announce: current == 0)
        }
    }

    private func add(productId: Int, variantId: Int, qty: Int, announce: Bool) {
        let key = Self.key(productId: productId, variantId: variantId)
        guard !addingKeys.contains(key) else { return }
        addingKeys.insert(key)
        bump()

        serviceManagable.addToCart(productId: productId, variantId: variantId, qty: qty)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.addingKeys.remove(key)
                self.bump()
                guard case .failure(let error) = completion else { return }
                self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                self.isShowToastView = true
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.addingKeys.remove(key)
                self.bump()
                if response.status == true {
                    if let added = response.item {
                        self.upsert(added)
                    }
                    if announce {
                        self.toastMessage = response.message ?? "Added to cart."
                        self.isShowToastView = true
                    }
                    self.refresh()
                } else {
                    self.toastMessage = response.message ?? "Unable to add this product."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }

    private func updateQty(_ item: CartItem, qty: Int) {
        guard item.cartId > 0, !updatingIds.contains(item.cartId), !removingIds.contains(item.cartId) else { return }
        updatingIds.insert(item.cartId)
        bump()
        let snapshot = items
        patch(cartId: item.cartId) { $0.setQty(qty) }

        serviceManagable.updateCart(cartId: item.cartId, qty: qty)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.updatingIds.remove(item.cartId)
                self.bump()
                guard case .failure(let error) = completion else { return }
                self.items = snapshot
                self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                self.isShowToastView = true
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.updatingIds.remove(item.cartId)
                self.bump()
                if response.status == true {
                    if let updated = response.item {
                        self.upsert(updated)
                    }
                    self.refresh()
                } else {
                    self.items = snapshot
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

    private func fetch() {
        serviceManagable.fetchCart()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false
                guard case .failure(let error) = completion else { return }
                let message = (error as? RequestError)?.errorString ?? error.localizedDescription
                self.pendingAfterLoad.removeAll()
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
