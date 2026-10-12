//
//  AddressViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class AddressViewModel: ObservableObject {

    /// One instance app-wide. The cart is reachable from seven screens and each used to build its
    /// own view model, so opening it anywhere but home refetched the address list and showed
    /// "No delivery address selected" until that call returned.
    static let shared = AddressViewModel()

    @Published private(set) var addresses: [Address] = []
    @Published private(set) var isLoading = false
    /// False until the first list call has come back either way, so the header can tell
    /// "we haven't asked yet" apart from "the user genuinely has no address".
    @Published private(set) var didAttemptLoad = false
    @Published private(set) var deviceLocation: ResolvedLocationInfo?
    @Published private(set) var isResolvingDevice = false
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
        guard UserDefaultManager.shared.isUserLoggedIn else {
            // A guest has no list to fetch, but that is still a settled answer: without it the
            // header would sit on "Loading…" forever instead of falling back to the device.
            addresses = []
            didAttemptLoad = true
            DispatchQueue.main.async { [weak self] in self?.resolveDeviceLocationIfNeeded() }
            return
        }
        guard !isLoading else { return }
        isLoading = true

        serviceManagable.fetchAddresses()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                self?.didAttemptLoad = true
                // A missing address list is not worth interrupting the home feed for; the header
                // falls back to the device location, or to prompting the user to set one. The next
                // `onAppear` retries, since `load()` only guards against a call already in flight.
                if case .failure(let error) = completion {
                    debugPrint("Address list failed:", error)
                }
                self?.resolveDeviceLocationIfNeeded()
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                self.didAttemptLoad = true
                self.addresses = response.addresses
                // A saved address outranks any device fix, so stop holding a stale one.
                if self.defaultAddress != nil { self.deviceLocation = nil }
                self.resolveDeviceLocationIfNeeded()
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

    // MARK: - Home header

    /// What the home header speaks for. Mirrors Android's `rememberLocationDisplay`: a saved
    /// address first, then a device fix, with progress text in between so the header never jumps
    /// straight to the "no address" prompt while it is still working something out.
    struct HeaderLocation {
        /// PIN code for the chip; empty hides it.
        let chip: String
        let line: String
    }

    var headerLocation: HeaderLocation {
        if let address = defaultAddress {
            let line = address.shortLine.isEmptyString
                ? (address.cityName ?? "Saved address")
                : address.shortLine
            return HeaderLocation(chip: address.pinCode, line: line)
        }
        if isResolvingDevice {
            return HeaderLocation(chip: "", line: "Detecting your location…")
        }
        if let device = deviceLocation, !device.postalCode.isEmpty {
            let line = [device.area, device.city]
                .first { !$0.isEmpty } ?? "Current location"
            return HeaderLocation(chip: device.postalCode, line: line)
        }
        if isLoading || !didAttemptLoad {
            return HeaderLocation(chip: "", line: "Loading…")
        }
        return HeaderLocation(chip: "", line: "Set your delivery address")
    }

    /// Fills the header from the device when the user has no saved address to show.
    ///
    /// Only runs on a permission the user has *already* granted — asking for location just to
    /// label the header would put an OS prompt in front of someone who only opened the app.
    /// Android gates this the same way (`locationPermission.isGranted`); its prompt belongs to the
    /// switcher's explicit "Use my current location".
    @MainActor
    func resolveDeviceLocationIfNeeded() {
        guard didAttemptLoad, !isLoading else { return }
        guard defaultAddress == nil, deviceLocation == nil, !isResolvingDevice else { return }

        let status = LocationManager.shared.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }

        isResolvingDevice = true
        LocationManager.shared.fetchCurrentLocationAndResolve { [weak self] info in
            Task { @MainActor in
                guard let self else { return }
                self.isResolvingDevice = false
                self.deviceLocation = info
            }
        }
    }
}
