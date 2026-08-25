//
//  AuthSessionManager.swift
//  SpiceMonk
//
//  Watches for 401 Unauthorized responses from any API call. When one arrives, it clears
//  stored credentials and switches the app's root view controller to the login screen so the
//  user is forced back to sign in.

import Foundation
import SwiftUI

enum UnauthorizedAccessNotification {
    static let name = NSNotification.Name("UnauthorizedAccess")
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

    /// Explicit method to ensure singleton observer is active at app launch
    func start() {
        // Observer initialized in init()
    }

    @objc private func handleUnauthorized() {
        // Always dispatch to main — the Combine pipeline may post from a background queue.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Avoid duplicate triggers if credentials have already been cleared
            guard UserDefaultManager.shared.isUserLoggedIn else { return }
            self.redirectToLogin()
        }
    }

    func redirectToLogin() {
        // Clear stored credentials
        UserDefaultManager.shared.resetUserData()

        // Reset in-memory cart state
        CartStore.shared.reset()

        // Switch root view to login screen
        AppRootManager.shared.setRootView(view: LoginScreen())
    }
}
