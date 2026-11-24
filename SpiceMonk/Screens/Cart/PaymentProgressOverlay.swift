//
//  PaymentProgressOverlay.swift
//  SpiceMonk
//

import SwiftUI

/// Covers the screen while the resolver works out what the gateway's result actually meant.
///
/// An overlay, not a sheet. The checkout itself used to live in a SwiftUI `.sheet`, and once the
/// native SDK started presenting its own screen on top there were two presentations stacked — so a
/// dark, empty sheet of ours flashed up every time while Razorpay's was still loading.
///
/// Mirrors Android's `PaymentProgressOverlay`, down to showing a caption: a frozen screen with an
/// unexplained spinner, while money is involved, reads as a hang.
struct PaymentProgressOverlay: View {

    let stage: CheckoutStage

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppTheme.brandGreen)

                Text(stage.caption)
                    .font(.appFont(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(stage.hint)
                    .font(.appFont(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                stepTracker
                    .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 300)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 20, y: 6)
        }
        .transition(.opacity)
    }

    /// order → pay → confirm.
    private var stepTracker: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index <= stage.step ? AppTheme.brandGreen : Color(hex: "E6EDE8"))
                    .frame(width: index == stage.step ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stage.step)
    }
}
