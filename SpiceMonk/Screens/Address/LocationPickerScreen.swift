//
//  LocationPickerScreen.swift
//  SpiceMonk
//
//

import SwiftUI
import CoreLocation
import GoogleMaps
import GooglePlaces

/// Interactive Google Map Location Picker matching the screenshot:
/// Top floating back button & search bar, center delivery pin,
/// floating "Use my current location" capsule pill, and bottom "DELIVERING YOUR ORDER TO" card with "Confirm location" CTA.
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

    var initialCoordinate: CLLocationCoordinate2D? = nil
    let onLocationSelected: (ResolvedLocationInfo) -> Void

    struct PlaceSearchResult: Identifiable {
        let id: String
        let title: String
        let subtitle: String
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Google Map Fullscreen
            GoogleMapView(
                centerCoordinate: $centerCoordinate,
                zoomLevel: 16.5,
                isMyLocationEnabled: true,
                showsMyLocationButton: false,
                showsCompass: false,
                onCameraIdle: { newCoord in
                    isDraggingMap = false
                    resolveAddress(for: newCoord)
                },
                onCameraMoveStarted: { gesture in
                    if gesture {
                        isDraggingMap = true
                        showSearchResults = false
                    }
                }
            )
            .ignoresSafeArea()

            // 2. Center Location Pin
            centerPinView

            // 3. Floating Overlay Controls
            VStack(spacing: 0) {
                // Top Search Bar & Back Button
                topFloatingBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Search Predictions Dropdown
                if showSearchResults && !searchResults.isEmpty {
                    searchResultsList
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                Spacer()

                // Floating "Use my current location" Pill
                HStack {
                    useCurrentLocationPill
                        .padding(.leading, 16)
                        .padding(.bottom, 12)

                    Spacer()
                }

                // 4. Bottom "DELIVERING YOUR ORDER TO" Card
                bottomAddressCard
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            setupInitialLocation()
        }
    }

    // MARK: - Center Pin

    private var centerPinView: some View {
        VStack(spacing: 0) {
            ZStack {
                // Custom green teardrop pin
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color(hex: "13683B"))
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 4)
            }
            .offset(y: isDraggingMap ? -16 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDraggingMap)

            // Pin Shadow / Ground Anchor
            Ellipse()
                .fill(Color.black.opacity(isDraggingMap ? 0.12 : 0.28))
                .frame(width: isDraggingMap ? 8 : 12, height: isDraggingMap ? 4 : 6)
                .offset(y: -4)
                .animation(.easeInOut(duration: 0.2), value: isDraggingMap)
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Top Floating Bar (Back + Search)

    private var topFloatingBar: some View {
        HStack(spacing: 10) {
            // Circular Back Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "1F2937"))
                    .frame(width: 48, height: 48)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "13683B"))

                TextField("Search for area, street or landmark", text: $searchQuery)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .onChange(of: searchQuery) { _, query in
                        handleSearchQueryChange(query)
                    }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.75)
                } else if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                        showSearchResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "9CA3AF"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Floating "Use my current location" Pill

    private var useCurrentLocationPill: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            moveToCurrentLocation()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)

                Text("Use my current location")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Address Card

    private var bottomAddressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Small Section Title
            Text("DELIVERING YOUR ORDER TO")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "6B7280"))
                .tracking(0.5)

            // Location details row
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayAreaTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "1F2937"))

                    if isResolving {
                        Text("Fetching address...")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(hex: "6B7280"))
                    } else {
                        Text(displaySubtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(hex: "4B5563"))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }

            // Confirm Location Button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                    Text("Confirm location")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.brandGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: AppTheme.brandGreen.opacity(0.25), radius: 8, y: 3)
            }
            .disabled(isResolving)
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .background(Color.white)
        .clipShape(RoundedCornerShape(radius: 24, corners: [.topLeft, .topRight]))
        .shadow(color: Color.black.opacity(0.14), radius: 16, y: -4)
    }

    private var displayAreaTitle: String {
        if isDraggingMap { return "Locating..." }
        if let info = resolvedInfo, !info.area.isEmpty {
            return info.area
        }
        if let info = resolvedInfo, !info.city.isEmpty {
            return info.city
        }
        return "Selected location"
    }

    private var displaySubtitle: String {
        if let info = resolvedInfo, !info.formattedAddress.isEmpty {
            return info.formattedAddress
        }
        return "Move pin to your exact delivery location"
    }

    // MARK: - Search Results Dropdown

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchResults) { result in
                Button {
                    selectSearchResult(result)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(AppTheme.brandGreen)
                            .font(.system(size: 17))

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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if result.id != searchResults.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
        .frame(maxHeight: 240)
    }

    // MARK: - Location & Geocoding Logic

    private func setupInitialLocation() {
        if let coord = initialCoordinate {
            centerCoordinate = coord
            resolveAddress(for: coord)
        } else if let current = locationManager.currentLocation {
            centerCoordinate = current.coordinate
            resolveAddress(for: current.coordinate)
        } else {
            locationManager.fetchCurrentLocationAndResolve { info in
                if let info {
                    self.centerCoordinate = info.coordinate
                    self.resolvedInfo = info
                } else {
                    self.resolveAddress(for: self.centerCoordinate)
                }
            }
        }
    }

    private func moveToCurrentLocation() {
        if let loc = locationManager.currentLocation {
            centerCoordinate = loc.coordinate
            resolveAddress(for: loc.coordinate)
        } else {
            locationManager.requestCurrentLocation()
            locationManager.fetchCurrentLocationAndResolve { info in
                if let info {
                    self.centerCoordinate = info.coordinate
                    self.resolvedInfo = info
                }
            }
        }
    }

    private func resolveAddress(for coordinate: CLLocationCoordinate2D) {
        geocodeTask?.cancel()
        isResolving = true

        geocodeTask = Task {
            let info = await locationManager.reverseGeocode(coordinate: coordinate)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.resolvedInfo = info
                self.isResolving = false
            }
        }
    }

    private func handleSearchQueryChange(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            showSearchResults = false
            return
        }

        isSearching = true
        showSearchResults = true

        let filter = GMSAutocompleteFilter()
        filter.country = "IN"

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

// MARK: - Rounded Corner Shape Helper

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
