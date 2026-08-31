//
//  AppDelegate.swift
//  SpiceMonk
//
//  Push Notification & Firebase Cloud Messaging (FCM) setup.
//

import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        setupFirebase()
        GoogleMapsConfig.setup()
        setupTypographyAppearance()
        registerForPushNotifications(application: application)
        NetworkMonitor.shared.start()
        AuthSessionManager.shared.start()
        return true
    }

    private func setupFirebase() {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           FileManager.default.fileExists(atPath: path) {
            FirebaseApp.configure()
            print("✅ [Firebase] Configured successfully with GoogleService-Info.plist")
        } else {
            print("⚠️ [Firebase] GoogleService-Info.plist not found in bundle. Please add GoogleService-Info.plist to your Xcode project.")
        }
        Messaging.messaging().delegate = self
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

    func registerForPushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions
        ) { granted, error in
            if let error = error {
                print("❌ [PushNotification] Authorization error: \(error.localizedDescription)")
            } else {
                print("🔔 [PushNotification] Permission granted: \(granted)")
            }
        }

        application.registerForRemoteNotifications()
    }

    // MARK: - APNs Registration Handlers

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Forward APNs token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ [APNs] Registered with Device Token: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [APNs] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("🔔 [PushNotification] Background notification received: \(userInfo)")
        Messaging.messaging().appDidReceiveMessage(userInfo)
        NotificationCenter.default.post(
            name: NSNotification.Name("PushNotificationReceived"),
            object: nil,
            userInfo: userInfo
        )
        completionHandler(.newData)
    }
}

// MARK: - Firebase Messaging Delegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken, !fcmToken.isEmpty else {
            print("⚠️ [FCM] Received empty or nil FCM token")
            return
        }
        print("✅ [FCM] Registration Token: \(fcmToken)")
        
        // Save to persistent storage
        UserDefaultManager.shared.fcmToken = fcmToken

        // Broadcast token update
        NotificationCenter.default.post(
            name: NSNotification.Name("FCMTokenReceived"),
            object: fcmToken
        )
    }
}

// MARK: - UNUserNotificationCenter Delegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Foreground notification presentation
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("🔔 [PushNotification] Foreground notification received: \(userInfo)")
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Present banner, sound, and badge while in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Notification interaction / tap handling
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("🔔 [PushNotification] Notification tapped: \(userInfo)")
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        NotificationCenter.default.post(
            name: NSNotification.Name("PushNotificationTapped"),
            object: nil,
            userInfo: userInfo
        )
        
        completionHandler()
    }
}
