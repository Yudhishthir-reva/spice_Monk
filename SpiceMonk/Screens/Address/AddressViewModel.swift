//
//  AddressViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class AddressViewModel: ObservableObject {

    @Published private(set) var addresses: [Address] = []
    @Published private(set) var isLoading = false
    @Published var isShowToastView = false
    @Published var toastMessage = ""

    private var cancellables = Set<AnyCancellable>()
    var serviceManagable = AddressServiceManager()

    /// The address the header speaks for. The backend flags one as default; if it ever sends a list
    /// with none flagged, the first is used so the header still shows something real.
    var defaultAddress: Address? {
        addresses.first(where: \.isDefault) ?? addresses.first
    }

    var hasAddresses: Bool { !addresses.isEmpty }

    func load() {
        guard UserDefaultManager.shared.isUserLoggedIn else { return }
        guard !isLoading else { return }
        isLoading = true

        serviceManagable.fetchAddresses()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                // A missing address list is not worth interrupting the home feed for; the header
                // simply keeps prompting the user to set one.
                if case .failure(let error) = completion {
                    debugPrint("Address list failed:", error)
                }
            } receiveValue: { [weak self] response in
                self?.isLoading = false
                self?.addresses = response.addresses
            }
            .store(in: &cancellables)
    }

    func makeDefault(_ address: Address) {
        guard !address.isDefault else { return }

        serviceManagable.setDefaultAddress(id: address.id)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                self?.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                self?.isShowToastView = true
                // The optimistic switch below no longer matches the server, so pull the truth back.
                self?.load()
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status != true {
                    self.toastMessage = response.message ?? "Could not change the delivery address."
                    self.isShowToastView = true
                    self.load()
                }
            }
            .store(in: &cancellables)

        // Applied straight away so the sheet responds to the tap instead of waiting on the network.
        addresses = addresses.map {
            var copy = $0
            copy.isDefault = $0.id == address.id
            return copy
        }
    }

    func deleteAddress(_ address: Address) {
        serviceManagable.deleteAddress(id: address.id)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    self?.isShowToastView = true
                    self?.load()
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status == true {
                    self.addresses.removeAll(where: { $0.id == address.id })
                    self.toastMessage = response.message ?? "Address deleted successfully."
                    self.isShowToastView = true
                } else {
                    self.toastMessage = response.message ?? "Could not delete address."
                    self.isShowToastView = true
                    self.load()
                }
            }
            .store(in: &cancellables)

        // Optimistic removal
        addresses.removeAll(where: { $0.id == address.id })
    }
}
