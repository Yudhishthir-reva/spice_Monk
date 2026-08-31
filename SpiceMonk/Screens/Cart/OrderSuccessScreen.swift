//
//  OrderOutcomeScreen.swift
//  SpiceMonk
//
//  Created for Order Success Animation & Outcome States.
//

import SwiftUI

// MARK: - Outcome Skin Tokens

struct OutcomeSkin: Equatable {
    let accent: Color
    let accentDark: Color
    let wash: Color
    let symbol: String
    let celebrate: Bool

    static let success = OutcomeSkin(
        accent:     Color(red: 0.122, green: 0.620, blue: 0.369),  // #1F9E5E
        accentDark: Color(red: 0.082, green: 0.451, blue: 0.278),  // #157347
        wash:       Color(red: 0.918, green: 0.969, blue: 0.941),  // #EAF7F0
        symbol: "checkmark",
        celebrate: true
    )
    static let pending = OutcomeSkin(
        accent:     Color(red: 0.914, green: 0.635, blue: 0.106),  // #E9A21B
        accentDark: Color(red: 0.710, green: 0.459, blue: 0.031),  // #B57508
        wash:       Color(red: 0.992, green: 0.961, blue: 0.894),  // #FDF5E4
        symbol: "hourglass.tophalf.filled",
        celebrate: false
    )
    static let failed = OutcomeSkin(
        accent:     Color(red: 0.839, green: 0.271, blue: 0.271),  // #D64545
        accentDark: Color(red: 0.639, green: 0.180, blue: 0.180),  // #A32E2E
        wash:       Color(red: 0.988, green: 0.929, blue: 0.929),  // #FCEDED
        symbol: "exclamationmark.circle",
        celebrate: false
    )
}

// MARK: - Order Outcome Enum

enum OrderOutcome: Identifiable, Equatable {
    var id: String {
        switch self {
        case .placed(let data): return "placed-\(data.orderId)"
        case .paid(let data): return "paid-\(data.orderId)"
        case .pending(let data): return "pending-\(data?.orderId ?? 0)"
        case .failed(let data, let reason): return "failed-\(data?.orderId ?? 0)-\(reason ?? "")"
        }
    }

    case placed(orderData: OrderPlaceData)
    case paid(orderData: OrderPlaceData)
    case pending(orderData: OrderPlaceData? = nil)
    case failed(orderData: OrderPlaceData? = nil, reason: String? = nil)

    var skin: OutcomeSkin {
        switch self {
        case .placed, .paid:
            return .success
        case .pending:
            return .pending
        case .failed:
            return .failed
        }
    }

    var title: String {
        switch self {
        case .paid:
            return "Payment successful!"
        case .placed:
            return "Order placed!"
        case .pending:
            return "Payment pending"
        case .failed:
            return "Payment failed"
        }
    }

    var subtitle: String {
        switch self {
        case .paid:
            return "We've got your money and your order. The monks are packing your spices."
        case .placed:
            return "The monks are packing your spices."
        case .pending:
            return "We are awaiting confirmation from the payment provider."
        case .failed(_, let reason):
            if let reason, !reason.isEmpty {
                return reason
            }
            return "Your payment could not be processed. Please try again."
        }
    }

    var amountLabel: String {
        switch self {
        case .paid:
            return "Amount paid"
        case .placed:
            return "Pay on delivery"
        case .pending:
            return "Amount"
        case .failed:
            return "Amount due"
        }
    }

    var orderNo: String? {
        switch self {
        case .placed(let data), .paid(let data):
            return data.orderNo.isEmpty ? nil : data.orderNo
        case .pending(let data), .failed(let data, _):
            return (data?.orderNo.isEmpty == false) ? data?.orderNo : nil
        }
    }

    var grandTotal: Double? {
        switch self {
        case .placed(let data), .paid(let data):
            return data.grandTotal > 0 ? data.grandTotal : nil
        case .pending(let data), .failed(let data, _):
            if let total = data?.grandTotal, total > 0 {
                return total
            }
            return nil
        }
    }

    var chip1: (icon: String, text: String) {
        switch self {
        case .paid:
            return ("creditcard", "Paid online")
        case .placed:
            return ("banknote", "Pay on delivery")
        case .pending:
            return ("hourglass", "Pending verification")
        case .failed:
            return ("exclamationmark.circle", "Payment incomplete")
        }
    }

