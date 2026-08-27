//
//  GoogleMapsConfig.swift
//  SpiceMonk
//

import Foundation
import GoogleMaps
import GooglePlaces

enum GoogleMapsConfig {
    /// Reads Google Maps API Key from UserDefaultManager (check-status API) or Info.plist fallback.
    static var apiKey: String {
        let stored = UserDefaultManager.shared.googleMapKey
        if !stored.isEmptyString {
            return stored
        }
        let keys = ["GoogleMapsAPIKey", "GMSApiKey", "GOOGLE_MAPS_API_KEY"]
        for key in keys {
            if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed != "YOUR_GOOGLE_MAPS_API_KEY" {
                    return trimmed
                }
            }
        }
        return ""
    }

    private static var isInitialized = false

    static func setup() {
        let key = apiKey
        guard !key.isEmpty else {
            print("⚠️ [GoogleMapsConfig] Google Maps API key is not configured.")
            return
        }
        provideAPIKey(key)
    }

    static func provideAPIKey(_ key: String) {
        guard !key.isEmpty else { return }
        GMSServices.provideAPIKey(key)
        GMSPlacesClient.provideAPIKey(key)
        isInitialized = true
        print("✅ [GoogleMapsConfig] Google Maps & Places initialized successfully with key: \(key.prefix(8))...")
    }
}
