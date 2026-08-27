//
//  SavedAddressesScreen.swift
//  SpiceMonk
//

import SwiftUI

struct SavedAddressesScreen: View {

    @ObservedObject var viewModel: AddressViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingAddress = false
    @State private var showLocationPicker = false
    @State private var pickedLocation: ResolvedLocationInfo? = nil
    @State private var editingAddress: Address?
    @State private var addressToDelete: Address?

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            // Body List
            ZStack(alignment: .bottom) {
                if viewModel.addresses.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(viewModel.addresses) { address in
                                addressCard(address)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 96) // Space for bottom floating button
                    }
                }

                // Bottom Add Address Button
                VStack(spacing: 0) {
                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Add a new address")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "145E2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(
                    LinearGradient(
                        colors: [Color(hex: "F8FAF8").opacity(0), Color(hex: "F8FAF8")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .background(Color(hex: "F8FAF8").ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            viewModel.load()
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerScreen { info in
                pickedLocation = info
                showLocationPicker = false
                isAddingAddress = true
            }
        }
        .sheet(isPresented: $isAddingAddress) {
            AddressFormScreen(initialInfo: pickedLocation) { _ in
                viewModel.load()
            }
        }
        .sheet(item: $editingAddress) { address in
            AddressFormScreen(editing: address) { _ in
                viewModel.load()
            }
        }
        .confirmationDialog(
            "Delete address?",
            isPresented: Binding(
                get: { addressToDelete != nil },
                set: { if !$0 { addressToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = addressToDelete {
                Button("Delete", role: .destructive) {
                    viewModel.deleteAddress(target)
                    addressToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                addressToDelete = nil
            }
        } message: {
            Text("Are you sure you want to remove this address?")
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Your addresses")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("Manage your delivery locations")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [AppTheme.homeHeaderTop, AppTheme.homeHeaderBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Address Card

    private func addressCard(_ address: Address) -> some View {
        HStack(spacing: 0) {
            // Left green indicator stripe if default
            if address.isDefault {
                Rectangle()
                    .fill(Color(hex: "1F6335"))
                    .frame(width: 4)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Header row: icon + name + DEFAULT badge
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: "EBF6EE"))
                            .frame(width: 36, height: 36)

                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: "1F6335"))
                    }

                    Text(address.fullName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if address.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "1F6335"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "E8F5EE"))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    Spacer()
                }

                // Address body
                Text(address.fullLine)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "4A5B52"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Phone number
                Text(address.mobile)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "8A9B92"))

                // Action buttons row
                HStack(spacing: 18) {
                    if !address.isDefault {
                        Button {
                            viewModel.makeDefault(address)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Set default")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: "2D4F38"))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Edit
                    Button {
                        editingAddress = address
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Edit")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "2D4F38"))
                    }
                    .buttonStyle(.plain)

                    // Delete
                    Button {
                        addressToDelete = address
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Delete")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "2D4F38"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(address.isDefault ? Color(hex: "1F6335").opacity(0.35) : Color.black.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "E8F5EE"))
                    .frame(width: 72, height: 72)

                Image(systemName: "mappin.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: "1F6335"))
            }

            Text("No saved addresses")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Add your delivery locations to order spices quickly.")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "6A7B72"))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