    var chip2: (icon: String, text: String) {
        switch self {
        case .paid, .placed:
            return ("clock", "Packed shortly")
        case .pending:
            return ("clock", "Awaiting update")
        case .failed:
            return ("arrow.clockwise", "Retry available")
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .paid, .placed, .pending:
            return "Track my order"
        case .failed:
            return "Try again"
        }
    }

    var primaryButtonIcon: String {
        switch self {
        case .paid, .placed, .pending:
            return "doc.text"
        case .failed:
            return "arrow.clockwise"
        }
    }

    var secondaryButtonTitle: String {
        return "Continue shopping"
    }
}

// MARK: - Ring Ripple Component

/// One expanding ripple. `progress` is driven 0 -> 1 by the parent; scale and opacity
/// are pure functions of it, matching the Compose `graphicsLayer` version.
private struct Ring: View {
    let progress: CGFloat
    let maxScale: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 88, height: 88)
            .scaleEffect(1 + (maxScale - 1) * progress)
            .opacity((1 - progress) * 0.35)
    }
}

// MARK: - Badge Component

struct OrderOutcomeBadge: View {
    let skin: OutcomeSkin

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badgeShown = false
    @State private var ringOne: CGFloat = 0
    @State private var ringTwo: CGFloat = 0

    var body: some View {
        ZStack {
            if skin.celebrate && !reduceMotion {
                Ring(progress: ringOne, maxScale: 1.9,  color: skin.accent)
                Ring(progress: ringTwo, maxScale: 1.45, color: skin.accent)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [skin.accent, skin.accentDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: skin.symbol)
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(.white)
                )
                .scaleEffect(badgeShown ? 1 : 0.4)
                .opacity(badgeShown ? 1 : 0)
        }
        .frame(width: 140, height: 140)
        .accessibilityElement()
        .accessibilityLabel(Text(skin.celebrate ? "Order placed" : "Payment not complete"))
        .onAppear(perform: play)
    }

    private func play() {
        if reduceMotion {
            badgeShown = true
            return
        }

        // Badge: single-overshoot spring (zeta = 0.5, k = 400).
        withAnimation(.interpolatingSpring(mass: 1, stiffness: 400, damping: 20)) {
            badgeShown = true
        }

        guard skin.celebrate else { return }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        withAnimation(.easeOut(duration: 0.9)) {
            ringOne = 1
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.18)) {
            ringTwo = 1
        }
    }
}

// MARK: - Receipt Card Component

struct OrderReceiptCard: View {
    let skin: OutcomeSkin
    let orderNo: String?
    let amountLabel: String
    let grandTotal: Double?
    let chip1: (icon: String, text: String)
    let chip2: (icon: String, text: String)

    var hasRows: Bool {
        (orderNo != nil && !orderNo!.isEmpty) || (grandTotal != nil && grandTotal! > 0)
    }

