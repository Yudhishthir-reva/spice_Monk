//
//  AddressPickerSheet.swift
//  SpiceMonk
//
//

import SwiftUI

/// "Select delivery location" bottom sheet matching the app design:
/// Search box, "Use my current location", "Add a new address", and "YOUR SAVED ADDRESSES" with "Manage" CTA.
struct AddressPickerSheet: View {

    @ObservedObject var viewModel: AddressViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery: String = ""
    @State private var isAddingAddress = false
    @State private var showLocationPicker = false
    @State private var pickedLocation: ResolvedLocationInfo? = nil
    @State private var isAddingWithLocation = false
    @State private var isManaging = false

    private var filteredAddresses: [Address] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.addresses }
        return viewModel.addresses.filter { address in
            address.fullName.lowercased().contains(query) ||
            address.fullLine.lowercased().contains(query) ||
            address.pinCode.lowercased().contains(query) ||
            (address.cityName?.lowercased().contains(query) == true) ||
            (address.stateName?.lowercased().contains(query) == true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Grabber Handle
            Capsule()
                .fill(Color(hex: "E5E7EB"))
                .frame(width: 44, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 14)

            // Header: Title & Close Button
            HStack {
                Text("Select delivery location")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "F3F4F6"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Search Box
                    searchField

                    // Quick Actions
                    VStack(spacing: 0) {
                        // 1. Use My Current Location
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            isAddingWithLocation = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "scope")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppTheme.brandGreen)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use my current location")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(AppTheme.brandGreen)

                                    Text("Fills your address in from GPS")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Color(hex: "6A7B72"))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(hex: "9CA3AF"))
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 42)

                        // 2. Add a New Address
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showLocationPicker = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.brandGreen)
                                    .frame(width: 28)

                                Text("Add a new address")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.brandGreen)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(hex: "9CA3AF"))
                            }
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)

                    // Saved Addresses Section Header
                    HStack {
                        Text("YOUR SAVED ADDRESSES")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Color(hex: "7C8B82"))
                            .tracking(0.5)

                        Spacer()

                        Button {
                            isManaging = true
                        } label: {
                            Text("Manage")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(AppTheme.brandGreen)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 4)

                    // Saved Addresses List
                    if filteredAddresses.isEmpty {
                        emptySavedAddresses
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredAddresses) { address in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.makeDefault(address)
                                    dismiss()
                                } label: {
                                    addressCard(address)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerScreen { info in
                pickedLocation = info
                showLocationPicker = false
                isAddingWithLocation = true
            }
        }
        .sheet(isPresented: $isAddingWithLocation) {
            AddressFormScreen(initialInfo: pickedLocation, isFromGPS: true) { _ in
                viewModel.load()
            }
        }
        .sheet(isPresented: $isAddingAddress) {
            AddressFormScreen { _ in
                viewModel.load()
            }
        }
        .sheet(isPresented: $isManaging) {
            NavigationStack {
                SavedAddressesScreen(viewModel: viewModel)
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: "9CA3AF"))

            TextField("Search by PIN code or saved address", text: $searchQuery)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color(hex: "F3F4F6"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Address Card Row

    private func addressCard(_ address: Address) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Location Pin Squircle
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.accentSoft)
                    .frame(width: 44, height: 44)

                Image(systemName: "mappin.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.brandGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(address.fullName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if address.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundStyle(AppTheme.brandGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }

                Text(address.fullLine)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "4B5563"))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if address.isDefault {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(address.isDefault ? Color(hex: "FAFCFA") : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(address.isDefault ? AppTheme.brandGreen.opacity(0.35) : Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Empty State

    private var emptySavedAddresses: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 24))
                .foregroundStyle(Color(hex: "9CA3AF"))
                .padding(.top, 12)

            Text(searchQuery.isEmpty ? "No saved addresses yet" : "No matching address found")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "6A7B72"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
