//
//  AddressPickerSheet.swift
//  SpiceMonk
//

import SwiftUI

/// Bottom sheet to pick a delivery address: search, quick actions, and saved addresses.
struct AddressPickerSheet: View {

    @ObservedObject var viewModel: AddressViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var showLocationPicker = false
    @State private var pickedLocation: ResolvedLocationInfo? = nil
    @State private var isAddingWithLocation = false
    @State private var isAddingFromGPS = false
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
        NavigationStack {
            ZStack {
                Color(hex: "F5F5F5").ignoresSafeArea()

                if viewModel.isLoading && viewModel.addresses.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 14) {
                            searchField
                            quickActionsCard
                            savedAddressesSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Select delivery location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.appFont(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            viewModel.load()
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerScreen { info in
                pickedLocation = info
                showLocationPicker = false
                isAddingWithLocation = true
            }
        }
        .sheet(isPresented: $isAddingWithLocation) {
            AddressFormScreen(initialInfo: pickedLocation) { _ in
                pickedLocation = nil
                viewModel.load()
            }
        }
        .sheet(isPresented: $isAddingFromGPS) {
            AddressFormScreen(isFromGPS: true) { _ in
                viewModel.load()
            }
        }
        .sheet(isPresented: $isManaging) {
            NavigationStack {
                SavedAddressesScreen(viewModel: viewModel)
            }
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.appFont(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)

            TextField("Search by area, PIN code or name", text: $searchQuery)
                .font(.appFont(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appFont(size: 15))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsCard: some View {
        VStack(spacing: 0) {
            quickActionRow(
                icon: "location.fill",
                title: "Use my current location",
                subtitle: "Detect address from GPS",
                action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isAddingFromGPS = true
                }
            )

            Divider().padding(.leading, 54)

            quickActionRow(
                icon: "plus",
                title: "Add a new address",
                subtitle: "Search on map and save",
                action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showLocationPicker = true
                }
            )
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private func quickActionRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.appFont(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appFont(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.appFont(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.appFont(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Saved Addresses

    private var savedAddressesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR SAVED ADDRESSES")
                    .font(.appFont(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textMuted)
                    .tracking(0.4)

                Spacer()

                if !viewModel.addresses.isEmpty {
                    Button("Manage") {
                        isManaging = true
                    }
                    .font(.appFont(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)

            if filteredAddresses.isEmpty {
                emptySavedAddresses
            } else {
                VStack(spacing: 10) {
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
    }

    private func addressCard(_ address: Address) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: address.isDefault ? "house.fill" : "mappin.and.ellipse")
                .font(.appFont(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.brandGreen)
                .frame(width: 38, height: 38)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(address.fullName.isEmptyString ? "Home" : address.fullName)
                        .font(.appFont(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    if address.isDefault {
                        Text("DEFAULT")
                            .font(.appFont(size: 9, weight: .heavy))
                            .foregroundStyle(AppTheme.brandGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }

                Text(address.fullLine)
                    .font(.appFont(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !address.mobile.isEmptyString {
                    Text(address.mobile)
                        .font(.appFont(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }

            if address.isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .font(.appFont(size: 18))
                    .foregroundStyle(AppTheme.brandGreen)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    address.isDefault ? AppTheme.brandGreen.opacity(0.35) : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        }
    }

    private var emptySavedAddresses: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.slash")
                .font(.appFont(size: 28))
                .foregroundStyle(AppTheme.textMuted)

            Text(searchQuery.isEmpty ? "No saved addresses yet" : "No matching address found")
                .font(.appFont(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(searchQuery.isEmpty
                 ? "Add a new address or use your current location to get started."
                 : "Try a different search term.")
                .font(.appFont(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}