    var body: some View {
        VStack(spacing: 10) {
            if let orderNo = orderNo, !orderNo.isEmpty {
                HStack {
                    Text("Order number")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(orderNo)
                        .font(.system(size: 14, weight: .heavy))
                        .kerning(0.4)
                        .foregroundStyle(skin.accentDark)
                }

                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 0.8)
            }

            if let grandTotal = grandTotal, grandTotal > 0 {
                HStack {
                    Text(amountLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("₹\(Int(grandTotal.rounded()))")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 0.8)
            }

            // Two equal-width chips at the bottom
            HStack(spacing: 8) {
                // Chip 1
                HStack(spacing: 6) {
                    Image(systemName: chip1.icon)
                        .font(.system(size: 15, weight: .bold))
                    Text(chip1.text)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(skin.accentDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(skin.wash)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Chip 2
                HStack(spacing: 6) {
                    Image(systemName: chip2.icon)
                        .font(.system(size: 15, weight: .bold))
                    Text(chip2.text)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(skin.accentDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(skin.wash)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, hasRows ? 2 : 0)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(skin.accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Main Order Outcome Screen

struct OrderOutcomeScreen: View {
    let outcome: OrderOutcome
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentOpacity: CGFloat = 0
    @State private var contentOffset: CGFloat = 90

    var skin: OutcomeSkin { outcome.skin }

    init(
        outcome: OrderOutcome,
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void
    ) {
        self.outcome = outcome
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }

    /// Convenience initializer for existing orderData call-sites (COD / Prepaid)
    init(
        orderData: OrderPlaceData,
        onTrack: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        let isCod = orderData.paymentType.lowercased() == "cod"
        self.outcome = isCod ? .placed(orderData: orderData) : .paid(orderData: orderData)
        self.onPrimaryAction = onTrack
        self.onSecondaryAction = onDismiss
    }

    var body: some View {
        ZStack {
            // Vertical page background gradient
            LinearGradient(
                stops: [
                    .init(color: skin.wash, location: 0),
                    .init(color: .white,    location: 0.45),
                    .init(color: .white,    location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Animated Badge (140x140 pt box)
                OrderOutcomeBadge(skin: skin)

                Spacer().frame(height: 18)

                // Animated Content Block
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text(outcome.title)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(outcome.subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    // Receipt card
                    OrderReceiptCard(
                        skin: skin,
                        orderNo: outcome.orderNo,
                        amountLabel: outcome.amountLabel,
                        grandTotal: outcome.grandTotal,
                        chip1: outcome.chip1,
                        chip2: outcome.chip2
                    )

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onPrimaryAction()
                        }) {
                            HStack(spacing: 8) {
                                Text(outcome.primaryButtonTitle)
                                    .font(.system(size: 15, weight: .bold))
                                Image(systemName: outcome.primaryButtonIcon)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [skin.accent, skin.accentDark],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: skin.accent.opacity(0.24), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSecondaryAction()
                        }) {
                            Text(outcome.secondaryButtonTitle)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .opacity(contentOpacity)
                .offset(y: contentOffset)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .onAppear {
            if reduceMotion {
                contentOpacity = 1
                contentOffset = 0
            } else {
                // Content follows the badge by 280 ms
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.easeOut(duration: 0.26)) {
                        contentOpacity = 1
                    }
                    withAnimation(.easeOut(duration: 0.32)) {
                        contentOffset = 0
                    }
                }
            }
        }
    }
}

// Backward compatibility alias
typealias OrderSuccessScreen = OrderOutcomeScreen

// MARK: - Previews

#Preview("Paid (Verified)") {
    OrderOutcomeScreen(
        outcome: .paid(
            orderData: try! JSONDecoder().decode(
                OrderPlaceData.self,
                from: """
                {
                    "order_id": 101,
                    "order_no": "SPM-2026-8812",
                    "payment_type": "prepaid",
                    "items_total": 450,
                    "delivery_charge": 40,
                    "handling_charge": 10,
                    "packing_charge": 0,
                    "coupon_discount": 0,
                    "grand_total": 500
                }
                """.data(using: .utf8)!
            )
        ),
        onPrimaryAction: {},
        onSecondaryAction: {}
    )
}

#Preview("Placed (COD)") {
    OrderOutcomeScreen(
        outcome: .placed(
            orderData: try! JSONDecoder().decode(
                OrderPlaceData.self,
                from: """
                {
                    "order_id": 102,
                    "order_no": "SPM-2026-8813",
                    "payment_type": "cod",
                    "items_total": 600,
                    "delivery_charge": 0,
                    "handling_charge": 0,
                    "packing_charge": 0,
                    "coupon_discount": 50,
                    "grand_total": 550
                }
                """.data(using: .utf8)!
            )
        ),
        onPrimaryAction: {},
        onSecondaryAction: {}
    )
}

#Preview("Pending") {
    OrderOutcomeScreen(
        outcome: .pending(
            orderData: try! JSONDecoder().decode(
                OrderPlaceData.self,
                from: """
                {
                    "order_id": 103,
                    "order_no": "SPM-2026-8814",
                    "payment_type": "prepaid",
                    "items_total": 750,
                    "delivery_charge": 0,
                    "handling_charge": 0,
                    "packing_charge": 0,
                    "coupon_discount": 0,
                    "grand_total": 750
                }
                """.data(using: .utf8)!
            )
        ),
        onPrimaryAction: {},
        onSecondaryAction: {}
    )
}

#Preview("Failed") {
    OrderOutcomeScreen(
        outcome: .failed(
            orderData: try! JSONDecoder().decode(
                OrderPlaceData.self,
                from: """
                {
                    "order_id": 104,
                    "order_no": "SPM-2026-8815",
                    "payment_type": "prepaid",
                    "items_total": 320,
                    "delivery_charge": 40,
                    "handling_charge": 0,
                    "packing_charge": 0,
                    "coupon_discount": 0,
                    "grand_total": 360
                }
                """.data(using: .utf8)!
            ),
            reason: "Bank transaction timed out. No amount was deducted."
        ),
        onPrimaryAction: {},
        onSecondaryAction: {}
    )
}
