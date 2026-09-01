//
//  CouponCelebrationModal.swift
//  SpiceMonk
//

import SwiftUI

struct CouponCelebrationModalView: View {
    let coupon: AppliedCouponData
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var checkmarkScale: CGFloat = 0.2
    @State private var ringPulse = false

    private var couponCode: String {
        coupon.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var savingsText: String {
        if coupon.discountAmount > 0 {
            return "You saved \(CartItem.rupees(coupon.discountAmount)) on this order"
        }
        if !coupon.discountText.isEmpty {
            return coupon.discountText
        }
        return "Coupon discount applied on this order"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissModal()
                }

            ConfettiView()

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppTheme.brandGreen.opacity(0.18))
                        .frame(width: 84, height: 84)
                        .scaleEffect(ringPulse ? 1.2 : 0.85)
                        .opacity(ringPulse ? 0.0 : 0.8)
                        .animation(
                            Animation.easeOut(duration: 1.4).repeatForever(autoreverses: false),
                            value: ringPulse
                        )

                    Circle()
                        .fill(AppTheme.brandGreen)
                        .frame(width: 64, height: 64)
                        .shadow(color: AppTheme.brandGreen.opacity(0.35), radius: 10, x: 0, y: 5)

                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(checkmarkScale)
                .padding(.top, 28)

                Text(couponCode)
                    .font(.appFont(size: 11.5, weight: .bold))
                    .foregroundStyle(AppTheme.textMuted)
                    .tracking(2.5)
                    .padding(.top, 18)

                Text("Applied successfully")
                    .font(.appFont(size: 19, weight: .heavy))
                    .foregroundStyle(AppTheme.brandGreen)
                    .padding(.top, 6)

                Text(savingsText)
                    .font(.appFont(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Button(action: dismissModal) {
                    Text("Wohoo! Thanks")
                        .font(.appFont(size: 16, weight: .heavy))
                        .foregroundStyle(AppTheme.brandGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .padding(.top, 22)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: 310)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 30, x: 0, y: 12)
            .scaleEffect(isVisible ? 1.0 : 0.7)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            withAnimation(.spring(response: 0.45, dampingFraction: 0.68, blendDuration: 0)) {
                isVisible = true
                checkmarkScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ringPulse = true
            }
        }
    }

    private func dismissModal() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Confetti

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let isCircle: Bool
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var rotation: Double
    var vRot: Double
    var opacity: Double
}

private struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var timer: Timer?

    private let colors: [Color] = [
        Color(hex: "10B981"),
        AppTheme.brandGreen,
        Color(hex: "F59E0B"),
        Color(hex: "3B82F6"),
        Color(hex: "EC4899"),
        Color(hex: "8B5CF6"),
        AppTheme.accentOrange,
        Color(hex: "06B6D4")
    ]

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, _ in
                for piece in pieces {
                    context.opacity = piece.opacity
                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: piece.x, y: piece.y)
                    transform = transform.rotated(by: CGFloat(piece.rotation * .pi / 180))

                    let rect = CGRect(
                        x: -piece.width / 2,
                        y: -piece.height / 2,
                        width: piece.width,
                        height: piece.height
                    )
                    let path: Path = piece.isCircle
                        ? Path(ellipseIn: rect)
                        : Path(roundedRect: rect, cornerRadius: 2)
                    context.fill(path.applying(transform), with: .color(piece.color))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            spawnConfetti()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func spawnConfetti() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        var newPieces: [ConfettiPiece] = []
        for _ in 0..<75 {
            let isCircle = Bool.random()
            let w: CGFloat = isCircle ? CGFloat.random(in: 6...10) : CGFloat.random(in: 8...14)
            let h: CGFloat = isCircle ? w : CGFloat.random(in: 5...9)
            let startX = CGFloat.random(in: screenWidth * 0.15 ... screenWidth * 0.85)
            let startY = CGFloat.random(in: screenHeight * 0.25 ... screenHeight * 0.45)

            newPieces.append(ConfettiPiece(
                color: colors.randomElement() ?? AppTheme.brandGreen,
                width: w,
                height: h,
                isCircle: isCircle,
                x: startX,
                y: startY,
                vx: CGFloat.random(in: -7...7),
                vy: CGFloat.random(in: -13 ... -4),
                rotation: Double.random(in: 0...360),
                vRot: Double.random(in: -8...8),
                opacity: 1.0
            ))
        }
        pieces = newPieces

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            for index in pieces.indices {
                pieces[index].x += pieces[index].vx
                pieces[index].y += pieces[index].vy
                pieces[index].vy += 0.35
                pieces[index].vx *= 0.98
                pieces[index].rotation += pieces[index].vRot
            }
        }
    }
}
