//
//  AppTheme.swift
//  SpiceMonk
//

import SwiftUI

enum AppTheme {
    static let brandBackgroundTop = Color(hex: "F1F8F1")
    static let brandBackgroundMid = Color(hex: "EAF5E9")
    static let brandBackgroundBottom = Color(hex: "DFEFDE")

    static let brandGreen = Color(hex: "167444")
    static let brandGreenLight = Color(hex: "1E8A52")
    static let brandGreenDark = Color(hex: "0E4A28")

    static let brandRed = brandGreen
    static let brandRedDark = brandGreenDark
    static let ctaGradient = LinearGradient(
        colors: [Color(hex: "1E8A52"), Color(hex: "167444"), Color(hex: "0E4A28")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let textPrimary = Color(hex: "1A1712")
    static let textSecondary = Color(hex: "526158")
    static let textMuted = Color(hex: "8FA196")

    static let fieldBackground = Color.white
    static let fieldBorder = Color(hex: "D6ECE0")
    static let fieldDivider = Color(hex: "E2F2E9")

    static let otpBoxBackground = Color.white
    static let otpBoxBorder = Color(hex: "D6ECE0")
    static let otpBoxBorderActive = Color(hex: "167444")
    static let otpPlaceholderDot = Color(hex: "94D2BD")

    static let accentRed = Color(hex: "167444")
    static let accentGreen = Color(hex: "167444")
    static let accentOrange = Color(hex: "F97316")
    static let accentYellow = Color(hex: "F59E0B")

    static let badgeSuccess = Color(hex: "167444")
    static let badgePrivate = Color(hex: "0D9488")

    // MARK: - Home

    static let homeCanvas = Color.white
    static let homeHeaderTop = Color(hex: "1D8750")
    static let homeHeaderBottom = Color(hex: "0E4A28")
    static let homeHeaderSurface = Color(hex: "167444")

    static let accentSoft = Color(hex: "E8F5EE")
    static let discountBadge = Color(hex: "167444")
    static let newBadgeBackground = Color(hex: "E0F2FE")
    static let newBadgeText = Color(hex: "0369A1")

    static let cardBorder = Color.black.opacity(0.08)
    static let imageTile = Color(hex: "F4F4F5")

    /// Backdrop for the `black_lazy_row` product rail, matching Android's featured carousel.
    static let blackCard = Color(hex: "1C1C1E")
    static let blackCardMuted = Color(hex: "9CA3AF")

    /// Soft green wash behind category sections.
    static let categoryPanel = Color(hex: "F0FDF4")
    static let categoryRail = Color(hex: "F7F7F8")
    static let heroTile = Color(hex: "F6F5F3")
    static let cardSoft = Color(hex: "F4F7F5")
    static let saveBadgeFill = Color(hex: "DCFCE7")
}

extension View {
    func spiceNavigationBar(title: String? = nil) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(title ?? "")
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.brandGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)
    }
}
