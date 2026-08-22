//
//  OrdersViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class OrdersViewModel: ObservableObject {

    @Published var orders: [OrderItem] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var loadError: String? = nil
    @Published var selectedStatusFilter: String = "" {
        didSet {
            // Cancel ongoing request, clear items and reload immediately
            cancellables.removeAll()
            orders = []
            isLoading = true
            isRefreshing = false
            loadError = nil
            currentPage = 1
            fetch(page: 1)
        }
    }

    private var currentPage = 1
    private var lastPage = 1
    private var hasMore = false
    private var cancellables = Set<AnyCancellable>()
    private let service = OrderServiceManager()

    func loadFirstPage() {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        currentPage = 1
        fetch(page: 1)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        loadError = nil
        currentPage = 1
        fetch(page: 1)
    }

    func loadNextPageIfNeeded(currentOrder: OrderItem) {
        guard hasMore && !isLoading else { return }
        guard let index = orders.firstIndex(where: { $0.id == currentOrder.id }),
              index >= orders.count - 3 else { return }

        isLoading = true
        fetch(page: currentPage + 1)
    }

    private func fetch(page: Int) {
        service.fetchOrders(page: page, status: selectedStatusFilter)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false

                if case .failure(let error) = completion {
                    let message = (error as? RequestError)?.errorString ?? error.localizedDescription
                    if self.orders.isEmpty {
                        self.loadError = message
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false

                self.currentPage = response.pagination.currentPage
                self.lastPage = response.pagination.lastPage
                self.hasMore = response.pagination.hasMore

                if page == 1 {
                    self.orders = response.orders
                } else {
                    self.orders.append(contentsOf: response.orders)
                }

                self.loadError = self.orders.isEmpty ? "No orders found." : nil
            }
            .store(in: &cancellables)
    }
}
