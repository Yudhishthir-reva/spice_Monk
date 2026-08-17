//
//  AppTheme.swift
//  SpiceMonk
//

import SwiftUI

enum AppTheme {
    static let brandBackgroundTop = Color(hex: "FFF6E9")
    static let brandBackgroundMid = Color(hex: "FFF3E4")
    static let brandBackgroundBottom = Color(hex: "FDEFDF")

    static let brandRed = Color(hex: "E5202E")
    static let brandRedDark = Color(hex: "C71D1D")
    static let ctaGradient = LinearGradient(
        colors: [Color(hex: "EC2A32"), Color(hex: "DA2226"), Color(hex: "C71D1D")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let textPrimary = Color(hex: "1A1712")
    static let textSecondary = Color(hex: "7C7266")
    static let textMuted = Color(hex: "B4A896")

    static let fieldBackground = Color.white
    static let fieldBorder = Color(hex: "EFE3CE")
    static let fieldDivider = Color(hex: "E9DBC2")

    static let otpBoxBackground = Color.white
    static let otpBoxBorder = Color(hex: "ECDFC9")
    static let otpBoxBorderActive = Color(hex: "E5202E")
    static let otpPlaceholderDot = Color(hex: "CDBBA2")

    static let accentRed = Color(hex: "E5202E")
    static let accentOrange = Color(hex: "F97316")
    static let accentYellow = Color(hex: "F59E0B")

    static let badgeSuccess = Color(hex: "2E9E6E")
    static let badgePrivate = Color(hex: "E8562A")

    // MARK: - Home

    static let homeCanvas = Color.white
    static let homeHeaderTop = Color(hex: "6E2440")
    static let homeHeaderBottom = Color(hex: "4A182C")
    static let homeHeaderSurface = Color(hex: "F3E1E8")

    static let accentSoft = Color(hex: "FFEBEE")
    static let discountBadge = Color(hex: "E5202E")
    static let newBadgeBackground = Color(hex: "E0F2FE")
    static let newBadgeText = Color(hex: "0369A1")

    static let cardBorder = Color.black.opacity(0.06)
    static let imageTile = Color(hex: "F4F4F5")

    /// Backdrop for the `black_lazy_row` product rail, matching Android's featured carousel.
    static let blackCard = Color(hex: "1C1C1E")
    static let blackCardMuted = Color(hex: "9CA3AF")

    /// Light red wash behind category sections — Android's Blinkit-style panel.
    static let categoryPanel = Color(hex: "FDECEC")
    static let categoryRail = Color(hex: "F7F7F8")
    static let heroTile = Color(hex: "F6F5F3")
    static let cardSoft = Color(hex: "F7F4EE")
    static let saveBadgeFill = Color(hex: "DCFCE7")
}
