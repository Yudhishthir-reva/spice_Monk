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
    @Published var isAppliedCouponValid = true
    @Published var couponValidationMessage: String? = nil
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
    private var pendingCartCouponQuery: CartCouponQuery = .default
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
    private let catalogService = HomeServiceManager()

    var isEmpty: Bool {
        items.allSatisfy { $0.qty < 1 } && pendingOptimisticQty.isEmpty
    }

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

    /// Catalog + stepper: local qty updates instantly; one debounce (product+variant) sends the final qty.
    func incrementOrAdd(productId: Int, variantId: Int, availableQty: Int, maxOrderQty: Int? = nil) {
        runWhenReady { [weak self] in
            self?.nudgeQty(
                productId: productId,
                variantId: variantId,
                by: 1,
                availableQty: availableQty,
                maxOrderQty: maxOrderQty
            )
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

    /// OTP just replaced the guest Bearer with a user token. Drop in-flight guest hydrations
    /// and pull `GET customer/cart`, which now includes the merged guest lines.
    func reloadAfterLogin() {
        cancellables.removeAll()
        pendingAfterLoad.removeAll()
        pendingQtyTimers.values.forEach { $0.cancel() }
        pendingQtyTimers.removeAll()
        isLoading = false
        isRefreshing = false
        load()
    }

    func refresh(clearingCoupon: Bool = false) {
        if clearingCoupon {
            pendingCartCouponQuery = .cleared
        } else if let coupon = appliedCoupon, coupon.couponId > 0 {
            pendingCartCouponQuery = .couponId(coupon.couponId)
        } else {
            pendingCartCouponQuery = .default
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        fetch()
    }

    /// Silent cart sync after add/update/remove — keeps bill details in sync with server.
    private func syncCartAfterMutation() {
        if let coupon = appliedCoupon, coupon.couponId > 0 {
            pendingCartCouponQuery = .couponId(coupon.couponId)
        } else {
            pendingCartCouponQuery = .default
        }
        fetch()
    }

    /// Validate `coupon_id` then sync cart via `GET customer/cart?coupon_id=`.
    func syncAppliedCoupon(
        _ data: AppliedCouponData,
        completion: @escaping (_ coupon: AppliedCouponData?, _ errorMessage: String?) -> Void
    ) {
        appliedCoupon = data
        couponDiscount = data.discountAmount
        isAppliedCouponValid = true
        couponValidationMessage = nil
        if data.finalTotal > 0 {
            grandTotal = data.finalTotal
        }

        serviceManagable.validateCoupon(couponId: data.couponId)
            .flatMap { [weak self] validateResponse -> AnyPublisher<(AppliedCouponData, CartResponse), Error> in
                guard let self else {
                    return Fail(error: RequestError.unknownError).eraseToAnyPublisher()
                }
                guard validateResponse.status == true else {
                    let message = validateResponse.message ?? "Coupon is not valid."
                    return Fail(error: RequestError.apiMessage(message)).eraseToAnyPublisher()
                }
                let discount = validateResponse.discountAmount > 0
                    ? validateResponse.discountAmount
                    : data.discountAmount
                let validated = data.updating(discountAmount: discount)
                return self.serviceManagable.fetchCart(couponQuery: .couponId(data.couponId))
                    .map { (validated, $0) }
                    .eraseToAnyPublisher()
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] sinkCompletion in
                if case .failure(let error) = sinkCompletion {
                    self?.appliedCoupon = nil
                    self?.couponDiscount = 0
                    self?.isAppliedCouponValid = true
                    self?.couponValidationMessage = nil
                    let message = (error as? RequestError)?.errorString ?? error.localizedDescription
                    completion(nil, message)
                }
            } receiveValue: { [weak self] validated, response in
                guard let self else { return }
                self.appliedCoupon = validated
                self.couponDiscount = validated.discountAmount
                self.applyCartResponse(response, couponQuery: .couponId(data.couponId))
                completion(self.appliedCoupon ?? validated, nil)
            }
            .store(in: &cancellables)
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
        isAppliedCouponValid = true
        couponValidationMessage = nil
        paymentMethod = .cod
        isLoading = false
        isRefreshing = false
        loadError = nil
        isClearing = false
        isRepeatingOrder = false
        didLoadOnce = false
        pendingCartCouponQuery = .default
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

    /// First add and later +/- share one timer keyed by product+variant so rapid taps
    /// (including minus before `cart_id` exists) collapse into a single API call.
    func addOrIncrement(productId: Int, variantId: Int, availableQty: Int, maxOrderQty: Int? = nil) {
        incrementOrAdd(
            productId: productId,
            variantId: variantId,
            availableQty: availableQty,
            maxOrderQty: maxOrderQty
        )
    }

    func decrement(productId: Int, variantId: Int) {
        runWhenReady { [weak self] in
            guard let self else { return }
            let item = self.line(productId: productId, variantId: variantId)
            self.nudgeQty(
                productId: productId,
                variantId: variantId,
                by: -1,
                availableQty: item?.availableQty ?? 0,
                maxOrderQty: item?.maxOrderQty
            )
        }
    }

    /// Optimistically updates the local qty and debounces the API call.
    /// Rapid +/- taps on the same item collapse into a single network request with the final qty.
    func changeQty(_ item: CartItem, by delta: Int) {
        nudgeQty(
            productId: item.productId,
            variantId: item.variantId,
            by: delta,
            availableQty: item.availableQty,
            maxOrderQty: item.maxOrderQty
        )
    }

    private func nudgeQty(
        productId: Int,
        variantId: Int,
        by delta: Int,
        availableQty: Int,
        maxOrderQty: Int?
    ) {
        let current = quantity(productId: productId, variantId: variantId)
        let next = current + delta
        if next < 1 {
            applyLocalQty(productId: productId, variantId: variantId, qty: 0)
            scheduleQtyFlush(productId: productId, variantId: variantId)
            return
        }

        let effectiveMax = maxOrderQty ?? line(productId: productId, variantId: variantId)?.maxOrderQty
        if availableQty > 0, next > availableQty {
            toastMessage = "Only \(availableQty) units available in stock."
            isShowToastView = true
            return
        }
        if let maxQty = effectiveMax, maxQty > 0, next > maxQty {
            toastMessage = "Maximum limit for this item is \(maxQty) units."
            isShowToastView = true
            return
        }

        applyLocalQty(productId: productId, variantId: variantId, qty: next)
        scheduleQtyFlush(productId: productId, variantId: variantId)
    }

    private func applyLocalQty(productId: Int, variantId: Int, qty: Int) {
        let key = Self.key(productId: productId, variantId: variantId)
        if qty < 1 {
            if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
                patch(cartId: item.cartId) { $0.setQty(0) }
                syncSummaryFromItems()
            }
            pendingOptimisticQty[key] = nil
            bump()
            return
        }
        if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
            patch(cartId: item.cartId) { $0.setQty(qty) }
            pendingOptimisticQty[key] = nil
            syncSummaryFromItems()
        } else {
            pendingOptimisticQty[key] = qty
        }
        bump()
    }

    private func scheduleQtyFlush(productId: Int, variantId: Int) {
        let key = Self.key(productId: productId, variantId: variantId)
        pendingQtyTimers[key]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingQtyTimers[key] = nil
            self.flushQty(productId: productId, variantId: variantId)
        }
        pendingQtyTimers[key] = workItem
        debounceQueue.asyncAfter(deadline: .now() + qtyDebounceInterval, execute: workItem)
    }

    private func flushQty(productId: Int, variantId: Int) {
        let key = Self.key(productId: productId, variantId: variantId)
        pendingAddKeys.remove(key)
        pendingAddTapCount[key] = nil
        let qty = quantity(productId: productId, variantId: variantId)
        if qty < 1 {
            if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
                removeItem(item)
            }
            pendingOptimisticQty[key] = nil
            return
        }
        let item = line(productId: productId, variantId: variantId)
        performAddOrIncrement(
            productId: productId,
            variantId: variantId,
            availableQty: item?.availableQty ?? 0,
            maxOrderQty: item?.maxOrderQty,
            tapCount: qty
        )
    }

    /// Removes the whole line in one tap (guest → `guest/cart/remove`, logged-in → `cart/remove`).
    func removeItem(_ item: CartItem) {
        debouncedRemove(item)
    }

    private func debouncedRemove(_ item: CartItem) {
        guard item.cartId > 0, !removingIds.contains(item.cartId) else { return }

        let key = String(item.cartId)
        pendingQtyTimers[key]?.cancel()
        pendingQtyTimers[key] = nil
        pendingQtyTimers[Self.key(productId: item.productId, variantId: item.variantId)]?.cancel()
        pendingQtyTimers[Self.key(productId: item.productId, variantId: item.variantId)] = nil

        // Optimistic local removal
        removingIds.insert(item.cartId)
        bump()
        let snapshot = items
        items.removeAll { $0.cartId == item.cartId }
        if items.isEmpty { summary = .empty }

        if !UserDefaultManager.shared.isUserLoggedIn {
            serviceManagable.removeGuestCart(productId: item.productId, variantId: item.variantId)
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
                            self.charges = []
                            self.grandTotal = 0
                        } else {
                            self.fetch()
                        }
                    } else {
                        self.items = snapshot
                        self.toastMessage = response.message ?? "Could not remove this item."
                        self.isShowToastView = true
                    }
                }
                .store(in: &cancellables)
            return
        }

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

        if !UserDefaultManager.shared.isUserLoggedIn {
            serviceManagable.clearGuestCart()
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
                        self.grandTotal = 0
                        self.toastMessage = response.message ?? "Cart cleared successfully."
                    } else {
                        self.items = snapshot
                        self.summary = snapshotSummary
                        self.toastMessage = response.message ?? "Could not clear the cart."
                    }
                    self.isShowToastView = true
                }
                .store(in: &cancellables)
            return
        }

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

        if !UserDefaultManager.shared.isUserLoggedIn {
            serviceManagable.addGuestCart(productId: productId, variantId: variantId, qty: qty)
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
                    if response.status == true {
                        if self.pendingQtyTimers[key] == nil {
                            self.fetch()
                        }
                    } else {
                        self.pendingOptimisticQty[key] = nil
                        self.toastMessage = response.message ?? "Unable to add this product."
                        self.isShowToastView = true
                    }
                }
                .store(in: &cancellables)
            return
        }

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

        if !UserDefaultManager.shared.isUserLoggedIn {
            serviceManagable.updateGuestCart(productId: item.productId, variantId: item.variantId, qty: qty)
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
                    self.load()
                } receiveValue: { [weak self] response in
                    guard let self else { return }
                    self.updatingIds.remove(item.cartId)
                    self.bump()
                    if response.status == true {
                        let key = Self.key(productId: item.productId, variantId: item.variantId)
                        if self.pendingQtyTimers[key] == nil {
                            self.fetch()
                        }
                    } else {
                        self.items = snapshot
                        self.syncSummaryFromItems()
                        self.toastMessage = response.message ?? "Could not update quantity."
                        self.isShowToastView = true
                    }
                }
                .store(in: &cancellables)
            return
        }

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
                    self.syncCartAfterMutation()
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
        if !UserDefaultManager.shared.isUserLoggedIn && !UserDefaultManager.shared.hasValidGuestToken {
            GuestSessionManager.shared.ensureSession { [weak self] in
                DispatchQueue.main.async {
                    self?.runWhenReady(action)
                }
            }
            return
        }
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
        let couponQuery = pendingCartCouponQuery
        pendingCartCouponQuery = .default
        if !UserDefaultManager.shared.isUserLoggedIn {
            fetchGuestCart()
            return
        }
        serviceManagable.fetchCart(couponQuery: couponQuery)
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
                self.applyCartResponse(response, couponQuery: couponQuery)
                self.loadError = nil
                let pending = self.pendingAfterLoad
                self.pendingAfterLoad.removeAll()
                pending.forEach { $0() }
            }
            .store(in: &cancellables)
    }

    private func fetchGuestCart() {
        serviceManagable.fetchGuestCart()
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
                // Guest cart GET/POST returns priced `data`/`summary`/`grand_total` (same as logged-in).
                self.applyCartResponse(response, couponQuery: .default)
                self.finishGuestFetch()
            }
            .store(in: &cancellables)
    }

    private func finishGuestFetch() {
        isLoading = false
        isRefreshing = false
        didLoadOnce = true
        loadError = nil
        pendingOptimisticQty = pendingOptimisticQty.filter { pendingQtyTimers[$0.key] != nil }
        pendingAddKeys = pendingAddKeys.filter { pendingQtyTimers[$0] != nil || addingKeys.contains($0) }
        bump()
        let pending = pendingAfterLoad
        pendingAfterLoad.removeAll()
        pending.forEach { $0() }
    }

    private func inFlightQtyOverrides() -> [String: Int] {
        var map: [String: Int] = [:]
        for item in items where item.productId > 0 {
            let key = Self.key(productId: item.productId, variantId: item.variantId)
            if pendingQtyTimers[key] != nil || addingKeys.contains(key) || updatingIds.contains(item.cartId) {
                map[key] = quantity(productId: item.productId, variantId: item.variantId)
            }
        }
        for (key, qty) in pendingOptimisticQty {
            if pendingQtyTimers[key] != nil || addingKeys.contains(key) {
                map[key] = qty
            }
        }
        return map
    }

    private func reapplyInFlightQtyOverrides(_ map: [String: Int]) {
        guard !map.isEmpty else { return }
        for (key, qty) in map {
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let productId = Int(parts[0]),
                  let variantId = Int(parts[1]) else { continue }
            if qty < 1 {
                if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
                    patch(cartId: item.cartId) { $0.setQty(0) }
                }
                pendingOptimisticQty[key] = nil
                continue
            }
            if let item = line(productId: productId, variantId: variantId), item.cartId > 0 {
                patch(cartId: item.cartId) { $0.setQty(qty) }
                pendingOptimisticQty[key] = nil
            } else {
                pendingOptimisticQty[key] = qty
            }
        }
        syncSummaryFromItems()
    }

    private func applyCartResponse(_ response: CartResponse, couponQuery: CartCouponQuery) {
        let overrides = inFlightQtyOverrides()
        items = response.items.filter { $0.productId > 0 }
        summary = response.summary
        charges = response.charges
        deliveryInfo = response.deliveryInfo
        reapplyInFlightQtyOverrides(overrides)

        switch couponQuery {
        case .cleared:
            appliedCoupon = nil
            isAppliedCouponValid = true
            couponValidationMessage = nil
            couponDiscount = response.couponDiscount
            if response.grandTotal > 0 {
                grandTotal = response.grandTotal
            }
            return
        case .couponId, .default:
            break
        }

        applyCouponState(from: response)

        if response.grandTotal > 0 {
            let serverOmitsCoupon = response.coupon == nil
                && response.couponInvalidMessage == nil
                && response.couponDiscount <= 0
            if !(serverOmitsCoupon && appliedCoupon != nil && isAppliedCouponValid) {
                grandTotal = response.grandTotal
            }
        }
    }

    private func applyCouponState(from response: CartResponse) {
        couponDiscount = response.couponDiscount

        if let payload = response.couponPayload {
            if payload.isValid, let details = payload.details {
                appliedCoupon = details
                isAppliedCouponValid = true
                couponValidationMessage = nil
                if response.couponDiscount > 0 {
                    couponDiscount = response.couponDiscount
                } else if details.discountAmount > 0 {
                    couponDiscount = details.discountAmount
                }
            } else if !payload.isValid {
                isAppliedCouponValid = false
                couponValidationMessage = payload.message ?? "Coupon is not valid for this cart."
                couponDiscount = response.couponDiscount
            }
            return
        }

        if let coupon = response.coupon {
            appliedCoupon = coupon
            isAppliedCouponValid = true
            couponValidationMessage = nil
            couponDiscount = response.couponDiscount > 0 ? response.couponDiscount : coupon.discountAmount
        } else if response.couponDiscount > 0, let existing = appliedCoupon {
            appliedCoupon = existing.updating(discountAmount: response.couponDiscount)
            isAppliedCouponValid = true
            couponValidationMessage = nil
            couponDiscount = response.couponDiscount
        } else if appliedCoupon == nil {
            isAppliedCouponValid = true
            couponValidationMessage = nil
        }
    }

    func removeCoupon() {
        guard appliedCoupon != nil else { return }
        appliedCoupon = nil
        isAppliedCouponValid = true
        couponValidationMessage = nil
        couponDiscount = 0
        refresh(clearingCoupon: true)
    }

    func validateAppliedCoupon() {
        guard let coupon = appliedCoupon else { return }
        serviceManagable.validateCoupon(couponId: coupon.couponId)
            .flatMap { [weak self] validateResponse -> AnyPublisher<CartResponse, Error> in
                guard let self else {
                    return Fail(error: RequestError.unknownError).eraseToAnyPublisher()
                }
                guard validateResponse.status == true else {
                    let message = validateResponse.message ?? "Coupon is no longer valid for your updated cart."
                    return Fail(error: RequestError.apiMessage(message)).eraseToAnyPublisher()
                }
                let validated = coupon.updating(
                    discountAmount: validateResponse.discountAmount > 0
                        ? validateResponse.discountAmount
                        : coupon.discountAmount
                )
                self.appliedCoupon = validated
                self.couponDiscount = validated.discountAmount
                return self.serviceManagable.fetchCart(couponQuery: .couponId(coupon.couponId))
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    if case RequestError.apiMessage(let message) = error {
                        self?.appliedCoupon = nil
                        self?.couponDiscount = 0
                        self?.toastMessage = message
                        self?.isShowToastView = true
                        self?.refresh(clearingCoupon: true)
                    } else {
                        #if DEBUG
                        print("Coupon validation failed: \(error)")
                        #endif
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self, let coupon = self.appliedCoupon else { return }
                self.applyCartResponse(response, couponQuery: .couponId(coupon.couponId))
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
        scheduleQtyFlush(productId: item.productId, variantId: item.variantId)
    }

    private func schedulePendingAddSync(productId: Int, variantId: Int) {
        scheduleQtyFlush(productId: productId, variantId: variantId)
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
            let timerKey = Self.key(productId: productId, variantId: variantId)
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
