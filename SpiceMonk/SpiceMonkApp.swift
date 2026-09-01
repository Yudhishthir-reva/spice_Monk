//
//  SpiceMonkApp.swift
//  SpiceMonk
//

import SwiftUI

@main
struct SpiceMonkApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .font(.dmSans(14, weight: .regular))
                .preferredColorScheme(.light)
                .dynamicTypeSize(.large)
                .handleNoInternet()
                .handleAppStatusOverlays()
                .onAppear {
                    UIApplication.shared.addTapGestureToDismissKeyboard()
                }
        }
    }
}
