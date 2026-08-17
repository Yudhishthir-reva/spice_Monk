//
//  HomeChrome.swift
//  SpiceMonk
//

import SwiftUI

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
                        Text("Delivering to")
                            .font(.system(size: 12))

                        // The API carries no "home"/"work" label, so the chip shows the city —
                        // real data rather than an invented tag.
                        if let city = address?.cityName {
                            Text(city.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 4) {
                        Text(address?.shortLine.isEmptyString == false
                             ? address!.shortLine
                             : "Set your delivery address")
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onProfileTap) {
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.accentRed)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            }
        }
    }
}

/// Shared search field: read-only on home (tap to enter), editable with a back chevron in search mode.
struct SpiceSearchBar: View {

    var query: Binding<String>?
    var isActive: Bool = false
    var onTap: (() -> Void)?
    var onBack: (() -> Void)?
    var onClear: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onMic: (() -> Void)?

    @FocusState private var isFocused: Bool

    private let placeholder = "Search spices, masala, oils…"

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
            TextField(placeholder, text: query)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { onSubmit?() }
        } else {
            Text(placeholder)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
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

// MARK: - Bottom navigation

enum HomeTab: Int, CaseIterable, Identifiable {
    case home
    case categories
    case cart
    case account

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .categories: return "Categories"
        case .cart: return "Cart"
        case .account: return "Account"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .categories: return "square.grid.2x2.fill"
        case .cart: return "cart.fill"
        case .account: return "person.fill"
        }
    }
}

struct HomeBottomBar: View {

    @Binding var selection: HomeTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases) { tab in
                let isSelected = tab == selection

                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17))
                            .scaleEffect(isSelected ? 1.1 : 1)
                            .frame(width: 52, height: 30)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppTheme.accentSoft)
                                }
                            }

                        Text(tab.title)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundStyle(isSelected ? AppTheme.accentRed : AppTheme.textPrimary.opacity(0.55))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .background(Color.white)
        .clipShape(.rect(topLeadingRadius: 26, topTrailingRadius: 26))
        .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
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
