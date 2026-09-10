//
//  SpiceAmbientField.swift
//  SpiceMonk
//
//  Mirrors Android `ambientLayer` spice particles (`SpiceParticles` + FreshMint theme):
//  chillies, cinnamon, star anise, etc. tumbling through the header and page canvas.
//

import SwiftUI

enum SpiceAmbientStyle {
    /// Header hero — denser / brighter (Android header ParticleField).
    case header
    /// Sticky collapsed bar — fewer / softer (Android headerCollapsed ParticleField).
    case collapsed
    /// Page canvas behind cards — quieter, glimpsed in gutters (Android canvas ParticleField).
    case canvas

    var count: Int {
        switch self {
        case .header: return 16
        case .collapsed: return 7
        case .canvas: return 12
        }
    }

    var alpha: CGFloat {
        switch self {
        case .header: return 0.82
        case .collapsed: return 0.34
        case .canvas: return 0.30
        }
    }

    var periodSeconds: TimeInterval {
        switch self {
        case .header: return 17
        case .collapsed: return 24
        case .canvas: return 26
        }
    }

    var sizePoints: CGFloat {
        switch self {
        case .header: return 11.5
        case .collapsed: return 7
        case .canvas: return 9.5
        }
    }

    var phase: CGFloat {
        switch self {
        case .header: return 0.66
        case .collapsed: return 0.2
        case .canvas: return 0.18
        }
    }

    var spinDegrees: CGFloat {
        switch self {
        case .header: return 190
        case .collapsed: return 120
        case .canvas: return 150
        }
    }
}

/// Falling spice silhouettes. Pure draw — no per-frame allocations beyond the Canvas.
struct SpiceAmbientField: View {

    var style: SpiceAmbientStyle = .canvas
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let depthFactors: [CGFloat] = [0.52, 0.92, 1.48]
    private static let tau: CGFloat = 2 * .pi

