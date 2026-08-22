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

/// Bottom-nav Categories tab: emerald green header with search + 3-column grid.
struct CategoriesTabScreen: View {

    let categories: [CategoryItem]
    @State private var searchText = ""

    private var filtered: [CategoryItem] {
        if searchText.isEmpty { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)

                TextField("Search categories", text: $searchText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Category grid
            if filtered.isEmpty {
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
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filtered) { category in
                            NavigationLink {
                                WidgetProductsScreen(
                                    searchQuery: "",
                                    title: category.name,
                                    categoryId: category.id
                                )
                            } label: {
                                categoryCell(category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F7F8F7"))
        .spiceNavigationBar(title: "Categories")
    }

    private func categoryCell(_ item: CategoryItem) -> some View {
        VStack(spacing: 8) {
            RemoteImage(url: item.imageUrl, contentMode: .fit)
                .padding(10)
                .frame(width: 80, height: 80)
                .background(AppTheme.imageTile)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(item.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
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
                            .foregroundStyle(AppTheme.brandGreen)
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

                NavigationLink {
                    OrdersScreen()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.brandGreen)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your orders")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Track, cancel, or buy again")
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
                        .foregroundStyle(AppTheme.brandGreen)
                    Text("More coming soon")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Your profile will live here soon.")
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
        .spiceNavigationBar(title: "Account")
        .sheet(isPresented: $isPickingAddress) {
            AddressPickerSheet(viewModel: addressViewModel)
        }
        .toast(isPresenting: $addressViewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: addressViewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }
}
