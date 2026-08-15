//
//  AppRootManager.swift
//  SpiceMonk
//

import Foundation
import SwiftUI
import UIKit

final class AppRootManager {

    static var shared = AppRootManager()

    var isSheetPresented = false

    func setRootView<T: View>(view: T, window: UIWindow? = nil) {
        let targetWindow = window ?? UIApplication.shared.keyWindow
        guard let targetWindow else { return }

        targetWindow.rootViewController = UIHostingController(rootView: view.handleNoInternet())
        UIView.transition(
            with: targetWindow,
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: nil,
            completion: nil
        )
    }
}

extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
