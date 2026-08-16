//
//  HomeChrome.swift
//  SpiceMonk
//

import SwiftUI

// MARK: - Top bar

/// Plum hero that collapses as the feed scrolls: the address block fades out and the bar settles
/// into a compact surface, leaving the search field always reachable.
struct HomeTopBar: View {

    /// 0 when the feed is at rest, 1 once it has scrolled past the collapse distance.
    let collapseProgress: Double
    /// Nil until the address list loads, or when the customer has not saved one yet.
    let address: Address?
    let onAddressTap: () -> Void
    let onProfileTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if collapseProgress < 1 {
                addressRow
                    .opacity(1 - collapseProgress)
                    .frame(height: 46 * (1 - collapseProgress))
                    .clipped()
            }

            searchBar
                .padding(.top, 12 * (1 - collapseProgress))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .background(background)
        .clipShape(
            .rect(
                bottomLeadingRadius: 26 * collapseProgress,
                bottomTrailingRadius: 26 * collapseProgress
            )
        )
        .shadow(color: .black.opacity(0.12 * collapseProgress), radius: 8, y: 2)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.homeHeaderTop, AppTheme.homeHeaderBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            AppTheme.homeHeaderSurface.opacity(collapseProgress)
        }
        .ignoresSafeArea(edges: .top)
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
                        if let city = address?.city?.name, !city.isEmpty {
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

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.accentRed)

            Text("Search spices, masala, oils…")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)

            Spacer()

            Rectangle()
                .fill(AppTheme.fieldDivider)
                .frame(width: 1, height: 22)

            Image(systemName: "mic.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.accentRed)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
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
