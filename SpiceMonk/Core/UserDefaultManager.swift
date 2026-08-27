//
//  UserDefaultManager.swift
//  SpiceMonk
//

import Foundation

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

    var authHeader: RequestConstants.Header {
        let token = getUserDefaultsString(key: .authToken)
        guard !token.isEmptyString else { return [:] }
        return ["Authorization": "Bearer \(token)"]
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
