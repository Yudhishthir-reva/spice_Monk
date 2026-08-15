//
//  SpiceIllustrations.swift
//  SpiceMonk
//

import SwiftUI

enum SpiceKind: CaseIterable {
    case starAnise
    case redChilli
    case cinnamon
    case bayLeaf
    case cardamom
}

/// Hand-drawn spice artwork used as decorative backdrop, so decoration never depends on
/// bundled image files. Each kind draws itself into whatever size it is given.
struct SpiceIllustration: View {

    let kind: SpiceKind

    var body: some View {
        Canvas { context, size in
            switch kind {
            case .starAnise: Self.drawStarAnise(in: &context, size: size)
            case .redChilli: Self.drawChilli(in: &context, size: size)
            case .cinnamon: Self.drawCinnamon(in: &context, size: size)
            case .bayLeaf: Self.drawBayLeaf(in: &context, size: size)
            case .cardamom: Self.drawCardamom(in: &context, size: size)
            }
        }
    }

    // MARK: - Star anise

    private static func drawStarAnise(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) * 0.5
        let lobeW = outer * 0.42

        let podLight = Color(hex: "9A6636")
        let podColor = Color(hex: "7A4A24")
        let podDark = Color(hex: "5A3315")
        let seedColor = Color(hex: "CBA063")

        for i in 0..<8 {
            var pod = Path()
            pod.move(to: CGPoint(x: center.x, y: center.y - outer))
            pod.addCurve(
                to: CGPoint(x: center.x, y: center.y + outer * 0.04),
                control1: CGPoint(x: center.x + lobeW, y: center.y - outer * 0.62),
                control2: CGPoint(x: center.x + lobeW * 0.62, y: center.y - outer * 0.10)
            )
            pod.addCurve(
                to: CGPoint(x: center.x, y: center.y - outer),
                control1: CGPoint(x: center.x - lobeW * 0.62, y: center.y - outer * 0.10),
                control2: CGPoint(x: center.x - lobeW, y: center.y - outer * 0.62)
            )
            pod.closeSubpath()

            var slit = Path()
            slit.move(to: CGPoint(x: center.x, y: center.y - outer * 0.66))
            slit.addLine(to: CGPoint(x: center.x, y: center.y - outer * 0.24))

            let rotation = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: .pi / 4 * Double(i))
                .translatedBy(x: -center.x, y: -center.y)

