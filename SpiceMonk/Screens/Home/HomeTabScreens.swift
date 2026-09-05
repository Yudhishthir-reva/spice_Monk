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
            // Aurora Title Header
            HStack {
                Text("Categories")
                    .font(.appFont(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .padding(.top, (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 50) + 8)
            .background {
                HomeHeaderAuroraCanvas()
                    .ignoresSafeArea(edges: .top)
            }

            // Search bar in body
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.appFont(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)

                TextField("Search categories", text: $searchText)
                    .font(.appFont(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.appFont(size: 16))
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
                        .font(.appFont(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Categories will appear here once available.")
                        .font(.appFont(size: 14))
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
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F7F8F7"))
        .ignoresSafeArea(edges: .top)
    }

    private func categoryCell(_ item: CategoryItem) -> some View {
        VStack(spacing: 8) {
            RemoteImage(url: item.imageUrl, contentMode: .fit)
                .padding(10)
                .frame(width: 80, height: 80)
                .background(AppTheme.imageTile)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(item.name)
                .font(.appFont(size: 12, weight: .semibold))
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

// MARK: - Account Tab Screen

struct AccountTabScreen: View {

    @ObservedObject var addressViewModel: AddressViewModel
    @ObservedObject private var cart = CartStore.shared
    @ObservedObject private var loginGate = LoginGate.shared
    var onLogout: () -> Void

    @State private var isPickingAddress = false
    @State private var isPickingPayment = false
    @State private var isConfirmingLogout = false
    @State private var isConfirmingDeleteAccount = false
    @State private var isShowDeleteSuccessAlert = false

    private var userMobile: String {
        let mobile = UserDefaultManager.shared.getUserDefaultsString(key: .userMobile)
        return mobile.isEmptyString ? "9999999999" : mobile
    }

    private var userName: String {
        let name = UserDefaultManager.shared.getUserDefaultsString(key: .userName)
        return name.isEmptyString ? "Welcome" : name
    }

    private var userInitials: String {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.lowercased() == "welcome" {
            return "WE"
        }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your account")
                    .font(.appFont(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .padding(.top, (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 50) + 8)
            .background {
                HomeHeaderAuroraCanvas()
                    .ignoresSafeArea(edges: .top)
            }

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if loginGate.isLoggedIn {
                    // Profile Card
                    profileCard
                        .padding(.top, 16)

                    // Section 1: Your orders & addresses
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your orders & addresses")
                            .font(.appFont(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "6A7B72"))
                            .padding(.leading, 4)

                        VStack(spacing: 12) {
                            NavigationLink {
                                OrdersScreen()
                            } label: {
                                accountRow(
                                    icon: "doc.text.fill",
                                    title: "Order history",
                                    subtitle: "Track deliveries and reorder in a tap"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                SavedAddressesScreen(viewModel: addressViewModel)
                            } label: {
                                accountRow(
                                    icon: "mappin.circle.fill",
                                    title: "Saved addresses",
                                    subtitle: "Manage where your spices land"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Section 2: Payment
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Payment")
                            .font(.appFont(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "6A7B72"))
                            .padding(.leading, 4)

                        Button {
                            isPickingPayment = true
                        } label: {
                            accountRow(
                                icon: "creditcard.fill",
                                title: "Payment method",
                                subtitle: cart.paymentMethod.rawValue
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Section 3: Support
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Support")
                            .font(.appFont(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "6A7B72"))
                            .padding(.leading, 4)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if let url = AppStatusManager.shared.whatsappURL {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            accountRow(
                                icon: "whatsapp",
                                isAsset: true,
                                title: "Help & support",
                                subtitle: "Chat with us on WhatsApp"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Log Out Button
                    Button {
                        isConfirmingLogout = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.appFont(size: 16, weight: .bold))
                            Text("Log out")
                                .font(.appFont(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Color(hex: "D93838"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "FFF5F5"))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(hex: "FCD4D4"), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    // Delete Account Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isConfirmingDeleteAccount = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.appFont(size: 13, weight: .medium))
                            Text("Delete account")
                                .font(.appFont(size: 13.5, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "9CA3AF"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    // Footer Tagline
                    Text("Freshly ground, straight from the monks.")
                        .font(.appFont(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "8FA196"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                        .padding(.bottom, 36)
                    } else {
                        guestLoginCard
                            .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Support")
                                .font(.appFont(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "6A7B72"))
                                .padding(.leading, 4)

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if let url = AppStatusManager.shared.whatsappURL {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                accountRow(
                                    icon: "whatsapp",
                                    isAsset: true,
                                    title: "Help & support",
                                    subtitle: "Chat with us on WhatsApp"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 36)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F8FAF8"))
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $isPickingAddress) {
            AddressPickerSheet(viewModel: addressViewModel)
        }
        .sheet(isPresented: $isPickingPayment) {
            PaymentMethodPickerSheet()
        }
        .sheet(isPresented: $isConfirmingLogout) {
            LogoutConfirmationSheet(
                onLogout: onLogout,
                onDismiss: { isConfirmingLogout = false }
            )
            .presentationDetents([.fraction(0.38), .medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Account", isPresented: $isConfirmingDeleteAccount) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                isShowDeleteSuccessAlert = true
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .alert("Request Received", isPresented: $isShowDeleteSuccessAlert) {
            Button("OK") {
                onLogout()
            }
        } message: {
            Text("Our team will connect with you soon regarding your account deletion request.")
        }
        .toast(isPresenting: $addressViewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: addressViewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    // MARK: - Profile Card

    private var guestLoginCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log in to continue")
                .font(.appFont(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Sign in with your mobile number to save addresses, track orders, and checkout.")
                .font(.appFont(size: 14))
                .foregroundStyle(Color(hex: "5A6B62"))
            Button {
                LoginGate.shared.requireLogin()
            } label: {
                Text("Log in")
                    .font(.appFont(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AppTheme.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "E0F2E9"))
                    .frame(width: 58, height: 58)

                Text(userInitials)
                    .font(.appFont(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "1F6335"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.appFont(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(userMobile)
                    .font(.appFont(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "5A6B62"))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Account Row Component

    private func accountRow(icon: String, isAsset: Bool = false, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "EBF6EE"))
                    .frame(width: 44, height: 44)

                if isAsset {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: icon)
                        .font(.appFont(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "1F6335"))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.appFont(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(subtitle)
                    .font(.appFont(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "6A7B72"))
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.appFont(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "A3B3AA"))
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

// MARK: - Logout Confirmation Sheet

struct LogoutConfirmationSheet: View {

    let onLogout: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "E8F5EE"))
                    .frame(width: 64, height: 64)

                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.appFont(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: "1F6335"))
            }
            .padding(.top, 24)

            // Title
            Text("Log out?")
                .font(.appFont(size: 22, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 16)

            // Subtitle
            Text("You'll need your mobile number to get back in. Your cart stays safe with us.")
                .font(.appFont(size: 14))
                .foregroundStyle(Color(hex: "5A6B62"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)

            // Primary Log out button
            Button {
                onLogout()
            } label: {
                Text("Log out")
                    .font(.appFont(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "1F6335"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 24)

            // Stay signed in
            Button {
                onDismiss()
            } label: {
                Text("Stay signed in")
                    .font(.appFont(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "2D4F38"))
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
}
