//
//  HomeTabScreens.swift
//  SpiceMonk
//

import SwiftUI

enum HomeTabDestination: String, Hashable, Identifiable {
    case categories
    case cart
    case account

    var id: String { rawValue }
}

/// Bottom-nav Categories tab: the flat grid Android derives from the home widgets.
struct CategoriesTabScreen: View {

    let categories: [CategoryItem]

    var body: some View {
        Group {
            if categories.isEmpty {
                VStack(spacing: 8) {
                    Text("No categories")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Categories will appear here once available.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    CategorySectionPanel {
                        ChipGrid(items: categories, destination: .categoryProducts)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationTitle("All Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(AppTheme.accentRed)
    }
}

struct AccountPlaceholderScreen: View {

    @ObservedObject var addressViewModel: AddressViewModel
    @State private var isPickingAddress = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    isPickingAddress = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.accentRed)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saved addresses")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Manage your delivery locations")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                VStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.accentRed)
                    Text("More coming soon")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Your profile and orders will live here soon.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            }
            .padding(16)
        }
        .background(Color.white)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(AppTheme.accentRed)
        .sheet(isPresented: $isPickingAddress) {
            AddressPickerSheet(viewModel: addressViewModel)
        }
        .toast(isPresenting: $addressViewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: addressViewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }
}
