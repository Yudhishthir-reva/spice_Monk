//
//  FreeDeliveryProgressCard.swift
//  SpiceMonk
//

import SwiftUI

/// Palette shared by the cart card and the floating-bar tray, mirroring Android's
/// `FreeDeliveryNudge` so both platforms read identically.
enum FreeDeliveryStyle {
    /// Deep green-black behind the floating bar's free-delivery tray.
    static let shell = Color(hex: "10261A")
    static let accent = AppTheme.brandGreen
    static let accentDark = AppTheme.brandGreenDark
    static let accentSoft = Color(hex: "E8F5EE")
    static let accentBorder = Color(hex: "B7E4C7")
    /// Saffron reads on the dark shell; brand green would sink into it.
    static let highlight = AppTheme.homeHeaderGlowWarm
}

/// A progress ring around a delivery van that fills toward the threshold and turns into a solid
/// badge with a tick once delivery is free.
struct FreeDeliveryRing: View {

    let progress: FreeDeliveryProgress
    var size: CGFloat
    var progressColor: Color = FreeDeliveryStyle.accent
    var trackColor: Color = FreeDeliveryStyle.accent.opacity(0.22)
    var iconTint: Color? = nil

    var body: some View {
        ZStack {
            if progress.isUnlocked {
                Circle().fill(progressColor)
            } else {
                Circle()
                    .stroke(trackColor, lineWidth: size * 0.11)
                Circle()
                    .trim(from: 0, to: progress.fraction)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: progress.isUnlocked ? "checkmark" : "truck.box.fill")
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
                .frame(width: size * 0.5, height: size * 0.5)
                .foregroundStyle(progress.isUnlocked ? Color.white : (iconTint ?? progressColor))
        }
        .frame(width: size, height: size)
        .scaleEffect(progress.isUnlocked ? 1 : 0.92)
        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: progress.fraction)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: progress.isUnlocked)
    }
}

/// "Add **₹481** more for **FREE delivery**" / "**FREE delivery** unlocked".
func freeDeliveryHeadline(
    _ progress: FreeDeliveryProgress,
    size: CGFloat,
    highlight: Color = FreeDeliveryStyle.accent
) -> Text {
    func strong(_ value: String) -> Text {
        Text(value).font(.appFont(size: size, weight: .heavy)).foregroundColor(highlight)
    }
    if progress.isUnlocked {
        return strong("FREE delivery") + Text(" unlocked")
    }
    return Text("Add ")
        + strong(progress.remainingLabel)
        + Text(" more for ")
        + strong("FREE delivery")
}

/// The cart screen's free-delivery card: a road the delivery van drives along as the cart grows,
/// from what's in the cart toward the threshold.
struct FreeDeliveryProgressCard: View {

    let progress: FreeDeliveryProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                FreeDeliveryRing(progress: progress, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    headline
                        .font(.appFont(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.appFont(size: 11.5, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            DeliveryRoad(progress: progress)

            HStack {
                Text("\(progress.cartValueLabel) in cart")
                    .font(.appFont(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 8)
                Text("FREE at \(progress.thresholdLabel)")
                    .font(.appFont(size: 10.5, weight: .bold))
                    .foregroundStyle(progress.isUnlocked ? FreeDeliveryStyle.accent : AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(progress.isUnlocked ? FreeDeliveryStyle.accentSoft : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    progress.isUnlocked ? FreeDeliveryStyle.accentBorder : FreeDeliveryStyle.accent.opacity(0.22),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        .animation(.easeInOut(duration: 0.32), value: progress.isUnlocked)
    }

    private var headline: Text {
        let line = freeDeliveryHeadline(progress, size: 15)
        return progress.isUnlocked ? Text("Yay! ") + line : line
    }

    private var subtitle: String {
        switch (progress.isUnlocked, progress.fee > 0) {
        case (true, true): return "The \(progress.feeLabel) delivery fee is waived on this order"
        case (true, false): return "This order ships free"
        case (false, true): return "Skip the \(progress.feeLabel) delivery fee on orders above \(progress.thresholdLabel)"
        case (false, false): return "Free delivery on orders above \(progress.thresholdLabel)"
        }
    }
}

/// A rounded track with a gradient fill and the van riding at its leading edge.
private struct DeliveryRoad: View {

    let progress: FreeDeliveryProgress

    private let riderSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let riderOffset = max((trackWidth - riderSize) * progress.fraction, 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FreeDeliveryStyle.accent.opacity(0.16))
                    .frame(height: 10)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [FreeDeliveryStyle.accent, FreeDeliveryStyle.accentDark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: trackWidth * progress.fraction, height: 10)
                    }

                // Finish-line flag: a small dot at the threshold end until the van gets there.
                if !progress.isUnlocked {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .overlay { Circle().strokeBorder(FreeDeliveryStyle.accentDark, lineWidth: 3) }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                ZStack {
                    Circle()
                        .fill(progress.isUnlocked ? FreeDeliveryStyle.accent : Color.white)
                        .overlay { Circle().strokeBorder(FreeDeliveryStyle.accent, lineWidth: 2) }

                    Image(systemName: progress.isUnlocked ? "checkmark" : "truck.box.fill")
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.bold)
                        .frame(width: 13, height: 13)
                        .foregroundStyle(progress.isUnlocked ? Color.white : FreeDeliveryStyle.accent)
                }
                .frame(width: riderSize, height: riderSize)
                .offset(x: riderOffset)
            }
            .frame(height: riderSize)
        }
        .frame(height: riderSize)
        .animation(.spring(response: 0.55, dampingFraction: 0.68), value: progress.fraction)
    }
}

/// The strip that rides on top of the floating "View Cart" bar. Kept to one compact line so the
/// bar never grows enough to crowd the product grid.
struct FreeDeliveryTray: View {

    let progress: FreeDeliveryProgress

    private var highlight: Color { FreeDeliveryStyle.highlight }

    var body: some View {
        HStack(spacing: 10) {
            FreeDeliveryRing(
                progress: progress,
                size: 32,
                progressColor: progress.isUnlocked ? FreeDeliveryStyle.accent : highlight,
                trackColor: Color.white.opacity(0.18)
            )

            VStack(alignment: .leading, spacing: 0) {
                freeDeliveryHeadline(progress, size: 13, highlight: highlight)
                    .font(.appFont(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.appFont(size: 11))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !progress.isUnlocked, progress.fee > 0 {
                Text("Save \(progress.feeLabel)")
                    .font(.appFont(size: 10, weight: .heavy))
                    .foregroundStyle(FreeDeliveryStyle.shell)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(highlight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var subtitle: String {
        guard progress.isUnlocked else { return "Free on orders above \(progress.thresholdLabel)" }
        return progress.fee > 0 ? "You're saving \(progress.feeLabel) on delivery" : "Your order ships free"
    }
}
