//
//  HomeChrome.swift
//  SpiceMonk
//

import SwiftUI
import UIKit
import Combine

// MARK: - Top bar

/// Plum chrome that lives *inside* the home `ScrollView`. Address fades as the first safe-area's
/// worth of content scrolls away; the search row is then held on screen by `visualEffect`, the same
/// trick E-RSPL uses so the bar never leaves with the feed.
struct HomeTopBar: View {

    let address: Address?
    /// 1 at rest, 0 once the address has scrolled through the threshold.
    let addressOpacity: CGFloat
    let safeAreaTop: CGFloat
    var searchActive: Bool = false
    var searchQuery: Binding<String>? = nil
    var searchPlaceholders: [String] = []
    let onAddressTap: () -> Void
    var onProfileTap: (() -> Void)? = nil
    var onNotificationTap: (() -> Void)? = nil
    var onSearchTap: (() -> Void)?
    var onSearchBack: (() -> Void)?
    var onSearchClear: (() -> Void)?
    var onSearchSubmit: (() -> Void)?
    var onSearchMic: (() -> Void)?

    var body: some View {
        VStack(spacing: searchActive ? 0 : 10) {
            addressRow
                .opacity(searchActive ? 0 : addressOpacity)

            SpiceSearchBar(
                query: searchQuery,
                isActive: searchActive,
                placeholders: searchPlaceholders,
                onTap: onSearchTap,
                onBack: onSearchBack,
                onClear: onSearchClear,
                onSubmit: onSearchSubmit,
                onMic: onSearchMic
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .padding(.top, safeAreaTop + 8)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        AppTheme.homeHeaderTop,
                        Color(hex: "13683B"),
                        AppTheme.homeHeaderBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Emerald mint glow (top-leading)
                RadialGradient(
                    colors: [AppTheme.homeHeaderGlowCool.opacity(0.22), Color.clear],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 180
                )

                // Saffron glow (top-trailing)
                RadialGradient(
                    colors: [AppTheme.homeHeaderGlowWarm.opacity(0.18), Color.clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 160
                )
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var addressRow: some View {
        HStack(spacing: 8) {
            Button(action: onAddressTap) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                        Text("Delivering to")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))

                        // Pincode/city chip
                        if let city = address?.cityName, !city.isEmptyString {
                            Text(city.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.22))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }

                    HStack(spacing: 4) {
                        Text(address?.shortLine.isEmptyString == false
                             ? address!.shortLine
                             : "Set your delivery address")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                if let onNotificationTap {
                    onNotificationTap()
                } else if let onProfileTap {
                    onProfileTap()
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 40, height: 40)

                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)

                    Circle()
                        .fill(Color(hex: "FFC53D"))
                        .frame(width: 8.5, height: 8.5)
                        .offset(x: -2.5, y: 2.5)
                }
            }
        }
    }
}

/// Shared search field: read-only on home (tap to enter), editable with a back chevron in search mode.
struct SpiceSearchBar: View {

    var query: Binding<String>?
    var isActive: Bool = false
    var placeholders: [String] = []
    var onTap: (() -> Void)?
    var onBack: (() -> Void)?
    var onClear: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onMic: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var placeholderIndex: Int = 0

    private let fallback = "Search spices, masala, oils…"

    private var currentPlaceholder: String {
        if placeholders.isEmpty { return fallback }
        return placeholders[placeholderIndex % placeholders.count]
    }

    private var hasQuery: Bool {
        !(query?.wrappedValue.isEmpty ?? true)
    }

    var body: some View {
        HStack(spacing: 8) {
            leading
            field
            trailing
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .frame(height: 48)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        .onChange(of: isActive) { _, active in
            isFocused = active
        }
        .onAppear {
            if isActive { isFocused = true }
        }
        .onReceive(
            Timer.publish(every: 3, on: .main, in: .common).autoconnect()
        ) { _ in
            guard !isActive, placeholders.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                placeholderIndex += 1
            }
        }
    }

