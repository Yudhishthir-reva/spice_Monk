//
//  LoginViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class LoginViewModel: ObservableObject {

    @Published var mobile: String = ""
    @Published var isShowProcessing = false
    @Published var isShowToastView = false
    @Published var toastMessage = ""
    @Published var goToOTP = false

    private var cancellables = Set<AnyCancellable>()
    var serviceManagable = LoginServiceManager()

    func sendOTP() {
        guard validateData else {
            isShowToastView = true
            return
        }

        if !NetworkMonitor.shared.isConnected {
            toastMessage = RequestError.noInternet.errorString
            isShowToastView = true
            return
        }

        isShowProcessing = true

        let params = ["mobile": mobile.trim]

        serviceManagable.sendOTP(params: params, headers: [:])
            .receive(on: RunLoop.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self.isShowProcessing = false
                    if let err = error as? RequestError {
                        self.toastMessage = err.errorString
                    } else {
                        self.toastMessage = error.localizedDescription
                    }
                    self.isShowToastView = true
                }
            } receiveValue: { [weak self] model in
                guard let self else { return }
                self.isShowProcessing = false
                if model.status == true {
                    self.goToOTP = true
                } else {
                    self.toastMessage = model.message ?? "Unable to send OTP."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }

    var validateData: Bool {
        let number = mobile.trim.replacingOccurrences(of: " ", with: "")
        if number.isEmptyString {
            toastMessage = "Please enter mobile number."
            return false
        }
        if !number.isValidIndianMobileNumber() {
            toastMessage = "Please enter a valid 10-digit mobile number."
            return false
        }
        return true
    }
}
