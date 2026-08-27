//
//  AppDelegate.swift
//  SpiceMonk
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        GoogleMapsConfig.setup()
        setupTypographyAppearance()
        registerForPushNotifications()
        NetworkMonitor.shared.start()
        AuthSessionManager.shared.start()
        return true
    }

    private func setupTypographyAppearance() {
        UIView.appearance().overrideUserInterfaceStyle = .light

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(red: 22/255, green: 116/255, blue: 68/255, alpha: 1.0)
        navBarAppearance.titleTextAttributes = [
            .font: UIFont.appFont(size: 17, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .font: UIFont.appFont(size: 28, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        let barButtonItemAppearance = UIBarButtonItemAppearance()
        barButtonItemAppearance.normal.titleTextAttributes = [
            .font: UIFont.appFont(size: 15, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        barButtonItemAppearance.highlighted.titleTextAttributes = [
            .font: UIFont.appFont(size: 15, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        navBarAppearance.buttonAppearance = barButtonItemAppearance
        navBarAppearance.backButtonAppearance = barButtonItemAppearance
        navBarAppearance.doneButtonAppearance = barButtonItemAppearance

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = .white
        UIBarButtonItem.appearance().tintColor = .white
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )

        UIApplication.shared.registerForRemoteNotifications()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
