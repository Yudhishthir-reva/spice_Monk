//
//  UserDefaultManager.swift
//  SpiceMonk
//

import Foundation
import UIKit

class UserDefaultManager {

    static let shared = UserDefaultManager()

    enum PersistenceKeys: String {
        case sellerId
        case userMobile
        case userName
        case authToken
        case refreshToken
        case tokenExpiry
        case whatsappNumber
        case googleMapKey
        case codEnabled
        case fcmToken
        case deviceId
        case guestToken
        case guestTokenExpiry
    }

    func setUserDefaultsString(value: String, key: PersistenceKeys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
        UserDefaults.standard.synchronize()
    }

    func setUserDefaultsBool(value: Bool, key: PersistenceKeys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
        UserDefaults.standard.synchronize()
    }

    func getUserDefaultsString(key: PersistenceKeys) -> String {
        UserDefaults.standard.value(forKey: key.rawValue) as? String ?? ""
    }

    func getUserDefaultsBool(key: PersistenceKeys) -> Bool {
        UserDefaults.standard.value(forKey: key.rawValue) as? Bool ?? false
    }

    var whatsappNumber: String {
        let stored = getUserDefaultsString(key: .whatsappNumber)
        return stored.isEmptyString ? "919999999999" : stored
    }

    var googleMapKey: String {
        getUserDefaultsString(key: .googleMapKey)
    }

    var isCodEnabled: Bool {
        if UserDefaults.standard.object(forKey: PersistenceKeys.codEnabled.rawValue) == nil {
            return true
        }
        return getUserDefaultsBool(key: .codEnabled)
    }

    var fcmToken: String {
        get { getUserDefaultsString(key: .fcmToken) }
        set { setUserDefaultsString(value: newValue, key: .fcmToken) }
    }

    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        if !identifier.isEmpty {
            return identifier
        }
        return UIDevice.current.model
    }

    var deviceId: String {
        let storedFcm = fcmToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedFcm.isEmpty {
            return storedFcm
        }
        let storedId = getUserDefaultsString(key: .deviceId)
        if !storedId.isEmpty {
            return storedId
        }
        let newId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        setUserDefaultsString(value: newId, key: .deviceId)
        return newId
    }

    var deviceInfoJSONString: String {
        let dict: [String: String] = [
            "deviceId": deviceId,
            "deviceModel": deviceModel
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{\"deviceId\":\"\(deviceId)\",\"deviceModel\":\"\(deviceModel)\"}"
    }

    /// Stores when the access token stops being usable, derived from the `expires_in` seconds the
    /// login response carries, so a refresh can be triggered before a request is rejected.
    func setTokenExpiry(secondsFromNow: Int?) {
        guard let secondsFromNow, secondsFromNow > 0 else {
            UserDefaults.standard.removeObject(forKey: PersistenceKeys.tokenExpiry.rawValue)
            return
        }
        let expiry = Date().addingTimeInterval(TimeInterval(secondsFromNow))
        UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: PersistenceKeys.tokenExpiry.rawValue)
    }

    var tokenExpiry: Date? {
        let stored = UserDefaults.standard.double(forKey: PersistenceKeys.tokenExpiry.rawValue)
        guard stored > 0 else { return nil }
        return Date(timeIntervalSince1970: stored)
    }

    var isUserLoggedIn: Bool {
        !getUserDefaultsString(key: .authToken).isEmptyString
    }

    var guestToken: String {
        get { getUserDefaultsString(key: .guestToken) }
        set { setUserDefaultsString(value: newValue, key: .guestToken) }
    }

    var hasValidGuestToken: Bool {
        let token = guestToken
        guard !token.isEmptyString else { return false }
        let expiry = UserDefaults.standard.double(forKey: PersistenceKeys.guestTokenExpiry.rawValue)
        if expiry > 0, Date().timeIntervalSince1970 >= expiry - 60 {
            return false
        }
        return true
    }

    func saveGuestSession(token: String, expiresIn: Int?) {
        guestToken = token
        guard let expiresIn, expiresIn > 0 else {
            UserDefaults.standard.removeObject(forKey: PersistenceKeys.guestTokenExpiry.rawValue)
            return
        }
        let expiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: PersistenceKeys.guestTokenExpiry.rawValue)
    }

    func clearGuestSession() {
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.guestToken.rawValue)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.guestTokenExpiry.rawValue)
    }

    var authHeader: RequestConstants.Header {
        let userToken = getUserDefaultsString(key: .authToken)
        if !userToken.isEmptyString {
            return ["Authorization": "Bearer \(userToken)"]
        }
        let guest = guestToken
        guard !guest.isEmptyString else { return [:] }
        return ["Authorization": "Bearer \(guest)"]
    }

    func resetUserData() {
        setUserDefaultsString(value: "", key: .sellerId)
        setUserDefaultsString(value: "", key: .userMobile)
        setUserDefaultsString(value: "", key: .userName)
        setUserDefaultsString(value: "", key: .authToken)
        setUserDefaultsString(value: "", key: .refreshToken)
        setTokenExpiry(secondsFromNow: nil)
    }
}
