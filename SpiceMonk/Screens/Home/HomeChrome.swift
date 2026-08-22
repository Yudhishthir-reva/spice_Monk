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
    /// 1 at rest, 0 once the address has scrolled through the status-bar height.
    let addressOpacity: CGFloat
    let safeAreaTop: CGFloat
    var searchActive: Bool = false
    var searchQuery: Binding<String>? = nil
    var searchPlaceholders: [String] = []
    let onAddressTap: () -> Void
    let onProfileTap: () -> Void
    var onSearchTap: (() -> Void)?
    var onSearchBack: (() -> Void)?
    var onSearchClear: (() -> Void)?
    var onSearchSubmit: (() -> Void)?
    var onSearchMic: (() -> Void)?

    var body: some View {
        VStack(spacing: searchActive ? 0 : 16) {
            addressRow
                .opacity(addressOpacity)
                .frame(height: 52 * addressOpacity, alignment: .bottom)
                .clipped()
                .allowsHitTesting(addressOpacity > 0.4)

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
        .padding(.bottom, 8)
        .padding(.top, safeAreaTop + 8)
        .background {
            LinearGradient(
                colors: [AppTheme.homeHeaderTop, AppTheme.homeHeaderBottom],
                startPoint: .top,
                endPoint: .bottom
            )
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
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))

                        // Pincode/city chip
                        if let city = address?.cityName {
                            Text(city.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.2))
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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onProfileTap) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "bell.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)

                    Circle()
                        .fill(Color(hex: "FFC53D"))
                        .frame(width: 9, height: 9)
                        .offset(x: -2, y: 2)
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
        .frame(height: 52)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
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
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.accentRed)
                .frame(width: 40, height: 40)
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
                .font(.system(size: 14))
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
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(AppTheme.fieldDivider)
                    .frame(width: 1, height: 22)

                Button {
                    onMic?()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accentRed)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Floating WhatsApp Button

struct FloatingWhatsAppButton: View {
    var body: some View {
        Button {
            if let url = URL(string: "https://wa.me/") {
                UIApplication.shared.open(url)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: "25D366"))
                    .frame(width: 48, height: 48)
                    .shadow(color: Color(hex: "25D366").opacity(0.4), radius: 6, y: 3)

                Image(systemName: "message.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
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
                                    .foregroundStyle(.white.opacity(0.85))
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
                .background(AppTheme.brandRed)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: AppTheme.brandRed.opacity(0.35), radius: 8, y: 3)
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
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 26,
                topTrailingRadius: 26,
                style: .continuous
            )
            .fill(Color.white)
            .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
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
            block(height: 172)
                .padding(.horizontal, 16)

            HStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { _ in
                    block(width: 66, height: 66)
                }
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 12) {
                block(width: 160, height: 18)
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        block(width: 140, height: 210)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }

    private func block(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppTheme.imageTile)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .opacity(shimmer ? 0.45 : 1)
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
