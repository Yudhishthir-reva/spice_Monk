//
//  SpiceBackdrops.swift
//  SpiceMonk
//

import SwiftUI

// MARK: - Auth backdrop

/// One scattered spice behind the auth form. Heroes hug the four corners and bleed off-screen;
/// smaller pods fill the gaps. Alphas stay low so the artwork never competes with the form.
private struct SpiceScatterItem {
    let kind: SpiceKind
    let alignment: Alignment
    let offset: CGSize
    let size: CGFloat
    let rotation: Double
    let opacity: Double
    let amplitude: CGFloat
    let periodMs: Int
    let phase: Double
}

private let authSpiceScatter: [SpiceScatterItem] = [
    // Top-left cluster
    .init(kind: .starAnise, alignment: .topLeading, offset: CGSize(width: -40, height: 20), size: 150, rotation: -12, opacity: 0.72, amplitude: 6, periodMs: 6400, phase: 0.00),
    .init(kind: .cardamom, alignment: .topLeading, offset: CGSize(width: 74, height: 132), size: 46, rotation: 16, opacity: 0.55, amplitude: 5, periodMs: 5200, phase: 0.20),
    .init(kind: .starAnise, alignment: .topLeading, offset: CGSize(width: 10, height: 150), size: 44, rotation: -22, opacity: 0.48, amplitude: 4, periodMs: 4800, phase: 0.55),
    // Top-right cluster
    .init(kind: .redChilli, alignment: .topTrailing, offset: CGSize(width: 40, height: 2), size: 150, rotation: 20, opacity: 0.74, amplitude: 6, periodMs: 6000, phase: 0.35),
    .init(kind: .redChilli, alignment: .topTrailing, offset: CGSize(width: 60, height: 140), size: 74, rotation: -16, opacity: 0.52, amplitude: 5, periodMs: 5600, phase: 0.65),
    .init(kind: .cardamom, alignment: .topTrailing, offset: CGSize(width: -24, height: 150), size: 46, rotation: 10, opacity: 0.5, amplitude: 4, periodMs: 5000, phase: 0.10),
    // Bottom-left cluster
    .init(kind: .cinnamon, alignment: .bottomLeading, offset: CGSize(width: -42, height: -6), size: 150, rotation: -16, opacity: 0.66, amplitude: 6, periodMs: 6600, phase: 0.15),
    .init(kind: .cardamom, alignment: .bottomLeading, offset: CGSize(width: 78, height: 12), size: 48, rotation: 12, opacity: 0.5, amplitude: 5, periodMs: 5400, phase: 0.80),
    .init(kind: .starAnise, alignment: .bottomLeading, offset: CGSize(width: 30, height: 34), size: 46, rotation: -18, opacity: 0.45, amplitude: 4, periodMs: 4600, phase: 0.40),
    // Bottom-right cluster
    .init(kind: .bayLeaf, alignment: .bottomTrailing, offset: CGSize(width: 40, height: 6), size: 152, rotation: 14, opacity: 0.66, amplitude: 6, periodMs: 6200, phase: 0.60),
    .init(kind: .redChilli, alignment: .bottomTrailing, offset: CGSize(width: 56, height: 30), size: 92, rotation: -12, opacity: 0.5, amplitude: 5, periodMs: 5800, phase: 0.25),
    .init(kind: .starAnise, alignment: .bottomTrailing, offset: CGSize(width: 62, height: -30), size: 52, rotation: 16, opacity: 0.44, amplitude: 4, periodMs: 5000, phase: 0.90),
]

