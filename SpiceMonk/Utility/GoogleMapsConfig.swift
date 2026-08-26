//
//  GoogleMapsConfig.swift
//  SpiceMonk
//

import Foundation
import GoogleMaps
import GooglePlaces

enum GoogleMapsConfig {
    /// Reads Google Maps API Key from Info.plist / Bundle infoDictionary.
    /// Supported Info.plist keys: "GoogleMapsAPIKey", "GMSApiKey", "GOOGLE_MAPS_API_KEY"
    static var apiKey: String {
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

    static func setup() {
        let key = apiKey
        guard !key.isEmpty else {
            print("⚠️ [GoogleMapsConfig] Google Maps API key is not configured in Info.plist (Key: GoogleMapsAPIKey).")
            return
        }

        GMSServices.provideAPIKey(key)
        GMSPlacesClient.provideAPIKey(key)
        print("✅ [GoogleMapsConfig] Google Maps & Places initialized successfully from Info.plist.")
    }
}
