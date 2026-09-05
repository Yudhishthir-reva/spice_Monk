//
//  AuthSessionManager.swift
//  SpiceMonk
//
//  Guest browse uses `guest-login` + Bearer guest_token. Real OTP replaces that session
//  and `merge-guest-cart` copies the guest basket onto the account.
//

import Foundation
import SwiftUI
import Combine

enum UnauthorizedAccessNotification {
    static let name = NSNotification.Name("UnauthorizedAccess")
}

@MainActor
final class LoginGate: ObservableObject {

    static let shared = LoginGate()

    @Published var isPresented = false
    @Published private(set) var isLoggedIn = UserDefaultManager.shared.isUserLoggedIn

    private var pendingAction: (() -> Void)?

    private init() {}

    func requireLogin(then action: (() -> Void)? = nil) {
        if UserDefaultManager.shared.isUserLoggedIn {
            isLoggedIn = true
            action?()
            return
        }
        pendingAction = action
        isPresented = true
    }

    func markLoggedIn() {
        isLoggedIn = true
        isPresented = false
        let action = pendingAction
        pendingAction = nil
        CartStore.shared.reloadAfterLogin()
        action?()
    }

    func dismiss() {
        isPresented = false
        pendingAction = nil
    }

    func didEndSession() {
        isLoggedIn = false
        isPresented = false
        pendingAction = nil
    }
}

final class GuestSessionManager {

    static let shared = GuestSessionManager()

    private var cancellables = Set<AnyCancellable>()
    private let loginService = LoginServiceManager()

    private init() {}

    func ensureSession(completion: @escaping () -> Void) {
        if UserDefaultManager.shared.isUserLoggedIn {
            completion()
            return
        }
        if UserDefaultManager.shared.hasValidGuestToken {
            completion()
            return
        }
        loginService.guestLogin()
            .receive(on: DispatchQueue.main)
            .sink { result in
                if case .failure(let error) = result {
                    print("❌ [GuestSession] guest-login failed: \(error)")
                }
                completion()
            } receiveValue: { response in
                if response.status == true, let token = response.guestToken, !token.isEmpty {
                    UserDefaultManager.shared.saveGuestSession(token: token, expiresIn: response.expiresIn)
                }
            }
            .store(in: &cancellables)
    }

    func mergeGuestCartThen(completion: @escaping () -> Void) {
        let token = UserDefaultManager.shared.guestToken
        guard UserDefaultManager.shared.isUserLoggedIn, !token.isEmptyString else {
            UserDefaultManager.shared.clearGuestSession()
            completion()
            return
        }
        loginService.mergeGuestCart(guestToken: token)
            .receive(on: DispatchQueue.main)
            .sink { result in
                if case .failure(let error) = result {
                    print("❌ [GuestSession] merge-guest-cart failed: \(error)")
                }
                UserDefaultManager.shared.clearGuestSession()
                completion()
            } receiveValue: { response in
                print("✅ [GuestSession] \(response.message ?? "Cart merged.")")
            }
            .store(in: &cancellables)
    }
}

final class AuthSessionManager {

    static let shared = AuthSessionManager()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnauthorized),
            name: UnauthorizedAccessNotification.name,
            object: nil
        )
    }

    func start() {}

    @objc private func handleUnauthorized() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if UserDefaultManager.shared.isUserLoggedIn {
                self.endSessionToLogin()
                return
            }
            let hadGuest = !UserDefaultManager.shared.guestToken.isEmptyString
            UserDefaultManager.shared.clearGuestSession()
            if hadGuest {
                CartStore.shared.reset()
                LoginGate.shared.didEndSession()
                AppRootManager.shared.setRootView(view: LoginScreen())
            }
        }
    }

    func redirectToLogin() {
        endSessionToLogin()
    }

    private func endSessionToLogin() {
        UserDefaultManager.shared.resetUserData()
        UserDefaultManager.shared.clearGuestSession()
        CartStore.shared.reset()
        LoginGate.shared.didEndSession()
        AppRootManager.shared.setRootView(view: LoginScreen())
    }
}