/// Gently drifting spice scatter behind the auth form. Decorative only, so it never intercepts taps.
struct AuthSpiceBackdrop: View {

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(Array(authSpiceScatter.enumerated()), id: \.offset) { _, item in
                    let drift = AmbientDrift(
                        time: time,
                        amplitude: item.amplitude,
                        periodMs: item.periodMs,
                        phase: item.phase,
                        baseRotation: item.rotation,
                        swayDegrees: 2.2
                    )

                    SpiceIllustration(kind: item.kind)
                        .frame(width: item.size, height: item.size)
                        .rotationEffect(drift.rotation)
                        .opacity(item.opacity)
                        .offset(
                            x: item.offset.width + drift.translation.width,
                            y: item.offset.height + drift.translation.height
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: item.alignment)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Splash spice field

/// A spice pinned near an edge that spins continuously in place.
private struct Spinner {
    let kind: SpiceKind
    let alignment: Alignment
    let offset: CGSize
    let size: CGFloat
    let spinMs: Int
    let clockwise: Bool
    let opacity: Double
}

private let splashSpinners: [Spinner] = [
    .init(kind: .starAnise, alignment: .topLeading, offset: CGSize(width: -30, height: 40), size: 128, spinMs: 12000, clockwise: true, opacity: 0.55),
    .init(kind: .redChilli, alignment: .topTrailing, offset: CGSize(width: 34, height: 26), size: 132, spinMs: 15000, clockwise: false, opacity: 0.5),
    .init(kind: .cardamom, alignment: .leading, offset: CGSize(width: 18, height: -120), size: 60, spinMs: 9000, clockwise: false, opacity: 0.5),
    .init(kind: .bayLeaf, alignment: .trailing, offset: CGSize(width: -14, height: 150), size: 74, spinMs: 13000, clockwise: true, opacity: 0.5),
    .init(kind: .cinnamon, alignment: .bottomLeading, offset: CGSize(width: -26, height: -30), size: 128, spinMs: 16000, clockwise: true, opacity: 0.55),
    .init(kind: .starAnise, alignment: .bottomTrailing, offset: CGSize(width: 30, height: -16), size: 120, spinMs: 11000, clockwise: false, opacity: 0.5),
    .init(kind: .cardamom, alignment: .bottomTrailing, offset: CGSize(width: -70, height: -150), size: 52, spinMs: 8000, clockwise: true, opacity: 0.45),
]

/// A spice that rolls all the way across the screen while tumbling.
private struct Roller {
    let kind: SpiceKind
    /// -1 is the top of the screen, 1 the bottom.
    let verticalBias: CGFloat
    let size: CGFloat
    let travelMs: Int
    let leftToRight: Bool
    let opacity: Double
}

private let splashRollers: [Roller] = [
    .init(kind: .redChilli, verticalBias: -0.62, size: 46, travelMs: 9000, leftToRight: true, opacity: 0.5),
    .init(kind: .starAnise, verticalBias: 0.66, size: 54, travelMs: 11000, leftToRight: false, opacity: 0.5),
]

/// The splash backdrop: edge spices spin in place while a couple roll all the way across, and the
/// whole field fades up on launch.
struct SplashSpiceField: View {

    @State private var entrance: Double = 0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(Array(splashSpinners.enumerated()), id: \.offset) { _, spinner in
                        let turns = time / (Double(spinner.spinMs) / 1000)
                        let degrees = turns.truncatingRemainder(dividingBy: 1) * 360

                        SpiceIllustration(kind: spinner.kind)
                            .frame(width: spinner.size, height: spinner.size)
                            .rotationEffect(.degrees(spinner.clockwise ? degrees : -degrees))
                            .scaleEffect(0.6 + 0.4 * entrance)
                            .opacity(spinner.opacity * entrance)
                            .offset(x: spinner.offset.width, y: spinner.offset.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: spinner.alignment)
                    }

                    ForEach(Array(splashRollers.enumerated()), id: \.offset) { _, roller in
                        let progress = (time / (Double(roller.travelMs) / 1000))
                            .truncatingRemainder(dividingBy: 1)
                        // Roll off one edge and back on from the other, tumbling as it goes.
                        let startX = -roller.size
                        let endX = geo.size.width + roller.size
                        let x = roller.leftToRight
                            ? startX + (endX - startX) * progress
                            : endX - (endX - startX) * progress
                        let spinDirection: Double = roller.leftToRight ? 1 : -1

                        SpiceIllustration(kind: roller.kind)
                            .frame(width: roller.size, height: roller.size)
                            .rotationEffect(.degrees(progress * 720 * spinDirection))
                            .opacity(roller.opacity * entrance)
                            .offset(
                                x: x - geo.size.width / 2,
                                y: geo.size.height * (roller.verticalBias / 2)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7)) {
                entrance = 1
            }
        }
    }
}

#Preview("Auth backdrop") {
    ZStack {
        AnimatedBrandBackground()
        AuthSpiceBackdrop()
    }
}

#Preview("Splash field") {
    ZStack {
        AnimatedBrandBackground()
        SplashSpiceField()
    }
}
