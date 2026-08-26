//
//  AddressFormViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class AddressFormViewModel: ObservableObject {

    @Published var fullName = ""
    @Published var mobile = ""
    @Published var alternateMobile = ""
    @Published var pinCode = ""
    /// Saving takes the state and district as plain names, so the PIN lookup is a convenience that
    /// fills these rather than a gate. They stay editable for PINs the backend cannot resolve.
    @Published var state = ""
    @Published var district = ""
    @Published var area = ""
    @Published var houseFlatNo = ""
    @Published var landmark = ""
    @Published var isDefault = false

    @Published private(set) var isLookingUpPincode = false
    @Published private(set) var didResolvePincode = false
    @Published private(set) var pincodeError: String?

    @Published private(set) var isSaving = false
    @Published var isShowToastView = false
    @Published var toastMessage = ""

    private var cancellables = Set<AnyCancellable>()
    private var lookupCancellable: AnyCancellable?
    var serviceManagable = AddressServiceManager()

    private static let pinCodeLength = 6

    /// A complete PIN is enough to try; anything still missing is reported by name on submit, which
    /// beats a dead button that does not say what it wants.
    func pinCodeChanged() {
        let digits = String(pinCode.filter(\.isNumber).prefix(Self.pinCodeLength))
        if digits != pinCode {
            pinCode = digits
        }

        lookupCancellable?.cancel()
        didResolvePincode = false
        pincodeError = nil

        guard digits.count == Self.pinCodeLength else {
            isLookingUpPincode = false
            return
        }

        isLookingUpPincode = true
        lookupCancellable = serviceManagable.lookupPincode(digits)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLookingUpPincode = false
                if case .failure(let error) = completion {
                    self.pincodeError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLookingUpPincode = false

                if let location = response.location, location.isUsable {
                    // The PIN is authoritative, so a fresh result replaces anything typed before.
                    self.state = location.state
                    self.district = location.district
                    self.didResolvePincode = true
                } else {
                    self.pincodeError = response.message ?? "Couldn't find this PIN code — please fill in the city and state."
                }
            }
    }

    /// Auto-fills form values from map location picker
    func applyPickedLocation(_ info: ResolvedLocationInfo) {
        if !info.postalCode.isEmpty {
            self.pinCode = info.postalCode
            self.pinCodeChanged()
        }
        if !info.area.isEmpty {
            self.area = info.area
        }
        if !info.street.isEmpty && self.houseFlatNo.isEmpty {
            self.houseFlatNo = info.street
        }
        if !info.city.isEmpty {
            self.district = info.city
        }
        if !info.state.isEmpty {
            self.state = info.state
        }
    }

    func save(onSuccess: @escaping (Address?) -> Void) {
        if let validationError = firstValidationError {
            show(validationError)
            return
        }
        submit(onSuccess: onSuccess)
    }

    private var firstValidationError: String? {
        if fullName.trim.isEmptyString {
            return "Please enter the recipient's name."
        }
        if !mobile.trim.isValidIndianMobileNumber() {
            return "Please enter a valid 10-digit mobile number."
        }
        if !alternateMobile.trim.isEmptyString, !alternateMobile.trim.isValidIndianMobileNumber() {
            return "The alternate number is not a valid 10-digit mobile number."
        }
        if pinCode.count != Self.pinCodeLength {
            return "Please enter a 6-digit PIN code."
        }
        if houseFlatNo.trim.isEmptyString {
            return "Please enter your house or flat number."
        }
        if area.trim.isEmptyString {
            return "Please enter your area."
        }
        if district.trim.isEmptyString {
            return "Please enter your city or district."
        }
        if state.trim.isEmptyString {
            return "Please enter your state."
        }
        return nil
    }

    private func submit(onSuccess: @escaping (Address?) -> Void) {
        isSaving = true

        let params: [String: Any] = [
            "full_name": fullName.trim,
            "mobile": mobile.trim,
            // Sent even when blank, matching the form the API is documented against.
            "alternate_mobile": alternateMobile.trim,
            "pin_code": pinCode,
            "state": state.trim,
            "district": district.trim,
            "area": area.trim,
            "house_flat_no": houseFlatNo.trim,
            "landmark": landmark.trim,
            "is_default": isDefault ? "1" : "0"
        ]

        serviceManagable.storeAddress(params: params)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSaving = false
                if case .failure(let error) = completion {
                    self.show((error as? RequestError)?.errorString ?? error.localizedDescription)
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSaving = false
                if response.status == true {
                    onSuccess(response.address)
                } else {
                    self.show(response.message ?? "Could not save this address.")
                }
            }
            .store(in: &cancellables)
    }

    private func show(_ message: String) {
        toastMessage = message
        isShowToastView = true
    }
}