    @ViewBuilder
    private var leading: some View {
        if isActive {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.brandGreen)
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
        }
    }

    @ViewBuilder
    private var field: some View {
        if isActive, let query {
            TextField(currentPlaceholder, text: query)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { onSubmit?() }
        } else {
            Text(currentPlaceholder)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
                .id(placeholderIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isActive && hasQuery {
            Button {
                onClear?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(AppTheme.fieldDivider)
                    .frame(width: 1, height: 20)

                Button {
                    onMic?()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.brandGreen)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Dedicated, compact top bar for search mode with back button outside the input field.
struct SearchTopBar: View {
    @Binding var query: String
    var placeholder: String = "Search spices, masala, oils…"
    let safeAreaTop: CGFloat
    let onBack: () -> Void
    let onClear: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Back button outside search field
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Search input field capsule
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .frame(width: 20, height: 20)

                TextField(placeholder, text: $query)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .focused($isFieldFocused)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { onSubmit() }

                if !query.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.textMuted)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .padding(.top, safeAreaTop + 6)
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
        .onAppear {
            isFieldFocused = true
        }
    }
}

// MARK: - Floating WhatsApp Button

struct FloatingWhatsAppButton: View {
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if let url = AppStatusManager.shared.whatsappURL {
                UIApplication.shared.open(url)
            }
        } label: {
            Image("whatsapp")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(hex: "25D366").opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating Cart Bar

struct FloatingCartBar: View {

    @ObservedObject private var cart = CartStore.shared
    let onTap: () -> Void

    var body: some View {
        let itemsCount = cart.summary.totalItems
        let totalPay = cart.summary.totalCustomerPrice
        let savings = cart.summary.totalSavings

        if itemsCount > 0 {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 36, height: 36)

                            Image(systemName: "bag.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(itemsCount) ITEM\(itemsCount == 1 ? "" : "S") • ₹\(Int(totalPay.rounded()))")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(.white)

                            if savings > 0 {
                                Text("Saved ₹\(Int(savings.rounded())) on MRP")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("View Cart")
                            .font(.system(size: 13, weight: .heavy))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.ctaGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: AppTheme.brandGreen.opacity(0.35), radius: 10, y: 4)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Bottom navigation

enum HomeTab: Int, CaseIterable, Identifiable {
    case home
    case categories
    case account

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .categories: return "Categories"
        case .account: return "Account"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .categories: return "square.grid.2x2.fill"
        case .account: return "person.fill"
        }
    }
}

struct HomeBottomBar: View {

    var selected: HomeTab = .home
    var onSelect: (HomeTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases) { tab in
                let isSelected = tab == selected

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Capsule()
                                .fill(AppTheme.brandGreen)
                                .opacity(isSelected ? 1 : 0)
                                .scaleEffect(isSelected ? 1 : 0.6)

                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? .white : AppTheme.textMuted)
                        }
                        .frame(width: 46, height: 28)

                        Text(tab.title)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? AppTheme.brandGreen : AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                topTrailingRadius: 24,
                style: .continuous
            )
            .fill(Color.white)
            .shadow(color: .black.opacity(0.06), radius: 10, y: -3)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Loading and error states

/// Shimmering stand-ins shaped like the real feed, so the first paint does not jump when content
/// lands.
struct HomeSkeleton: View {

    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            block(height: 180)
                .padding(.horizontal, 16)

            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    block(width: 70, height: 70)
                }
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 12) {
                block(width: 160, height: 18)
                    .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        block(height: 210)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }

    private func block(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(shimmer ? 0.05 : 0.09))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
    }
}

struct HomeErrorState: View {

    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.accentRed)
                .frame(width: 72, height: 72)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            Text("Something went wrong")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: retry) {
                Text("Try again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 48)
                    .background(AppTheme.ctaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}