            context.fill(
                pod.applying(rotation),
                with: .linearGradient(
                    Gradient(colors: [podLight, podColor, podDark]),
                    startPoint: CGPoint(x: center.x, y: center.y - outer),
                    endPoint: center
                )
            )
            context.stroke(
                slit.applying(rotation),
                with: .color(seedColor.opacity(0.7)),
                style: StrokeStyle(lineWidth: outer * 0.05, lineCap: .round)
            )
        }

        let coreRect = CGRect(
            x: center.x - outer * 0.22,
            y: center.y - outer * 0.22,
            width: outer * 0.44,
            height: outer * 0.44
        )
        context.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                Gradient(colors: [podLight, podDark]),
                center: center,
                startRadius: 0,
                endRadius: outer * 0.26
            )
        )
    }

    // MARK: - Red chilli

    private static func drawChilli(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        var body = Path()
        body.move(to: CGPoint(x: w * 0.58, y: h * 0.16))
        body.addCurve(
            to: CGPoint(x: w * 0.60, y: h * 0.86),
            control1: CGPoint(x: w * 0.92, y: h * 0.24),
            control2: CGPoint(x: w * 0.90, y: h * 0.62)
        )
        body.addCurve(
            to: CGPoint(x: w * 0.20, y: h * 0.84),
            control1: CGPoint(x: w * 0.44, y: h * 0.98),
            control2: CGPoint(x: w * 0.24, y: h * 0.96)
        )
        body.addCurve(
            to: CGPoint(x: w * 0.62, y: h * 0.62),
            control1: CGPoint(x: w * 0.34, y: h * 0.90),
            control2: CGPoint(x: w * 0.52, y: h * 0.80)
        )
        body.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.24),
            control1: CGPoint(x: w * 0.72, y: h * 0.44),
            control2: CGPoint(x: w * 0.66, y: h * 0.28)
        )
        body.addCurve(
            to: CGPoint(x: w * 0.58, y: h * 0.16),
            control1: CGPoint(x: w * 0.52, y: h * 0.20),
            control2: CGPoint(x: w * 0.55, y: h * 0.17)
        )
        body.closeSubpath()

        context.fill(
            body,
            with: .linearGradient(
                Gradient(colors: [Color(hex: "F04A3C"), Color(hex: "D8342A"), Color(hex: "B01E1A")]),
                startPoint: CGPoint(x: w * 0.2, y: h * 0.2),
                endPoint: CGPoint(x: w * 0.9, y: h * 0.9)
            )
        )

        var gloss = Path()
        gloss.move(to: CGPoint(x: w * 0.60, y: h * 0.26))
        gloss.addCurve(
            to: CGPoint(x: w * 0.58, y: h * 0.72),
            control1: CGPoint(x: w * 0.78, y: h * 0.34),
            control2: CGPoint(x: w * 0.76, y: h * 0.56)
        )
        gloss.addCurve(
            to: CGPoint(x: w * 0.56, y: h * 0.30),
            control1: CGPoint(x: w * 0.66, y: h * 0.54),
            control2: CGPoint(x: w * 0.66, y: h * 0.38)
        )
        gloss.closeSubpath()
        context.fill(gloss, with: .color(.white.opacity(0.30)))

        var stem = Path()
        stem.move(to: CGPoint(x: w * 0.52, y: h * 0.22))
        stem.addCurve(
            to: CGPoint(x: w * 0.34, y: h * 0.05),
            control1: CGPoint(x: w * 0.50, y: h * 0.10),
            control2: CGPoint(x: w * 0.44, y: h * 0.05)
        )
        stem.addLine(to: CGPoint(x: w * 0.40, y: h * 0.12))
        stem.addCurve(
            to: CGPoint(x: w * 0.48, y: h * 0.26),
            control1: CGPoint(x: w * 0.46, y: h * 0.14),
            control2: CGPoint(x: w * 0.48, y: h * 0.20)
        )
        stem.closeSubpath()
        context.fill(stem, with: .color(Color(hex: "5F8A3E")))

        let knobR = w * 0.035
        context.fill(
            Path(ellipseIn: CGRect(x: w * 0.34 - knobR, y: h * 0.06 - knobR, width: knobR * 2, height: knobR * 2)),
            with: .color(Color(hex: "4C7431"))
        )
    }

    // MARK: - Cinnamon

    private static func drawCinnamon(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let top = h * 0.30
        let bh = h * 0.40

        let barkColor = Color(hex: "A9713F")
        let coreColor = Color(hex: "D9A96C")

        let quill = Path(
            roundedRect: CGRect(x: w * 0.06, y: top, width: w * 0.88, height: bh),
            cornerRadius: bh * 0.5
        )
        context.fill(
            quill,
            with: .linearGradient(
                Gradient(colors: [Color(hex: "B9814C"), barkColor, Color(hex: "7E5026")]),
                startPoint: CGPoint(x: 0, y: top),
                endPoint: CGPoint(x: 0, y: top + bh)
            )
        )

        let cx = w * 0.80
        let cy = top + bh / 2
        for r in 0..<3 {
            let rad = (bh * 0.5) * (1 - Double(r) * 0.28)
            context.fill(
                Path(ellipseIn: CGRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2)),
                with: .color(r % 2 == 0 ? coreColor : barkColor)
            )
        }

        let grain = Color(hex: "6E451F").opacity(0.5)
        for i in 1...3 {
            let y = top + bh * (Double(i) * 0.25)
            var line = Path()
            line.move(to: CGPoint(x: w * 0.14, y: y))
            line.addLine(to: CGPoint(x: w * 0.66, y: y - h * 0.015))
            context.stroke(line, with: .color(grain), style: StrokeStyle(lineWidth: w * 0.012, lineCap: .round))
        }

        context.fill(
            Path(ellipseIn: CGRect(x: w * 0.02, y: top, width: w * 0.12, height: bh)),
            with: .color(coreColor)
        )
    }

    // MARK: - Bay leaf

    private static func drawBayLeaf(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let veinColor = Color(hex: "4C5D2A")

        var leaf = Path()
        leaf.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
        leaf.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.96),
            control1: CGPoint(x: w * 0.90, y: h * 0.26),
            control2: CGPoint(x: w * 0.90, y: h * 0.74)
        )
        leaf.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.04),
            control1: CGPoint(x: w * 0.10, y: h * 0.74),
            control2: CGPoint(x: w * 0.10, y: h * 0.26)
        )
        leaf.closeSubpath()

        context.fill(
            leaf,
            with: .linearGradient(
                Gradient(colors: [Color(hex: "869A55"), Color(hex: "6E8341"), Color(hex: "56692F")]),
                startPoint: CGPoint(x: w * 0.2, y: h * 0.1),
                endPoint: CGPoint(x: w * 0.8, y: h * 0.9)
            )
        )

        var sheen = Path()
        sheen.move(to: CGPoint(x: w * 0.5, y: h * 0.10))
        sheen.addCurve(
            to: CGPoint(x: w * 0.52, y: h * 0.74),
            control1: CGPoint(x: w * 0.74, y: h * 0.28),
            control2: CGPoint(x: w * 0.74, y: h * 0.56)
        )
        sheen.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.16),
            control1: CGPoint(x: w * 0.6, y: h * 0.5),
            control2: CGPoint(x: w * 0.6, y: h * 0.3)
        )
        sheen.closeSubpath()
        context.fill(sheen, with: .color(.white.opacity(0.14)))

        var midrib = Path()
        midrib.move(to: CGPoint(x: w * 0.5, y: h * 0.08))
        midrib.addLine(to: CGPoint(x: w * 0.5, y: h * 0.92))
        context.stroke(midrib, with: .color(veinColor), style: StrokeStyle(lineWidth: w * 0.022, lineCap: .round))

        for i in 1...4 {
            let y = h * (0.20 + Double(i) * 0.14)
            var right = Path()
            right.move(to: CGPoint(x: w * 0.5, y: y))
            right.addLine(to: CGPoint(x: w * 0.74, y: y - h * 0.06))
            var left = Path()
            left.move(to: CGPoint(x: w * 0.5, y: y))
            left.addLine(to: CGPoint(x: w * 0.26, y: y - h * 0.06))

            let style = StrokeStyle(lineWidth: w * 0.012, lineCap: .round)
            context.stroke(right, with: .color(veinColor.opacity(0.65)), style: style)
            context.stroke(left, with: .color(veinColor.opacity(0.65)), style: style)
        }
    }

    // MARK: - Cardamom

    private static func drawCardamom(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let lineColor = Color(hex: "7E8B4A")

        var pod = Path()
        pod.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
        pod.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.94),
            control1: CGPoint(x: w * 0.86, y: h * 0.20),
            control2: CGPoint(x: w * 0.86, y: h * 0.74)
        )
        pod.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.04),
            control1: CGPoint(x: w * 0.14, y: h * 0.74),
            control2: CGPoint(x: w * 0.14, y: h * 0.20)
        )
        pod.closeSubpath()

        context.fill(
            pod,
            with: .linearGradient(
                Gradient(colors: [Color(hex: "C7D488"), Color(hex: "AFBE6E"), Color(hex: "8C9A54")]),
                startPoint: CGPoint(x: w * 0.2, y: h * 0.1),
                endPoint: CGPoint(x: w * 0.8, y: h * 0.9)
            )
        )

        for nx in [0.38, 0.5, 0.62] {
            var seam = Path()
            seam.move(to: CGPoint(x: w * nx, y: h * 0.14))
            seam.addLine(to: CGPoint(x: w * nx, y: h * 0.86))
            context.stroke(
                seam,
                with: .color(lineColor.opacity(nx == 0.5 ? 0.8 : 0.5)),
                style: StrokeStyle(lineWidth: w * 0.02, lineCap: .round)
            )
        }

        var tip = Path()
        tip.move(to: CGPoint(x: w * 0.5, y: h * 0.06))
        tip.addLine(to: CGPoint(x: w * 0.5, y: -h * 0.02))
        context.stroke(
            tip,
            with: .color(Color(hex: "8A7A45")),
            style: StrokeStyle(lineWidth: w * 0.04, lineCap: .round)
        )
    }
}

#Preview {
    HStack {
        ForEach(Array(SpiceKind.allCases.enumerated()), id: \.offset) { _, kind in
            SpiceIllustration(kind: kind)
                .frame(width: 60, height: 60)
        }
    }
    .padding()
    .background(AppTheme.brandBackgroundMid)
}
