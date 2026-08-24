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

// MARK: - Auth Plantation Backdrop (Ported from Android Jetpack Compose)

/// Rich, authentic vector backdrop for the SpiceMonk Auth & Splash screen:
/// - Fresh mint-green canvas background with subtle soft vertical gradients.
/// - Overhead hanging green leaf branches with gentle 2-harmonic wind sway.
/// - Bottom green branches inverted at base.
/// - Smooth drifting leaf particles and floating spices (star anise, cinnamon) floating in mid-air.
/// - 100% Vector Canvas — scales crisply across all screen sizes.
struct AuthPlantationBackdrop: View {
    var showsBranches: Bool = true

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            // Primary & secondary harmonic wind sway
            let swaySlow = sin(2.0 * Double.pi * (time / 7.0))
            let swayFast = sin(2.0 * Double.pi * (time / 3.2))
            let swayAngle = swaySlow * 0.7 + swayFast * 0.25

            // Independent drift channels for floating leaf particles
            let driftA = (time / 12.0).truncatingRemainder(dividingBy: 1.0)
            let driftB = (time / 9.5).truncatingRemainder(dividingBy: 1.0)

            ZStack {
                // Background Gradient
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "F1F8F1"), location: 0.00),
                        .init(color: Color(hex: "EAF5E9"), location: 0.35),
                        .init(color: Color(hex: "DFEFDE"), location: 0.65),
                        .init(color: Color(hex: "D2E8D1"), location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Canvas { context, size in
                    let w = size.width
                    let h = size.height

                    // 1. Floating Leaf Particles (upper atmosphere only)
                    drawFloatingLeafParticles(in: &context, w: w, h: h, driftA: driftA, driftB: driftB)

                    // 2. Overhead Green Branches (Top-Left and Top-Right)
                    if showsBranches {
                        drawOverheadLeafBranches(in: &context, w: w, h: h, sway: swayAngle)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Overhead Leaf Branches

    private func drawOverheadLeafBranches(in context: inout GraphicsContext, w: CGFloat, h: CGFloat, sway: Double) {
        // Top-Left Branch System
        var leftCtx = context
        leftCtx.rotate(by: .degrees(sway))

        var stemLeft = Path()
        stemLeft.move(to: CGPoint(x: -20, y: -20))
        stemLeft.addCurve(
            to: CGPoint(x: w * 0.26, y: h * 0.08),
            control1: CGPoint(x: w * 0.08, y: h * 0.03),
            control2: CGPoint(x: w * 0.16, y: h * 0.06)
        )
        leftCtx.stroke(stemLeft, with: .color(Color(hex: "3F5E24")), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

        var twig1 = Path()
        twig1.move(to: CGPoint(x: w * 0.12, y: h * 0.045))
        twig1.addCurve(
            to: CGPoint(x: w * 0.22, y: h * 0.13),
            control1: CGPoint(x: w * 0.15, y: h * 0.08),
            control2: CGPoint(x: w * 0.18, y: h * 0.11)
        )
        leftCtx.stroke(twig1, with: .color(Color(hex: "4D6E2E")), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        // Background shadow leaves
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.02, stemY: h * 0.00, length: 72, width: 34, angle: 35, isBackground: true)
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.08, stemY: h * 0.02, length: 80, width: 38, angle: 55, isBackground: true)
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.16, stemY: h * 0.05, length: 74, width: 36, angle: 70, isBackground: true)

        // Foreground vibrant leaves
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.05, stemY: h * 0.015, length: 75, width: 35, angle: 45)
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.11, stemY: h * 0.035, length: 82, width: 40, angle: 62)
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.14, stemY: h * 0.005, length: 68, width: 32, angle: 22)
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.19, stemY: h * 0.06, length: 85, width: 42, angle: 78)
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.22, stemY: h * 0.12, length: 65, width: 30, angle: 90)
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.23, stemY: h * 0.03, length: 72, width: 34, angle: 38)
        drawBotanicalLeaf(in: &leftCtx, stemX: w * 0.27, stemY: h * 0.08, length: 60, width: 28, angle: 52)

        // Top-Right Branch System
        var rightCtx = context
        rightCtx.translateBy(x: w, y: 0)
        rightCtx.rotate(by: .degrees(-sway * 0.85))

        var stemRight = Path()
        stemRight.move(to: CGPoint(x: 20, y: -20))
        stemRight.addCurve(
            to: CGPoint(x: -w * 0.26, y: h * 0.08),
            control1: CGPoint(x: -w * 0.08, y: h * 0.03),
            control2: CGPoint(x: -w * 0.16, y: h * 0.06)
        )
        rightCtx.stroke(stemRight, with: .color(Color(hex: "3F5E24")), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

        var rTwig = Path()
        rTwig.move(to: CGPoint(x: -w * 0.12, y: h * 0.045))
        rTwig.addCurve(
            to: CGPoint(x: -w * 0.22, y: h * 0.13),
            control1: CGPoint(x: -w * 0.15, y: h * 0.08),
            control2: CGPoint(x: -w * 0.18, y: h * 0.11)
        )
        rightCtx.stroke(rTwig, with: .color(Color(hex: "4D6E2E")), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        // Background shadow leaves
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.02, stemY: h * 0.00, length: 74, width: 35, angle: -35, isBackground: true)
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.08, stemY: h * 0.02, length: 82, width: 38, angle: -58, isBackground: true)
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.16, stemY: h * 0.05, length: 76, width: 36, angle: -72, isBackground: true)

        // Foreground vibrant leaves
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.05, stemY: h * 0.012, length: 76, width: 36, angle: -42)
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.11, stemY: h * 0.032, length: 84, width: 40, angle: -65)
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.14, stemY: h * 0.005, length: 68, width: 32, angle: -18)
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.19, stemY: h * 0.06, length: 86, width: 42, angle: -80)
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.22, stemY: h * 0.12, length: 66, width: 30, angle: -92)
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.23, stemY: h * 0.03, length: 74, width: 35, angle: -32)
        drawBotanicalLeaf(in: &rightCtx, stemX: -w * 0.27, stemY: h * 0.08, length: 62, width: 28, angle: -54)
    }

    // MARK: - Botanical Leaf

    private func drawBotanicalLeaf(
        in context: inout GraphicsContext,
        stemX: CGFloat,
        stemY: CGFloat,
        length: CGFloat,
        width: CGFloat,
        angle: Double,
        isBackground: Bool = false
    ) {
        var leafCtx = context
        leafCtx.translateBy(x: stemX, y: stemY)
        leafCtx.rotate(by: .degrees(angle))

        // Drop shadow
        var shadowPath = Path()
        let ox: CGFloat = 3
        let oy: CGFloat = 4
        shadowPath.move(to: CGPoint(x: ox, y: oy))
        shadowPath.addCurve(
            to: CGPoint(x: ox, y: length + oy),
            control1: CGPoint(x: width * 0.85 + ox, y: length * 0.35 + oy),
            control2: CGPoint(x: width * 0.70 + ox, y: length * 0.80 + oy)
        )
        shadowPath.addCurve(
            to: CGPoint(x: ox, y: oy),
            control1: CGPoint(x: -width * 0.70 + ox, y: length * 0.80 + oy),
            control2: CGPoint(x: -width * 0.85 + ox, y: length * 0.35 + oy)
        )
        shadowPath.closeSubpath()
        leafCtx.fill(shadowPath, with: .color(Color(hex: "0A2004").opacity(0.10)))

        // Left half (Sunlit green)
        var leftHalf = Path()
        leftHalf.move(to: .zero)
        leftHalf.addCurve(
            to: CGPoint(x: 0, y: length),
            control1: CGPoint(x: -width * 0.85, y: length * 0.35),
            control2: CGPoint(x: -width * 0.70, y: length * 0.80)
        )
        leftHalf.closeSubpath()

        let leftColors = isBackground
            ? [Color(hex: "386822"), Color(hex: "224E14"), Color(hex: "16380A")]
            : [Color(hex: "6AB83E"), Color(hex: "428E24"), Color(hex: "276114")]

        leafCtx.fill(
            leftHalf,
            with: .linearGradient(
                Gradient(colors: leftColors),
                startPoint: CGPoint(x: -width * 0.5, y: 0),
                endPoint: CGPoint(x: 0, y: length)
            )
        )

        // Right half (Deeper shaded green)
        var rightHalf = Path()
        rightHalf.move(to: .zero)
        rightHalf.addCurve(
            to: CGPoint(x: 0, y: length),
            control1: CGPoint(x: width * 0.85, y: length * 0.35),
            control2: CGPoint(x: width * 0.70, y: length * 0.80)
        )
        rightHalf.closeSubpath()

        let rightColors = isBackground
            ? [Color(hex: "224E14"), Color(hex: "163C0C"), Color(hex: "0E2806")]
            : [Color(hex: "529B2E"), Color(hex: "367A1A"), Color(hex: "1D5810")]

        leafCtx.fill(
            rightHalf,
            with: .linearGradient(
                Gradient(colors: rightColors),
                startPoint: CGPoint(x: width * 0.5, y: 0),
                endPoint: CGPoint(x: 0, y: length)
            )
        )

        // Gloss highlight
        if !isBackground {
            var sheen = Path()
            sheen.move(to: CGPoint(x: 0, y: length * 0.12))
            sheen.addCurve(
                to: CGPoint(x: 0, y: length * 0.82),
                control1: CGPoint(x: -width * 0.52, y: length * 0.35),
                control2: CGPoint(x: -width * 0.38, y: length * 0.65)
            )
            sheen.addCurve(
                to: CGPoint(x: 0, y: length * 0.12),
                control1: CGPoint(x: -width * 0.18, y: length * 0.55),
                control2: CGPoint(x: -width * 0.18, y: length * 0.30)
            )
            sheen.closeSubpath()
            leafCtx.fill(sheen, with: .color(Color.white.opacity(0.25)))
        }

        // Midrib central vein
        var midrib = Path()
        midrib.move(to: CGPoint(x: 0, y: length * 0.04))
        midrib.addLine(to: CGPoint(x: 0, y: length * 0.95))
        leafCtx.stroke(
            midrib,
            with: .color(isBackground ? Color(hex: "4A7D2C") : Color(hex: "7DD24E")),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
        )

        // Side lateral veins
        let veinColor = (isBackground ? Color(hex: "1B400F") : Color(hex: "1E5210")).opacity(0.45)
        for v in 1...4 {
            let vy = length * (0.20 + CGFloat(v) * 0.15)
            var rightVein = Path()
            rightVein.move(to: CGPoint(x: 0, y: vy))
            rightVein.addLine(to: CGPoint(x: width * 0.48, y: vy + length * 0.08))
            leafCtx.stroke(rightVein, with: .color(veinColor), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            var leftVein = Path()
            leftVein.move(to: CGPoint(x: 0, y: vy))
            leftVein.addLine(to: CGPoint(x: -width * 0.48, y: vy + length * 0.08))
            leafCtx.stroke(leftVein, with: .color(veinColor), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }

    // MARK: - Floating Leaf Particles

    private func drawFloatingLeafParticles(in context: inout GraphicsContext, w: CGFloat, h: CGFloat, driftA: Double, driftB: Double) {
        let twoPI: Double = 2.0 * Double.pi

        // Particle 1 — Upper-Left drift
        let p1Phase = driftA * twoPI
        let p1X = w * 0.12 + CGFloat(sin(p1Phase)) * w * 0.025
        let p1Y = h * 0.20 + CGFloat(sin(p1Phase * 2.0)) * h * 0.015 + CGFloat(cos(p1Phase * 0.7)) * 6
        let p1Angle = sin(p1Phase * 0.5) * 35 + 15
        drawBotanicalLeaf(in: &context, stemX: p1X, stemY: p1Y, length: 30, width: 15, angle: p1Angle)

        // Particle 2 — Upper-Right drift
        let p2Phase = driftB * twoPI
        let p2X = w * 0.86 + CGFloat(cos(p2Phase)) * w * 0.02
        let p2Y = h * 0.14 + CGFloat(sin(p2Phase * 1.3)) * h * 0.012 + CGFloat(sin(p2Phase * 0.6)) * 5
        let p2Angle = cos(p2Phase * 0.4) * 40 - 30
        drawBotanicalLeaf(in: &context, stemX: p2X, stemY: p2Y, length: 26, width: 13, angle: p2Angle)

        // Particle 3 — Mid-Right drift
        let p3PhaseA = driftA * twoPI
        let p3PhaseB = driftB * twoPI
        let p3X = w * 0.90 + CGFloat(sin(p3PhaseA)) * w * 0.015 + CGFloat(cos(p3PhaseB)) * w * 0.01
        let p3Y = h * 0.30 + CGFloat(cos(p3PhaseA * 1.5)) * h * 0.01 + CGFloat(sin(p3PhaseB * 0.8)) * 4
        let p3Angle = sin(p3PhaseA * 0.3 + p3PhaseB * 0.5) * 30 - 15
        drawBotanicalLeaf(in: &context, stemX: p3X, stemY: p3Y, length: 22, width: 11, angle: p3Angle)

        // Particle 4 — Below left branch
        let p4Phase = driftB * twoPI + 1.5
        let p4X = w * 0.22 + CGFloat(sin(p4Phase * 0.8)) * w * 0.018
        let p4Y = h * 0.16 + CGFloat(cos(p4Phase * 1.1)) * h * 0.01
        let p4Angle = cos(p4Phase * 0.35) * 25 + 40
        drawBotanicalLeaf(in: &context, stemX: p4X, stemY: p4Y, length: 20, width: 10, angle: p4Angle)

        // Particle 5 — Upper-Center drift
        let p5Phase = driftA * twoPI + 2.8
        let p5X = w * 0.55 + CGFloat(cos(p5Phase * 0.6)) * w * 0.02
        let p5Y = h * 0.12 + CGFloat(sin(p5Phase * 0.9)) * h * 0.008
        let p5Angle = sin(p5Phase * 0.25) * 50
        drawBotanicalLeaf(in: &context, stemX: p5X, stemY: p5Y, length: 18, width: 9, angle: p5Angle)
    }

    // MARK: - Floating Spices

    private func drawFloatingSpices(in context: inout GraphicsContext, w: CGFloat, h: CGFloat, driftA: Double, driftB: Double) {
        let twoPI: Double = 2.0 * Double.pi

        // Floating Star Anise 1 (bottom left)
        let s1Phase = driftA * twoPI + 1.0
        let s1X = w * 0.18 + CGFloat(sin(s1Phase)) * w * 0.02
        let s1Y = h * 0.85 + CGFloat(cos(s1Phase * 1.5)) * h * 0.02
        let s1Rot = sin(s1Phase * 0.5) * 45.0
        var s1Ctx = context
        s1Ctx.translateBy(x: s1X, y: s1Y)
        s1Ctx.rotate(by: .degrees(s1Rot))
        drawStarAnisePod(in: &s1Ctx, cx: 0, cy: 0, scale: 0.8)

        // Floating Star Anise 2 (mid right)
        let s2Phase = driftB * twoPI + 2.0
        let s2X = w * 0.82 + CGFloat(cos(s2Phase)) * w * 0.025
        let s2Y = h * 0.75 + CGFloat(sin(s2Phase * 1.2)) * h * 0.015
        let s2Rot = cos(s2Phase * 0.4) * 60.0
        var s2Ctx = context
        s2Ctx.translateBy(x: s2X, y: s2Y)
        s2Ctx.rotate(by: .degrees(s2Rot))
        drawStarAnisePod(in: &s2Ctx, cx: 0, cy: 0, scale: 0.6)

        // Cinnamon stick floating (bottom center-ish)
        let cPhase = driftA * twoPI + 3.0
        let cx = w * 0.65 + CGFloat(sin(cPhase * 0.8)) * w * 0.02
        let cy = h * 0.90 + CGFloat(cos(cPhase * 1.1)) * h * 0.02
        let cRot = sin(cPhase * 0.35) * 30.0 - 15.0
        var cCtx = context
        cCtx.translateBy(x: cx, y: cy)
        cCtx.rotate(by: .degrees(cRot))
        let cinPath = Path(roundedRect: CGRect(x: -25, y: -5, width: 50, height: 10), cornerRadius: 4)
        cCtx.fill(
            cinPath,
            with: .linearGradient(
                Gradient(colors: [Color(hex: "A66838"), Color(hex: "7D461E"), Color(hex: "572C0D")]),
                startPoint: CGPoint(x: 0, y: -5),
                endPoint: CGPoint(x: 0, y: 5)
            )
        )
    }

    // MARK: - Star Anise Pod

    private func drawStarAnisePod(in context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, scale: CGFloat) {
        let outer = 15.0 * scale
        let lobeW = outer * 0.42
        let podDark = Color(hex: "5A3315")
        let podLight = Color(hex: "9A6636")
        let podColor = Color(hex: "7A4A24")

        for i in 0..<8 {
            var podCtx = context
            podCtx.rotate(by: .degrees(Double(i) * 45.0))

            var pod = Path()
            pod.move(to: CGPoint(x: cx, y: cy - outer))
            pod.addCurve(
                to: CGPoint(x: cx, y: cy + outer * 0.04),
                control1: CGPoint(x: cx + lobeW, y: cy - outer * 0.62),
                control2: CGPoint(x: cx + lobeW * 0.62, y: cy - outer * 0.10)
            )
            pod.addCurve(
                to: CGPoint(x: cx, y: cy - outer),
                control1: CGPoint(x: cx - lobeW * 0.62, y: cy - outer * 0.10),
                control2: CGPoint(x: cx - lobeW, y: cy - outer * 0.62)
            )
            pod.closeSubpath()

            podCtx.fill(
                pod,
                with: .linearGradient(
                    Gradient(colors: [podLight, podColor, podDark]),
                    startPoint: CGPoint(x: cx, y: cy - outer),
                    endPoint: CGPoint(x: cx, y: cy)
                )
            )
        }

        let centerPod = Path(ellipseIn: CGRect(x: cx - outer * 0.22, y: cy - outer * 0.22, width: outer * 0.44, height: outer * 0.44))
        context.fill(centerPod, with: .color(podLight))
    }
}

// MARK: - Top Leaves Decoration (Uses the botanical leaf system)

struct TopLeavesDecor: View {
    var showsBranches: Bool = true

    var body: some View {
        AuthPlantationBackdrop(showsBranches: showsBranches)
    }
}

