//
//  OTPVerifyViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

/// Matches the Android cooldown so both platforms gate resends identically.
private let resendCooldownSeconds = 30

class OTPVerifyViewModel: ObservableObject {

    let mobile: String

    @Published var otp: String = ""
    @Published var isShowProcessing = false
    @Published var isShowToastView = false
    @Published var toastMessage = ""
    @Published var secondsRemaining = resendCooldownSeconds

    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    var serviceManagable = LoginServiceManager()

    var canResend: Bool { secondsRemaining <= 0 }

    init(mobile: String, prefilledOTP: String = "") {
        self.mobile = mobile.replacingOccurrences(of: " ", with: "")
        self.otp = prefilledOTP
        startTimer()
    }

    func startTimer() {
        secondsRemaining = resendCooldownSeconds
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.secondsRemaining > 0 {
                    self.secondsRemaining -= 1
                } else {
                    self.timerCancellable?.cancel()
                }
            }
    }

    var timerText: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    func verifyOTP() {
        guard otp.count == 6 else {
            toastMessage = "Please enter the 6-digit OTP."
            isShowToastView = true
            return
        }

        if !NetworkMonitor.shared.isConnected {
            toastMessage = RequestError.noInternet.errorString
            isShowToastView = true
            return
        }

        isShowProcessing = true

        let params: [String: Any] = [
            "mobile": mobile,
            "otp": otp,
            "device_info": UserDefaultManager.shared.deviceInfoJSONString
        ]

        var headers = UserDefaultManager.shared.authHeader
        headers["Accept"] = "application/json"

        serviceManagable.verifyOTP(params: params, headers: headers)
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

                if model.status == true, let token = model.accessToken, !token.isEmpty {
                    let defaults = UserDefaultManager.shared
                    defaults.setUserDefaultsString(value: token, key: .authToken)
                    defaults.setUserDefaultsString(value: model.refreshToken ?? "", key: .refreshToken)
                    defaults.setUserDefaultsString(value: model.sellerId ?? "", key: .sellerId)
                    defaults.setUserDefaultsString(value: model.mobile ?? self.mobile, key: .userMobile)
                    defaults.setUserDefaultsString(value: model.name ?? "", key: .userName)
                    defaults.setTokenExpiry(secondsFromNow: model.expiresIn)
                    AppRootManager.shared.setRootView(view: HomeScreen())
                } else {
                    self.toastMessage = model.message ?? "Invalid OTP."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }

    func resendOTP() {
        guard canResend else { return }
        if !NetworkMonitor.shared.isConnected {
            toastMessage = RequestError.noInternet.errorString
            isShowToastView = true
            return
        }

        serviceManagable.sendOTP(params: ["mobile": mobile], headers: [:])
            .receive(on: RunLoop.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    if let err = error as? RequestError {
                        self.toastMessage = err.errorString
                    } else {
                        self.toastMessage = error.localizedDescription
                    }
                    self.isShowToastView = true
                }
            } receiveValue: { [weak self] model in
                guard let self else { return }
                if model.status == true {
                    self.otp = OTPSendModel.usableOTP(from: model.otp)
                    self.startTimer()
                    self.toastMessage = model.message ?? "OTP sent successfully."
                    self.isShowToastView = true
                } else {
                    self.toastMessage = model.message ?? "Unable to resend OTP."
                    self.isShowToastView = true
                }
            }
            .store(in: &cancellables)
    }
}
