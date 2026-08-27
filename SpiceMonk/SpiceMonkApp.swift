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
                .handleNoInternet()
                .handleAppStatusOverlays()
        }
    }
}
