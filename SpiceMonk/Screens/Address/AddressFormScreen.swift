//
//  AddressFormScreen.swift
//  SpiceMonk
//
//

import SwiftUI
import CoreLocation
import GoogleMaps

/// "Add a new address" screen matching the screenshot:
/// Full name, mobile, alternate mobile, PIN code with deliverability banner,
/// interactive Google Map preview card with "Change" CTA, suggested area chips,
/// house/flat, area/locality, landmark, default switch, and sticky "Save address" button.
struct AddressFormScreen: View {

    @StateObject private var viewModel = AddressFormViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showMapPicker: Bool = false
    @State private var mapCenterCoord: CLLocationCoordinate2D = LocationManager.defaultCoordinate

    var editingAddress: Address? = nil
    var initialLocationInfo: ResolvedLocationInfo? = nil
    var isFromGPS: Bool = false
    let onSaved: (Address?) -> Void

    init(
        editing: Address? = nil,
        initialInfo: ResolvedLocationInfo? = nil,
        isFromGPS: Bool = false,
        onSaved: @escaping (Address?) -> Void
    ) {
        self.editingAddress = editing
        self.initialLocationInfo = initialInfo
        self.isFromGPS = isFromGPS
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            // Scrollable Form Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Full Name
                    formField(
                        label: "Full name",
                        placeholder: "e.g. John Doe",
                        text: $viewModel.fullName
                    )

                    // Mobile Number
                    formField(
                        label: "Mobile number",
                        placeholder: "10-digit mobile number",
                        text: $viewModel.mobile,
                        keyboard: .numberPad
                    )
                    .onChange(of: viewModel.mobile) { _, newValue in
                        viewModel.mobile = String(newValue.filter(\.isNumber).prefix(10))
                    }

                    // Alternate Mobile
                    formField(
                        label: "Alternate mobile (optional)",
                        placeholder: "Another contact number",
                        text: $viewModel.alternateMobile,
                        keyboard: .numberPad
                    )
                    .onChange(of: viewModel.alternateMobile) { _, newValue in
                        viewModel.alternateMobile = String(newValue.filter(\.isNumber).prefix(10))
                    }

                    // PIN Code
                    pinCodeSection

                    // Deliverability Banner
                    if canShowDeliverabilityBanner {
                        deliverabilityBanner
                    }

                    // Delivery Location Map Preview Card
                    deliveryLocationMapCard

                    // Suggested Area Chips
                    if !suggestedAreaList.isEmpty {
                        suggestedAreasSection
                    }

                    // House / Flat / Building
                    formField(
                        label: "House / Flat / Building",
                        placeholder: "e.g. Flat 101, Sunrise Apartments",
                        text: $viewModel.houseFlatNo
                    )

                    // Area / Locality
                    formField(
                        label: "Area / Locality",
                        placeholder: "Area or locality",
                        text: $viewModel.area
                    )

                    // Landmark
                    formField(
                        label: "Landmark (optional)",
                        placeholder: "e.g. Near Metro Station",
                        text: $viewModel.landmark
                    )

                    // Set as Default Address Switch
                    defaultAddressSwitchTile

                    // Bottom Save Address Button
                    saveButton
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            setupInitialData()
        }
        .sheet(isPresented: $showMapPicker) {
            LocationPickerScreen { location in
                viewModel.applyPickedLocation(location)
                mapCenterCoord = location.coordinate
            }
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 2.2, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    // MARK: - Initial Setup

    private func setupInitialData() {
        if let initialInfo = initialLocationInfo {
            viewModel.applyPickedLocation(initialInfo)
            mapCenterCoord = initialInfo.coordinate
        } else if let editing = editingAddress {
            viewModel.fullName = editing.fullName
            viewModel.mobile = editing.mobile
            viewModel.alternateMobile = editing.alternateMobile ?? ""
            viewModel.pinCode = editing.pinCode
            viewModel.houseFlatNo = editing.houseFlatNo
            viewModel.area = editing.area
            viewModel.landmark = editing.landmark ?? ""
            viewModel.state = editing.stateName ?? ""
            viewModel.district = editing.cityName ?? ""
            viewModel.isDefault = editing.isDefault
            viewModel.pinCodeChanged()
        } else if isFromGPS {
            if let lastInfo = LocationManager.shared.lastResolvedInfo {
                viewModel.applyPickedLocation(lastInfo)
                mapCenterCoord = lastInfo.coordinate
            } else {
                LocationManager.shared.fetchCurrentLocationAndResolve { info in
                    if let info {
                        viewModel.applyPickedLocation(info)
                        mapCenterCoord = info.coordinate
                    }
                }
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(editingAddress == nil ? "Add a new address" : "Edit address")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            LinearGradient(
                colors: [
                    AppTheme.homeHeaderTop,
                    Color(hex: "13683B"),
                    AppTheme.homeHeaderBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Form Field Component

    private func formField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "374151"))

            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                }
        }
    }

    // MARK: - PIN Code Section

    private var pinCodeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PIN code")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "374151"))

            HStack(spacing: 8) {
                TextField("6-digit PIN code", text: $viewModel.pinCode)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.pinCode) { _, _ in
                        viewModel.pinCodeChanged()
                    }

                if viewModel.isLookingUpPincode {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if viewModel.isDeliverable || viewModel.didResolvePincode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                } else if viewModel.pincodeError != nil && viewModel.pinCode.count == 6 {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: "DC2626"))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        (viewModel.isDeliverable || viewModel.didResolvePincode) ? AppTheme.brandGreen :
                        (viewModel.pincodeError != nil && viewModel.pinCode.count == 6 ? Color(hex: "DC2626") : Color(hex: "E5E7EB")),
                        lineWidth: (viewModel.isDeliverable || viewModel.didResolvePincode || (viewModel.pincodeError != nil && viewModel.pinCode.count == 6)) ? 1.5 : 1
                    )
            }
        }
    }

    // MARK: - Deliverability Banner

    private var canShowDeliverabilityBanner: Bool {
        (viewModel.isDeliverable && !viewModel.district.isEmpty && !viewModel.state.isEmpty) ||
        (viewModel.pincodeError != nil && viewModel.pinCode.count == 6)
    }

    private var deliverabilityBanner: some View {
        Group {
            if viewModel.isDeliverable && !viewModel.district.isEmpty && !viewModel.state.isEmpty {
                HStack(spacing: 6) {
                    Text("Deliverable to \(viewModel.district), \(viewModel.state)")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color(hex: "1F6335"))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if let errorMsg = viewModel.pincodeError, !viewModel.isDeliverable {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "DC2626"))

                    Text(errorMsg)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "DC2626"))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "FEE2E2"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - Delivery Location Map Card

    private var deliveryLocationMapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Delivery location")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Color(hex: "374151"))

                Spacer()

                Button {
                    showMapPicker = true
                } label: {
                    Text("Change")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                }
                .buttonStyle(.plain)
            }

            // Map Preview & Formatted Address Container
            VStack(spacing: 0) {
                // Mini Map View
                ZStack {
                    GoogleMapView(
                        centerCoordinate: $mapCenterCoord,
                        zoomLevel: 16.0,
                        isMyLocationEnabled: false,
                        showsMyLocationButton: false,
                        showsCompass: false,
                        isUserInteractionEnabled: false
                    )
                    .frame(height: 130)
                    .allowsHitTesting(false)

                    // Pin Marker
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                }
                .frame(height: 130)
                .clipped()

                // Address info bottom row
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.brandGreen)
                        .padding(.top, 2)

                    Text(formattedDeliveryAddressText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "4B5563"))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            }
        }
    }

    private var formattedDeliveryAddressText: String {
        if let info = viewModel.resolvedLocationInfo, !info.formattedAddress.isEmpty {
            return info.formattedAddress
        }
        let parts = [viewModel.houseFlatNo, viewModel.area, viewModel.district, viewModel.state, viewModel.pinCode]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if parts.isEmpty {
            return "Tap Change to select your location precisely on the map"
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Suggested Area Chips

    private var suggestedAreaList: [String] {
        if viewModel.isDeliverable {
            return viewModel.suggestedAreas
        }
        return []
    }

    private var suggestedAreasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested areas for this PIN")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "6B7280"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedAreaList, id: \.self) { areaName in
                        let isSelected = viewModel.area.lowercased() == areaName.lowercased()
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.area = areaName
                        } label: {
                            Text(areaName)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? AppTheme.brandGreen : Color(hex: "374151"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isSelected ? AppTheme.accentSoft : Color(hex: "F3F4F6"))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isSelected ? AppTheme.brandGreen : Color.clear, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Default Address Switch Tile

    private var defaultAddressSwitchTile: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Set as default address")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Orders will be delivered here by default")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "6B7280"))
            }

            Spacer()

            Toggle("", isOn: $viewModel.isDefault)
                .labelsHidden()
                .tint(AppTheme.brandGreen)
        }
        .padding(14)
        .background(Color(hex: "F9FAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.save { address in
                onSaved(address)
                dismiss()
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text("Save address")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.brandGreen)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppTheme.brandGreen.opacity(0.25), radius: 8, y: 3)
        }
        .disabled(viewModel.isSaving)
        .buttonStyle(.plain)
    }
}
