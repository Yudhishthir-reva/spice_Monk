//
//  OrderDetailViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class OrderDetailViewModel: ObservableObject {

    @Published var order: OrderDetail? = nil
    @Published var isLoading = false
    @Published var loadError: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let service = OrderServiceManager()

    func load(orderId: Int) {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil

        service.fetchOrderDetail(orderId: orderId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.loadError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status == true {
                    self.order = response.order
                } else {
                    self.loadError = response.message ?? "Could not load order details."
                }
            }
            .store(in: &cancellables)
    }

    func cancel(orderId: Int, reason: String, completion: @escaping (Bool, String) -> Void) {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil

        service.cancelOrder(orderId: orderId, reason: reason)
            .receive(on: RunLoop.main)
            .sink { [weak self] comp in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = comp {
                    let msg = (error as? RequestError)?.errorString ?? error.localizedDescription
                    completion(false, msg)
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status == true {
                    completion(true, response.message ?? "Order cancelled successfully.")
                    self.load(orderId: orderId)
                } else {
                    completion(false, response.message ?? "Could not cancel order.")
                }
            }
            .store(in: &cancellables)
    }
}
