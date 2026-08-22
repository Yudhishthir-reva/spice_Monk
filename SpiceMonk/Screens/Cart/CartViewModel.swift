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
    @Published var appliedCoupon: Coupon? = nil
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
        bump()
    }

    func placeOrder(addressId: Int, notes: String = "Please call before delivery") {
        guard !isClearing && !isLoading else { return }
        isLoading = true

        let apiPaymentType = paymentMethod == .cod ? "cod" : "prepaid"
        OrderServiceManager().placeOrder(addressId: addressId, paymentType: apiPaymentType, notes: notes)
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
    func addOrIncrement(productId: Int, variantId: Int, availableQty: Int) {
        runWhenReady { [weak self] in
            self?.performAddOrIncrement(productId: productId, variantId: variantId, availableQty: availableQty)
        }
    }

    func decrement(productId: Int, variantId: Int) {
        runWhenReady { [weak self] in
            guard let self, let item = self.line(productId: productId, variantId: variantId) else { return }
            self.changeQty(item, by: -1)
        }
    }

    func changeQty(_ item: CartItem, by delta: Int) {
        let next = item.qty + delta
        if next < 1 {
            remove(item)
            return
        }
        if item.availableQty > 0, next > item.availableQty {
            toastMessage = "Only \(item.availableQty) units available in stock."
            isShowToastView = true
            return
        }
        updateQty(item, qty: next)
    }

    func remove(_ item: CartItem) {
        guard item.cartId > 0, !removingIds.contains(item.cartId) else { return }
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

    private func performAddOrIncrement(productId: Int, variantId: Int, availableQty: Int) {
        let current = quantity(productId: productId, variantId: variantId)
        let next = current + 1
        if availableQty > 0, next > availableQty {
            toastMessage = "Only \(availableQty) units available in stock."
            isShowToastView = true
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
                let pending = self.pendingAfterLoad
                self.pendingAfterLoad.removeAll()
                pending.forEach { $0() }
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
