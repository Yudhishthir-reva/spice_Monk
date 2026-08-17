//
//  CartViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class CartViewModel: ObservableObject {

    @Published var items: [CartItem] = []
    @Published var summary: CartSummary = .empty
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var loadError: String?
    @Published var toastMessage = ""
    @Published var isShowToastView = false
    @Published var isClearing = false

    private var removingIds = Set<Int>()
    private var cancellables = Set<AnyCancellable>()
    var serviceManagable = CartServiceManager()

    var isEmpty: Bool { items.isEmpty }

    func isRemoving(_ item: CartItem) -> Bool {
        removingIds.contains(item.cartId)
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

    func checkout() {
        toastMessage = "Checkout is coming soon"
        isShowToastView = true
    }

    func remove(_ item: CartItem) {
        guard item.cartId > 0, !removingIds.contains(item.cartId) else { return }
        removingIds.insert(item.cartId)
        let snapshot = items
        items.removeAll { $0.cartId == item.cartId }
        if items.isEmpty { summary = .empty }

        serviceManagable.removeFromCart(cartId: item.cartId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.removingIds.remove(item.cartId)
                guard case .failure(let error) = completion else { return }
                self.items = snapshot
                self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                self.isShowToastView = true
                self.load()
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.removingIds.remove(item.cartId)
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
                self.items = response.items.filter { $0.productId > 0 }
                self.summary = response.summary
                self.loadError = nil
            }
            .store(in: &cancellables)
    }
}
