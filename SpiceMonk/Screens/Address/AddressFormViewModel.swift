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
    @Published var area = ""
    @Published var houseFlatNo = ""
    @Published var landmark = ""
    @Published var isDefault = false

    /// Resolved from the PIN rather than typed, because saving needs the ids behind these names and
    /// only `by-pincode` can supply them.
    @Published private(set) var resolvedLocation: PincodeLocation?
    @Published private(set) var isLookingUpPincode = false
    @Published private(set) var pincodeError: String?

    @Published private(set) var isSaving = false
    @Published var isShowToastView = false
    @Published var toastMessage = ""

    private var cancellables = Set<AnyCancellable>()
    private var lookupCancellable: AnyCancellable?
    var serviceManagable = AddressServiceManager()

    private static let pinCodeLength = 6

    var canSave: Bool {
        resolvedLocation != nil && !isSaving
    }

    /// Called as the PIN field changes. A lookup only fires on a complete PIN, and any previously
    /// resolved city is cleared the moment the PIN stops matching it — otherwise an edited PIN
    /// could be saved against the old city's ids.
    func pinCodeChanged() {
        let digits = String(pinCode.filter(\.isNumber).prefix(Self.pinCodeLength))
        if digits != pinCode {
            pinCode = digits
        }

        lookupCancellable?.cancel()
        resolvedLocation = nil
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
                if let location = response.location, location.cityId > 0 {
                    self.resolvedLocation = location
                } else {
                    self.pincodeError = response.message ?? "We don't deliver to this PIN code yet."
                }
            }
    }

    func save(onSuccess: @escaping (Address?) -> Void) {
        guard let location = resolvedLocation else {
            show("Enter a PIN code so we can confirm your city.")
            return
        }
        guard let validationError = firstValidationError else {
            submit(location: location, onSuccess: onSuccess)
            return
        }
        show(validationError)
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
        if houseFlatNo.trim.isEmptyString {
            return "Please enter your house or flat number."
        }
        if area.trim.isEmptyString {
            return "Please enter your area."
        }
        return nil
    }

    private func submit(location: PincodeLocation, onSuccess: @escaping (Address?) -> Void) {
        isSaving = true

        let params: [String: Any] = [
            "full_name": fullName.trim,
            "mobile": mobile.trim,
            // Sent even when blank, matching the form the API is documented against.
            "alternate_mobile": alternateMobile.trim,
            "pin_code": pinCode,
            "state_id": location.stateId,
            "city_id": location.cityId,
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
