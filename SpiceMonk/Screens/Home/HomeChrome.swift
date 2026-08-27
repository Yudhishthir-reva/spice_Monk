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
                Color(hex: "F7FAF7")

                HomeHeaderAuroraCanvas()
                    .opacity(addressOpacity)
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
                            .font(.appFont(size: 11))
                            .foregroundStyle(.white)
                        Text("Delivering to")
                            .font(.appFont(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))

                        // Pincode/city chip
                        if let city = address?.cityName, !city.isEmptyString {
                            Text(city.uppercased())
                                .font(.appFont(size: 10, weight: .bold))
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
                            .font(.appFont(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.appFont(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            AnimatedHeaderBell {
                if let onNotificationTap {
                    onNotificationTap()
                } else if let onProfileTap {
                    onProfileTap()
                }
            }
        }
    }
}

private let TAU: CGFloat = 2.0 * .pi

/// Living "Spiced Aurora" Canvas Background matching Android Jetpack Compose reference.
/// 60/120 FPS GPU-accelerated drawing with drifting Lissajous glows, light sweep sheen, and rising spice specks.
 struct HomeHeaderAuroraCanvas: View {

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            let warmPhase = CGFloat(date.truncatingRemainder(dividingBy: 11.0) / 11.0)
            let coolPhase = CGFloat((date + 14.5 * 0.33).truncatingRemainder(dividingBy: 14.5) / 14.5)
            let deepPhase = CGFloat((date + 8.6 * 0.66).truncatingRemainder(dividingBy: 8.6) / 8.6)
            let sweepPhase = CGFloat(date.truncatingRemainder(dividingBy: 6.4) / 6.4)

            Canvas { context, size in
                let w = size.width
                let h = size.height
                guard w > 0, h > 0 else { return }

                // 1. Base 3-Hue Diagonal Gradient
                let gradient = Gradient(colors: [
                    AppTheme.homeHeaderTop,
                    Color(hex: "13683B"),
                    AppTheme.homeHeaderBottom
                ])
                let baseRect = CGRect(origin: .zero, size: size)
                context.fill(
                    Path(baseRect),
                    with: .linearGradient(
                        gradient,
                        startPoint: .zero,
                        endPoint: CGPoint(x: w, y: h * 1.4)
                    )
                )

                // 2. Drifting Radial Glows (Lissajous loops)
                func drawGlow(phase: CGFloat, color: Color, baseX: CGFloat, baseY: CGFloat, radiusFactor: CGFloat, strength: CGFloat) {
                    let a = phase * TAU
                    let centerX = w * baseX + sin(a) * w * 0.16
                    let centerY = h * baseY + cos(a * 1.3) * h * 0.30
                    let radius = radiusFactor * w

                    let glowGradient = Gradient(colors: [
                        color.opacity(Double(strength)),
                        color.opacity(0.0)
                    ])

                    let circleRect = CGRect(
                        x: centerX - radius,
                        y: centerY - radius,
                        width: radius * 2,
                        height: radius * 2
                    )

                    context.fill(
                        Path(ellipseIn: circleRect),
                        with: .radialGradient(
                            glowGradient,
                            center: CGPoint(x: centerX, y: centerY),
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }

                // Saffron warm glow
                drawGlow(phase: warmPhase, color: AppTheme.homeHeaderGlowWarm, baseX: 0.80, baseY: 0.18, radiusFactor: 0.62, strength: 0.34)
                // Emerald mint glow
                drawGlow(phase: coolPhase, color: AppTheme.homeHeaderGlowCool, baseX: 0.14, baseY: 0.86, radiusFactor: 0.55, strength: 0.30)
                // Deep center glow
                drawGlow(phase: deepPhase, color: AppTheme.homeHeaderGlowWarm, baseX: 0.48, baseY: 0.55, radiusFactor: 0.40, strength: 0.16)

                // 3. Diagonal light sweep (Sheen pass)
                let sweepX = (sweepPhase * 2.2 - 0.6) * w
                let sheenGradient = Gradient(colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.0)
                ])
                context.fill(
                    Path(baseRect),
                    with: .linearGradient(
                        sheenGradient,
                        startPoint: CGPoint(x: sweepX, y: 0),
                        endPoint: CGPoint(x: sweepX + w * 0.42, y: h)
                    )
                )

                // 4. 7 Rising spice specks / motes
                for i in 0..<7 {
                    let seed = CGFloat(i) * 0.137
                    let p = (deepPhase + seed).truncatingRemainder(dividingBy: 1.0)
                    let x = w * (CGFloat(i) * 0.1613 + 0.06).truncatingRemainder(dividingBy: 1.0) + sin((p + seed) * TAU) * w * 0.05
                    let y = h * (1.05 - p * 1.15)
                    let fade = sin(p * .pi)
                    let radius = 1.2 + CGFloat(i % 3) * 0.7

                    let speckRect = CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )

                    context.fill(
                        Path(ellipseIn: speckRect),
                        with: .color(Color.white.opacity(Double(0.22 * fade)))
                    )
                }
            }
        }
    }
}

