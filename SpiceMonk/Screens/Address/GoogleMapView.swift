//
//  GoogleMapView.swift
//  SpiceMonk
//

import SwiftUI
import GoogleMaps

struct MapMarkerItem: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let snippet: String?
    let icon: UIImage?

    static func == (lhs: MapMarkerItem, rhs: MapMarkerItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.title == rhs.title &&
        lhs.snippet == rhs.snippet
    }
}

struct GoogleMapView: UIViewRepresentable {

    @Binding var centerCoordinate: CLLocationCoordinate2D
    var zoomLevel: Float = 15.0
    var markers: [MapMarkerItem] = []
    var isMyLocationEnabled: Bool = true
    var showsMyLocationButton: Bool = false
    var showsCompass: Bool = true
    var isUserInteractionEnabled: Bool = true

    var onCameraIdle: ((CLLocationCoordinate2D) -> Void)?
    var onCameraMoveStarted: ((_ gesture: Bool) -> Void)?
    var onMarkerTapped: ((MapMarkerItem) -> Void)?

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: centerCoordinate.latitude,
            longitude: centerCoordinate.longitude,
            zoom: zoomLevel
        )
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = isMyLocationEnabled
        mapView.settings.myLocationButton = showsMyLocationButton
        mapView.settings.compassButton = showsCompass
        mapView.settings.setAllGesturesEnabled(isUserInteractionEnabled)

        context.coordinator.mapView = mapView
        context.coordinator.syncMarkers(markers: markers, mapView: mapView)

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.isMyLocationEnabled = isMyLocationEnabled
        mapView.settings.myLocationButton = showsMyLocationButton
        mapView.settings.compassButton = showsCompass
        mapView.settings.setAllGesturesEnabled(isUserInteractionEnabled)

        // Only animate camera if coordinate significantly changed from external update
        let currentTarget = mapView.camera.target
        let latDiff = abs(currentTarget.latitude - centerCoordinate.latitude)
        let lonDiff = abs(currentTarget.longitude - centerCoordinate.longitude)

        if (latDiff > 0.0001 || lonDiff > 0.0001) && !context.coordinator.isUserDragging {
            let update = GMSCameraUpdate.setTarget(centerCoordinate, zoom: zoomLevel)
            mapView.animate(with: update)
        }

        context.coordinator.syncMarkers(markers: markers, mapView: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        weak var mapView: GMSMapView?
        var isUserDragging: Bool = false
        private var displayedMarkers: [String: GMSMarker] = [:]

        init(_ parent: GoogleMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            isUserDragging = gesture
            parent.onCameraMoveStarted?(gesture)
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            isUserDragging = false
            parent.centerCoordinate = position.target
            parent.onCameraIdle?(position.target)
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let markerId = marker.userData as? String,
               let item = parent.markers.first(where: { $0.id == markerId }) {
                parent.onMarkerTapped?(item)
                return true
            }
            return false
        }

        func syncMarkers(markers: [MapMarkerItem], mapView: GMSMapView) {
            let newIds = Set(markers.map(\.id))
            let existingIds = Set(displayedMarkers.keys)

            // Remove old markers
            for removedId in existingIds.subtracting(newIds) {
                displayedMarkers[removedId]?.map = nil
                displayedMarkers.removeValue(forKey: removedId)
            }

            // Update or add markers
            for item in markers {
                if let existing = displayedMarkers[item.id] {
                    existing.position = item.coordinate
                    existing.title = item.title
                    existing.snippet = item.snippet
                    if let icon = item.icon {
                        existing.icon = icon
                    }
                } else {
                    let marker = GMSMarker(position: item.coordinate)
                    marker.title = item.title
                    marker.snippet = item.snippet
                    marker.userData = item.id
                    if let icon = item.icon {
                        marker.icon = icon
                    }
                    marker.map = mapView
                    displayedMarkers[item.id] = marker
                }
            }
        }
    }
}
