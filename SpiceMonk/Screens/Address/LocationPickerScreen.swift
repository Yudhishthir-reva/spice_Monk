//
//  LocationPickerScreen.swift
//  SpiceMonk
//

import SwiftUI
import CoreLocation
import GoogleMaps
import GooglePlaces

struct LocationPickerScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager.shared

    @State private var centerCoordinate: CLLocationCoordinate2D = LocationManager.defaultCoordinate
    @State private var isDraggingMap: Bool = false
    @State private var resolvedInfo: ResolvedLocationInfo?
    @State private var isResolving: Bool = false
    @State private var geocodeTask: Task<Void, Never>?

    // Search state
    @State private var searchQuery: String = ""
    @State private var searchResults: [PlaceSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var showSearchResults: Bool = false

    let onLocationSelected: (ResolvedLocationInfo) -> Void

    struct PlaceSearchResult: Identifiable {
        let id: String
        let title: String
        let subtitle: String
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Google Map View
                GoogleMapView(
                    centerCoordinate: $centerCoordinate,
                    zoomLevel: 16.0,
                    isMyLocationEnabled: true,
                    showsMyLocationButton: false,
                    showsCompass: true,
                    onCameraIdle: { newCoord in
                        isDraggingMap = false
                        resolveAddress(for: newCoord)
                    },
                    onCameraMoveStarted: { gesture in
                        if gesture {
                            isDraggingMap = true
                        }
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // 2. Center Location Pin (Interactive Bouncing Pin)
                centerPinView

                // 3. Floating Controls & Top Search Bar
                VStack(spacing: 0) {
                    searchBarView
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if showSearchResults && !searchResults.isEmpty {
                        searchResultsList
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    Spacer()

                    HStack {
                        Spacer()
                        myLocationFloatingButton
                            .padding(.trailing, 16)
                            .padding(.bottom, 12)
                    }

                    // 4. Bottom Location Card
                    bottomAddressCard
                }
            }
            .navigationTitle("Select location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .onAppear {
                setupInitialLocation()
            }
            .onChange(of: locationManager.currentLocation) { _, newLoc in
                if let loc = newLoc {
                    centerCoordinate = loc.coordinate
                }
            }
        }
    }

    // MARK: - Center Pin
    private var centerPinView: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(AppTheme.brandGreen)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
                .offset(y: isDraggingMap ? -16 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDraggingMap)

            // Pin Shadow / Ground Anchor
            Ellipse()
                .fill(Color.black.opacity(isDraggingMap ? 0.15 : 0.3))
                .frame(width: isDraggingMap ? 8 : 12, height: isDraggingMap ? 4 : 6)
                .offset(y: -4)
                .animation(.easeInOut(duration: 0.2), value: isDraggingMap)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.brandGreen)
                .font(.system(size: 16, weight: .semibold))

            TextField("Search area, landmark or street...", text: $searchQuery)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textPrimary)
                .autocorrectionDisabled()
                .onChange(of: searchQuery) { _, query in
                    handleSearchQueryChange(query)
                }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = []
                    showSearchResults = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    // MARK: - Search Results Dropdown
    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchResults) { result in
                Button {
                    selectSearchResult(result)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(AppTheme.brandGreen)
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)

                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if result.id != searchResults.last?.id {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        .frame(maxHeight: 220)
    }

    // MARK: - My Location Button
    private var myLocationFloatingButton: some View {
        Button {
            moveToCurrentLocation()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)

                if locationManager.isLocating {
                    ProgressView()
                } else {
                    Image(systemName: "location.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.brandGreen)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Address Card
    private var bottomAddressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.brandGreen)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isDraggingMap ? "Locating..." : (resolvedInfo?.area.isEmpty == false ? resolvedInfo!.area : "Selected Location"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if isResolving {
                        Text("Fetching address...")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else if let info = resolvedInfo, !info.formattedAddress.isEmpty {
                        Text(info.formattedAddress)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    } else {
                        Text("Move pin to your exact delivery location")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }

                Spacer()

                if isResolving {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let info = resolvedInfo, (!info.city.isEmpty || !info.postalCode.isEmpty) {
                HStack(spacing: 8) {
                    if !info.postalCode.isEmpty {
                        Text("PIN: \(info.postalCode)")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentSoft)
                            .foregroundStyle(AppTheme.brandGreen)
                            .clipShape(Capsule())
                    }

                    if !info.city.isEmpty {
                        Text(info.city)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.brandBackgroundMid)
                            .foregroundStyle(AppTheme.textSecondary)
                            .clipShape(Capsule())
                    }
                }
            }

            // Confirm Location Action Button
            Button {
                if let info = resolvedInfo {
                    onLocationSelected(info)
                    dismiss()
                } else {
                    let fallback = ResolvedLocationInfo(coordinate: centerCoordinate)
                    onLocationSelected(fallback)
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Confirm location")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.ctaGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: AppTheme.brandGreen.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isResolving)
        }
        .padding(20)
        .background(
            Color.white
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: -4)
        )
    }

    // MARK: - Actions & Geocoding
    private func setupInitialLocation() {
        if let current = locationManager.currentLocation {
            centerCoordinate = current.coordinate
            resolveAddress(for: current.coordinate)
        } else {
            locationManager.requestCurrentLocation()
            resolveAddress(for: centerCoordinate)
        }
    }

    private func moveToCurrentLocation() {
        locationManager.requestCurrentLocation()
        if let current = locationManager.currentLocation {
            centerCoordinate = current.coordinate
            resolveAddress(for: current.coordinate)
        }
    }

    private func resolveAddress(for coordinate: CLLocationCoordinate2D) {
        geocodeTask?.cancel()
        isResolving = true
        geocodeTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if Task.isCancelled { return }

            let info = await locationManager.reverseGeocode(coordinate: coordinate)
            if !Task.isCancelled {
                self.resolvedInfo = info
                self.isResolving = false
            }
        }
    }

    private func handleSearchQueryChange(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            searchResults = []
            showSearchResults = false
            return
        }

        isSearching = true
        showSearchResults = true

        let filter = GMSAutocompleteFilter()
        filter.countries = ["IN"]

        GMSPlacesClient.shared().findAutocompletePredictions(
            fromQuery: trimmed,
            filter: filter,
            sessionToken: nil
        ) { predictions, error in
            Task { @MainActor in
                self.isSearching = false
                if let predictions = predictions, !predictions.isEmpty {
                    self.searchResults = predictions.map {
                        PlaceSearchResult(
                            id: $0.placeID,
                            title: $0.attributedPrimaryText.string,
                            subtitle: $0.attributedSecondaryText?.string ?? ""
                        )
                    }
                } else {
                    // Fallback to CLGeocoder search
                    searchWithAppleGeocoder(query: trimmed)
                }
            }
        }
    }

    private func searchWithAppleGeocoder(query: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(query) { placemarks, _ in
            Task { @MainActor in
                guard let marks = placemarks else {
                    self.searchResults = []
                    return
                }
                self.searchResults = marks.enumerated().map { index, mark in
                    let title = mark.name ?? mark.locality ?? query
                    let sub = [mark.subLocality, mark.locality, mark.administrativeArea, mark.postalCode]
                        .compactMap { $0 }.joined(separator: ", ")
                    return PlaceSearchResult(id: "\(index)-\(title)", title: title, subtitle: sub)
                }
            }
        }
    }

    private func selectSearchResult(_ result: PlaceSearchResult) {
        showSearchResults = false
        searchQuery = result.title

        // Fetch place details from GMSPlacesClient
        let fields: GMSPlaceField = [.coordinate, .formattedAddress, .addressComponents, .name]
        GMSPlacesClient.shared().fetchPlace(
            fromPlaceID: result.id,
            placeFields: fields,
            sessionToken: nil
        ) { place, error in
            Task { @MainActor in
                if let place = place {
                    self.centerCoordinate = place.coordinate
                    self.resolveAddress(for: place.coordinate)
                } else {
                    // Fallback with geocoding text
                    let geocoder = CLGeocoder()
                    geocoder.geocodeAddressString("\(result.title), \(result.subtitle)") { placemarks, _ in
                        if let coord = placemarks?.first?.location?.coordinate {
                            Task { @MainActor in
                                self.centerCoordinate = coord
                                self.resolveAddress(for: coord)
                            }
                        }
                    }
                }
            }
        }
    }
}