    private var animates: Bool { !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: animates ? 1.0 / 30.0 : nil)) { timeline in
            let t = animates
                ? timeline.date.timeIntervalSinceReferenceDate
                : 0
            Canvas { context, size in
                drawField(context: context, size: size, time: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawField(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let w = size.width
        let h = size.height
        guard w > 1, h > 1 else { return }

        let depths = Self.depthFactors
        for i in 0..<style.count {
            let seed = CGFloat(i) * 0.137
            let layer = i % depths.count
            let depth = depths[layer]
            let period = style.periodSeconds / Double(depth)
            let layerPhase = (style.phase + CGFloat(layer) * 0.37).truncatingRemainder(dividingBy: 1)
            let clock: CGFloat
            if animates, period > 0 {
                let raw = CGFloat(time / period) + layerPhase + seed
                clock = raw.truncatingRemainder(dividingBy: 1)
            } else {
                clock = (layerPhase + seed).truncatingRemainder(dividingBy: 1)
            }
            let p = clock < 0 ? clock + 1 : clock

            let swayPhase = (p + seed) * Self.tau
            let swayAmount = sin(swayPhase) + sin(swayPhase * 2 + seed) * 0.32
            let swayAmp: CGFloat = 0.075 * depth
            let x = w * ((CGFloat(i) * 0.1613 + 0.06).truncatingRemainder(dividingBy: 1))
                + swayAmount * w * swayAmp
            let y = h * (-0.05 + p * 1.15)
            let travel = sin(p * .pi)
            let alpha = style.alpha * travel * depth
            guard alpha > 0.01 else { continue }

            let radius = style.sizePoints * depth
            let spinDir: CGFloat = i % 2 == 0 ? 1 : -1
            let rotation = seed * 360 + p * style.spinDegrees * spinDir + swayAmount * 12

            SpiceSilhouette.draw(
                kind: SpiceSilhouette.Kind.mix[i % SpiceSilhouette.Kind.mix.count],
                in: context,
                center: CGPoint(x: x, y: y),
                radius: radius,
                rotationDegrees: rotation,
                alpha: alpha
            )
        }
    }
}

extension View {
    /// Android `Modifier.ambientCanvas()` — soft spice fall behind page content.
    func spiceAmbientCanvas() -> some View {
        background {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.homeCanvas, Color(hex: "F7FBF8")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                SpiceAmbientField(style: .canvas)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Silhouettes (unit space −1…1)

enum SpiceSilhouette {
    enum Kind: CaseIterable {
        case starAnise, chilli, cinnamon, cardamom, peppercorn, bayLeaf, clove, turmeric

        static let mix: [Kind] = [
            .starAnise, .chilli, .cinnamon, .cardamom, .peppercorn, .bayLeaf, .clove, .turmeric,
        ]

        var scale: CGFloat {
            switch self {
            case .starAnise: return 1.05
            case .cinnamon: return 1.15
            case .peppercorn: return 0.72
            case .bayLeaf: return 1.1
            case .turmeric: return 0.95
            default: return 1
            }
        }

        var bodyColor: Color {
            switch self {
            case .starAnise: return Color(hex: "8B5A2B")
            case .chilli: return Color(hex: "E0393B")
            case .cinnamon: return Color(hex: "B0672F")
            case .cardamom: return Color(hex: "A9C48A")
            case .peppercorn: return Color(hex: "4A3B34")
            case .bayLeaf: return Color(hex: "5C8F4E")
            case .clove: return Color(hex: "7A4A2A")
            case .turmeric: return Color(hex: "E9A227")
            }
        }

        var accentColor: Color {
            switch self {
            case .starAnise: return Color(hex: "D9A441")
            case .chilli: return Color(hex: "4E9E4A")
            case .cinnamon: return Color(hex: "8A4A1E")
            case .cardamom: return Color(hex: "6F8F55")
            case .peppercorn: return Color(hex: "8D7A6E")
            case .bayLeaf: return Color(hex: "3F6B36")
            case .clove: return Color(hex: "AE7550")
            case .turmeric: return Color(hex: "C97F14")
            }
        }
    }

    static func draw(
        kind: Kind,
        in context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        rotationDegrees: CGFloat,
        alpha: CGFloat
    ) {
        let s = radius * kind.scale
        guard s > 0.5, alpha > 0.004 else { return }

        var ctx = context
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: .degrees(Double(rotationDegrees)))
        ctx.scaleBy(x: s, y: s)

        let body = bodyPath(kind)
        ctx.fill(body, with: .color(kind.bodyColor.opacity(Double(alpha))))

        if let accent = accentPath(kind) {
            let accentAlpha = min(alpha * 1.18, 1)
            ctx.fill(accent, with: .color(kind.accentColor.opacity(Double(accentAlpha))))
        }
    }

    private static func bodyPath(_ kind: Kind) -> Path {
        switch kind {
        case .starAnise:
            return rosette(lobes: 8, outer: 1, lobeWide: 0.40)
        case .chilli:
            var p = Path()
            p.move(to: CGPoint(x: -0.18, y: -0.86))
            p.addCurve(
                to: CGPoint(x: 0.28, y: 0.60),
                control1: CGPoint(x: 0.30, y: -0.72),
                control2: CGPoint(x: 0.48, y: -0.04)
            )
            p.addCurve(
                to: CGPoint(x: 0.04, y: 1),
                control1: CGPoint(x: 0.21, y: 0.86),
                control2: CGPoint(x: 0.13, y: 0.98)
            )
            p.addCurve(
                to: CGPoint(x: -0.21, y: -0.20),
                control1: CGPoint(x: -0.02, y: 0.78),
                control2: CGPoint(x: -0.07, y: 0.28)
            )
            p.addCurve(
                to: CGPoint(x: -0.18, y: -0.86),
                control1: CGPoint(x: -0.29, y: -0.50),
                control2: CGPoint(x: -0.29, y: -0.74)
            )
            p.closeSubpath()
            return p
        case .cinnamon:
            return Path(roundedRect: CGRect(x: -0.30, y: -1, width: 0.60, height: 2), cornerRadius: 0.26)
        case .cardamom, .bayLeaf:
            return pod(wide: kind == .bayLeaf ? 0.62 : 0.52)
        case .peppercorn:
            return Path(ellipseIn: CGRect(x: -0.82, y: -0.82, width: 1.64, height: 1.64))
        case .clove:
            var p = Path()
            p.move(to: CGPoint(x: -0.16, y: -0.30))
            p.addLine(to: CGPoint(x: 0.16, y: -0.30))
            p.addLine(to: CGPoint(x: 0.07, y: 1))
            p.addLine(to: CGPoint(x: -0.07, y: 1))
            p.closeSubpath()
            return p
        case .turmeric:
            return Path(ellipseIn: CGRect(x: -0.44, y: -0.98, width: 0.88, height: 1.60))
        }
    }

    private static func accentPath(_ kind: Kind) -> Path? {
        switch kind {
        case .starAnise:
            return Path(ellipseIn: CGRect(x: -0.26, y: -0.26, width: 0.52, height: 0.52))
        case .chilli:
            var p = Path()
            p.move(to: CGPoint(x: -0.20, y: -0.80))
            p.addCurve(
                to: CGPoint(x: 0.06, y: -1.16),
                control1: CGPoint(x: -0.02, y: -0.94),
                control2: CGPoint(x: 0.10, y: -0.98)
            )
            p.addCurve(
                to: CGPoint(x: -0.34, y: -0.86),
                control1: CGPoint(x: -0.06, y: -1.12),
                control2: CGPoint(x: -0.30, y: -1.02)
            )
            p.closeSubpath()
            return p
        case .cinnamon:
            var p = Path()
            p.addRoundedRect(in: CGRect(x: -0.11, y: -0.86, width: 0.08, height: 1.72), cornerSize: CGSize(width: 0.04, height: 0.04))
            p.addRoundedRect(in: CGRect(x: 0.09, y: -0.80, width: 0.08, height: 1.60), cornerSize: CGSize(width: 0.04, height: 0.04))
            return p
        case .cardamom, .bayLeaf:
            let w: CGFloat = kind == .bayLeaf ? 0.07 : 0.10
            return Path(roundedRect: CGRect(x: -w / 2, y: -0.72, width: w, height: 1.44), cornerRadius: w / 2)
        case .peppercorn:
            return Path(ellipseIn: CGRect(x: -0.52, y: -0.60, width: 0.46, height: 0.42))
        case .clove:
            var p = Path()
            p.addEllipse(in: CGRect(x: -0.34, y: -0.98, width: 0.36, height: 0.48))
            p.addEllipse(in: CGRect(x: -0.02, y: -0.98, width: 0.36, height: 0.48))
            p.addEllipse(in: CGRect(x: -0.20, y: -1.10, width: 0.40, height: 0.38))
            p.addEllipse(in: CGRect(x: -0.20, y: -0.62, width: 0.40, height: 0.36))
            return p
        case .turmeric:
            return Path(ellipseIn: CGRect(x: 0.06, y: 0.14, width: 0.60, height: 0.86))
        }
    }

    private static func pod(wide: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -1))
        p.addCurve(
            to: CGPoint(x: 0, y: 1),
            control1: CGPoint(x: wide, y: -0.52),
            control2: CGPoint(x: wide, y: 0.52)
        )
        p.addCurve(
            to: CGPoint(x: 0, y: -1),
            control1: CGPoint(x: -wide, y: 0.52),
            control2: CGPoint(x: -wide, y: -0.52)
        )
        p.closeSubpath()
        return p
    }

    private static func rosette(lobes: Int, outer: CGFloat, lobeWide: CGFloat) -> Path {
        var p = Path()
        for i in 0..<lobes {
            let a = CGFloat(i) * Self.tau / CGFloat(lobes)
            let c = cos(a)
            let s = sin(a)
            func rx(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x * c - y * s }
            func ry(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x * s + y * c }
            p.move(to: CGPoint(x: rx(0, -outer), y: ry(0, -outer)))
            p.addCurve(
                to: CGPoint(x: rx(0, 0.04), y: ry(0, 0.04)),
                control1: CGPoint(x: rx(lobeWide, -outer * 0.62), y: ry(lobeWide, -outer * 0.62)),
                control2: CGPoint(x: rx(lobeWide * 0.6, -outer * 0.12), y: ry(lobeWide * 0.6, -outer * 0.12))
            )
            p.addCurve(
                to: CGPoint(x: rx(0, -outer), y: ry(0, -outer)),
                control1: CGPoint(x: rx(-lobeWide * 0.6, -outer * 0.12), y: ry(-lobeWide * 0.6, -outer * 0.12)),
                control2: CGPoint(x: rx(-lobeWide, -outer * 0.62), y: ry(-lobeWide, -outer * 0.62))
            )
            p.closeSubpath()
        }
        return p
    }

    private static let tau: CGFloat = 2 * .pi
}