/// Bell that rings on a periodic loop — quick damped wobble every 4.2s pivoted at top crown with a pulsing golden dot.
private struct AnimatedHeaderBell: View {

    let onTap: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            let ringPhase = CGFloat(date.truncatingRemainder(dividingBy: 4.2) / 4.2)
            let pulsePhase = CGFloat(date.truncatingRemainder(dividingBy: 1.6) / 1.6)

            // Damped wobble in first 20% of cycle
            let burst = ringPhase < 0.2 ? (ringPhase / 0.2) : 0.0
            let angle: Double = burst > 0 ? Double(sin(burst * TAU * 3.0) * 15.0 * (1.0 - burst)) : 0.0

            // Pulse scale for unread dot
            let scale: CGFloat = 1.0 + sin(pulsePhase * TAU) * 0.28

            Button(action: onTap) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 40, height: 40)

                    Image(systemName: "bell.fill")
                        .font(.appFont(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.5, y: 0.08))

                    Circle()
                        .fill(Color(hex: "FFC53D"))
                        .frame(width: 8.5, height: 8.5)
                        .scaleEffect(scale)
                        .offset(x: -2.5, y: 2.5)
                }
            }
            .buttonStyle(.plain)
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
                    .font(.appFont(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "magnifyingglass")
                .font(.appFont(size: 17, weight: .bold))
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
                .font(.appFont(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { onSubmit?() }
        } else {
            Text(currentPlaceholder)
                .font(.appFont(size: 14, weight: .medium))
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
                    .font(.appFont(size: 18))
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
                        .font(.appFont(size: 15))
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
    var onMic: (() -> Void)? = nil

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Back button outside search field
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.appFont(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Search input field capsule
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.appFont(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .frame(width: 20, height: 20)

                TextField(placeholder, text: $query)
                    .font(.appFont(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .focused($isFieldFocused)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { onSubmit() }

                if !query.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.appFont(size: 17))
                            .foregroundStyle(AppTheme.textMuted)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                } else if let onMic {
                    Button(action: onMic) {
                        Image(systemName: "mic.fill")
                            .font(.appFont(size: 15))
                            .foregroundStyle(AppTheme.brandGreen)
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
            HomeHeaderAuroraCanvas()
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
                                .font(.appFont(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(itemsCount) ITEM\(itemsCount == 1 ? "" : "S") • ₹\(Int(totalPay.rounded()))")
                                .font(.appFont(size: 13, weight: .heavy))
                                .foregroundStyle(.white)

                            if savings > 0 {
                                Text("Saved ₹\(Int(savings.rounded())) on MRP")
                                    .font(.appFont(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("View Cart")
                            .font(.appFont(size: 13, weight: .heavy))
                        Image(systemName: "arrow.right")
                            .font(.appFont(size: 13, weight: .bold))
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
                                .font(.appFont(size: 16, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? .white : AppTheme.textMuted)
                        }
                        .frame(width: 46, height: 28)

                        Text(tab.title)
                            .font(.appFont(size: 11, weight: isSelected ? .bold : .medium))
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
                .font(.appFont(size: 30))
                .foregroundStyle(AppTheme.accentRed)
                .frame(width: 72, height: 72)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            Text("Something went wrong")
                .font(.appFont(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(.appFont(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: retry) {
                Text("Try again")
                    .font(.appFont(size: 15, weight: .semibold))
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
