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

    func startUpdatingLocation() {
        requestLocationPermission()
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    /// Reverse geocodes a coordinate using GMSGeocoder first, and falls back to CLGeocoder.
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> ResolvedLocationInfo {
        isGeocoding = true
        defer { isGeocoding = false }

        // Attempt 1: GMSGeocoder
        if let gmsResult = await reverseGeocodeWithGMS(coordinate: coordinate) {
            self.lastResolvedInfo = gmsResult
            return gmsResult
        }

        // Attempt 2: CLGeocoder fallback
        let clResult = await reverseGeocodeWithApple(coordinate: coordinate)
        self.lastResolvedInfo = clResult
        return clResult
    }

    private func reverseGeocodeWithGMS(coordinate: CLLocationCoordinate2D) async -> ResolvedLocationInfo? {
        await withCheckedContinuation { (continuation: CheckedContinuation<ResolvedLocationInfo?, Never>) in
            gmsGeocoder.reverseGeocodeCoordinate(coordinate) { response, error in
                guard error == nil, let first = response?.firstResult() else {
                    continuation.resume(returning: nil)
                    return
                }

                let lines = first.lines ?? []
                let fullAddress = lines.joined(separator: ", ")

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
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let mark = placemarks.first else {
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
