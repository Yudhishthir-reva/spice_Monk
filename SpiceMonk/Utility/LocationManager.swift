//
//  LocationManager.swift
//  SpiceMonk
//

import Foundation
import CoreLocation
import Combine
import GoogleMaps

struct ResolvedLocationInfo: Equatable {
    var coordinate: CLLocationCoordinate2D
    var formattedAddress: String = ""
    var street: String = ""
    var area: String = ""
    var city: String = ""
    var state: String = ""
    var postalCode: String = ""
    var country: String = ""

    static func == (lhs: ResolvedLocationInfo, rhs: ResolvedLocationInfo) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.formattedAddress == rhs.formattedAddress
    }
}

@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isLocating: Bool = false
    @Published var lastResolvedInfo: ResolvedLocationInfo?
    @Published var isGeocoding: Bool = false
    @Published var errorMessage: String?

    // Default fallback coordinate (e.g. Mumbai, India)
    static let defaultCoordinate = CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let gmsGeocoder = GMSGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestLocationPermission() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func requestCurrentLocation() {
        requestLocationPermission()
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        isLocating = true
        locationManager.requestLocation()
    }

    func fetchCurrentLocationAndResolve(completion: @escaping (ResolvedLocationInfo?) -> Void) {
        requestLocationPermission()
        if let loc = currentLocation {
            Task { @MainActor in
                let info = await self.reverseGeocode(coordinate: loc.coordinate)
                completion(info)
            }
            return
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            completion(nil)
            return
        }

        isLocating = true
        locationManager.requestLocation()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if let loc = self.currentLocation {
                let info = await self.reverseGeocode(coordinate: loc.coordinate)
                completion(info)
            } else {
                let fallback = await self.reverseGeocode(coordinate: Self.defaultCoordinate)
                completion(fallback)
            }
        }
    }

    func startUpdatingLocation() {
        requestLocationPermission()
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    /// Reverse geocodes a coordinate using Google Geocoding REST API first, then GMSGeocoder, then CLGeocoder.
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> ResolvedLocationInfo {
        isGeocoding = true
        defer { isGeocoding = false }

        print("📍 [Geocoding] ===================================================")
        print("📍 [Geocoding] Starting Reverse Geocode for: (\(coordinate.latitude), \(coordinate.longitude))")

        // Attempt 1: Official Google Geocoding REST API (Returns full address with Plus Code & detailed landmarks)
        if let apiResult = await reverseGeocodeWithGoogleMapsAPI(coordinate: coordinate) {
            self.lastResolvedInfo = apiResult
            print("✅ [Geocoding] Resolved using Google Geocoding REST API")
            print("📍 [Geocoding] ===================================================")
            return apiResult
        }

        // Attempt 2: GMSGeocoder SDK
        if let gmsResult = await reverseGeocodeWithGMS(coordinate: coordinate) {
            self.lastResolvedInfo = gmsResult
            print("✅ [Geocoding] Resolved using Google Maps SDK (GMSGeocoder)")
            print("📍 [Geocoding] ===================================================")
            return gmsResult
        }

        // Attempt 3: Apple CLGeocoder fallback
        let clResult = await reverseGeocodeWithApple(coordinate: coordinate)
        self.lastResolvedInfo = clResult
        print("✅ [Geocoding] Resolved using Apple CLGeocoder fallback")
        print("📍 [Geocoding] ===================================================")
        return clResult
    }

    private func reverseGeocodeWithGoogleMapsAPI(coordinate: CLLocationCoordinate2D) async -> ResolvedLocationInfo? {
        let key = GoogleMapsConfig.apiKey
        guard !key.isEmpty else {
            print("⚠️ [Google Geocoding API] Google Maps API key is empty. Skipping REST API.")
            return nil
        }

        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(coordinate.latitude),\(coordinate.longitude)&key=\(key)"
        guard let url = URL(string: urlString) else {
            print("⚠️ [Google Geocoding API] Invalid URL: \(urlString)")
            return nil
        }

        print("🌐 [Google Geocoding API] Request URL: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [Google Geocoding API] Non-HTTP response received.")
                return nil
            }

            print("🌐 [Google Geocoding API] HTTP Status Code: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ [Google Geocoding API] HTTP Error: \(httpResponse.statusCode)")
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ [Google Geocoding API] Failed to parse JSON response.")
                return nil
            }

            let status = json["status"] as? String ?? "UNKNOWN"
            print("🌐 [Google Geocoding API] API Status: \(status)")

            if let errorMessage = json["error_message"] as? String {
                print("⚠️ [Google Geocoding API] API Error Message: \(errorMessage)")
            }

            guard status == "OK",
                  let results = json["results"] as? [[String: Any]],
                  let firstResult = results.first else {
                print("⚠️ [Google Geocoding API] No results found or status not OK: \(status)")
                return nil
            }

            var formattedAddress = firstResult["formatted_address"] as? String ?? ""

            // Extract Plus Code prefix (e.g. "VQH5+4HQ")
            if let plusCodeObj = json["plus_code"] as? [String: Any],
               let compoundCode = plusCodeObj["compound_code"] as? String {
                let codePrefix = compoundCode.components(separatedBy: " ").first ?? ""
                if !codePrefix.isEmpty && !formattedAddress.contains(codePrefix) {
                    formattedAddress = "\(codePrefix), \(formattedAddress)"
                }
            } else if let plusCodeObj = firstResult["plus_code"] as? [String: Any],
                      let compoundCode = plusCodeObj["compound_code"] as? String {
                let codePrefix = compoundCode.components(separatedBy: " ").first ?? ""
                if !codePrefix.isEmpty && !formattedAddress.contains(codePrefix) {
                    formattedAddress = "\(codePrefix), \(formattedAddress)"
                }
            }

            var street = ""
            var area = ""
            var city = ""
            var state = ""
            var postalCode = ""
            var country = ""

            if let components = firstResult["address_components"] as? [[String: Any]] {
                for comp in components {
                    guard let types = comp["types"] as? [String],
                          let longName = comp["long_name"] as? String else { continue }

                    if types.contains("postal_code") {
                        postalCode = longName
                    } else if types.contains("sublocality_level_1") || types.contains("sublocality") {
                        if area.isEmpty { area = longName }
                    } else if types.contains("sublocality_level_2") {
                        if area.isEmpty { area = longName }
                    } else if types.contains("route") || types.contains("street_number") {
                        if street.isEmpty { street = longName } else { street = "\(longName) \(street)" }
                    } else if types.contains("locality") {
                        city = longName
                    } else if types.contains("administrative_area_level_2") && city.isEmpty {
                        city = longName
                    } else if types.contains("administrative_area_level_1") {
                        state = longName
                    } else if types.contains("country") {
                        country = longName
                    }
                }
            }

            if area.isEmpty {
                area = city
            }

            print("📄 [Google Geocoding API] Full Formatted Address: \(formattedAddress)")
            print("🏘️ [Google Geocoding API] Parsed: Street='\(street)', Area='\(area)', City='\(city)', State='\(state)', PIN='\(postalCode)'")

            return ResolvedLocationInfo(
                coordinate: coordinate,
                formattedAddress: formattedAddress,
                street: street,
                area: area,
                city: city,
                state: state,
                postalCode: postalCode,
                country: country
            )
        } catch {
            print("❌ [Google Geocoding API] Network/Parsing Exception: \(error.localizedDescription)")
            return nil
        }
    }

    private func reverseGeocodeWithGMS(coordinate: CLLocationCoordinate2D) async -> ResolvedLocationInfo? {
        print("🗺️ [GMSGeocoder] Calling GMSGeocoder SDK...")
        return await withCheckedContinuation { (continuation: CheckedContinuation<ResolvedLocationInfo?, Never>) in
            gmsGeocoder.reverseGeocodeCoordinate(coordinate) { response, error in
                if let error = error {
                    print("⚠️ [GMSGeocoder] SDK Error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let first = response?.firstResult() else {
                    print("⚠️ [GMSGeocoder] No results found from SDK.")
                    continuation.resume(returning: nil)
                    return
                }

                let lines = first.lines ?? []
                let fullAddress = lines.joined(separator: ", ")

                print("✅ [GMSGeocoder] SDK Result Lines: \(lines)")

                let info = ResolvedLocationInfo(
                    coordinate: coordinate,
                    formattedAddress: fullAddress,
                    street: first.thoroughfare ?? "",
                    area: first.subLocality ?? first.locality ?? "",
                    city: first.locality ?? first.administrativeArea ?? "",
                    state: first.administrativeArea ?? "",
                    postalCode: first.postalCode ?? "",
                    country: first.country ?? ""
                )
                continuation.resume(returning: info)
            }
        }
    }

    private func reverseGeocodeWithApple(coordinate: CLLocationCoordinate2D) async -> ResolvedLocationInfo {
        print("🍏 [Apple CLGeocoder] Calling Apple CLGeocoder...")
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let mark = placemarks.first else {
                print("⚠️ [Apple CLGeocoder] No placemarks returned.")
                return ResolvedLocationInfo(coordinate: coordinate)
            }

            let parts = [
                mark.name,
                mark.subLocality,
                mark.locality,
                mark.administrativeArea,
                mark.postalCode
            ].compactMap { $0 }.filter { !$0.isEmpty }

            let full = parts.joined(separator: ", ")

            print("✅ [Apple CLGeocoder] Formatted Placemark: \(full)")

            return ResolvedLocationInfo(
                coordinate: coordinate,
                formattedAddress: full,
                street: [mark.subThoroughfare, mark.thoroughfare].compactMap { $0 }.joined(separator: " "),
                area: mark.subLocality ?? mark.locality ?? "",
                city: mark.locality ?? mark.subAdministrativeArea ?? "",
                state: mark.administrativeArea ?? "",
                postalCode: mark.postalCode ?? "",
                country: mark.country ?? ""
            )
        } catch {
            print("❌ [Apple CLGeocoder] Exception: \(error.localizedDescription)")
            return ResolvedLocationInfo(coordinate: coordinate)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.isLocating = false
            if let loc = locations.last {
                self.currentLocation = loc
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLocating = false
            self.errorMessage = error.localizedDescription
        }
    }
}
