//
//  AnimatedBrandBackground.swift
//  SpiceMonk
//

import SwiftUI

/// Cream brand wash whose top and bottom tints slowly cross-shift, giving the backdrop a gentle
/// breathing depth. Drawn in a `Canvas` driven by a timeline, so no view state churns per frame.
struct AnimatedBrandBackground: View {

    /// One full out-and-back cycle. Android shifts over 5s and reverses, so the loop is twice that.
    private let cycle: Double = 10

    var body: some View {
        TimelineView(.animation) { timeline in
            let fraction = Self.breathFraction(
                at: timeline.date.timeIntervalSinceReferenceDate,
                cycle: cycle
            )
            let top = AppTheme.brandBackgroundTop.mix(
                with: AppTheme.brandBackgroundBottom,
                by: fraction * 0.4
            )
            let bottom = AppTheme.brandBackgroundBottom.mix(
                with: AppTheme.brandBackgroundTop,
                by: fraction * 0.4
            )

            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [top, bottom]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }
        }
        .ignoresSafeArea()
    }

    /// Eased 0 → 1 → 0 ramp. A cosine keeps velocity continuous, so the wash never visibly snaps
    /// at the turnaround the way a linear reverse would.
    static func breathFraction(at time: TimeInterval, cycle: Double) -> Double {
        (1 - cos(2 * .pi * time / cycle)) / 2
    }
}

// MARK: - Ambient motion

/// Continuous drift for decorative artwork: a vertical bob, a smaller horizontal sway, and a
/// gentle tilt — all from sine waves off one linear clock, so motion has no endpoint snap.
struct AmbientDrift {
    var translation: CGSize
    var rotation: Angle

    init(
        time: TimeInterval,
        amplitude: CGFloat,
        periodMs: Int,
        phase: Double,
        baseRotation: Double = 0,
        swayDegrees: Double = 2.5
    ) {
        let period = Double(max(periodMs, 1)) / 1000
        let progress = (time / period + phase).truncatingRemainder(dividingBy: 1)
        let angle = progress * 2 * .pi

        translation = CGSize(
            width: cos(angle * 2) * amplitude * 0.32,
            height: sin(angle) * amplitude
        )
        rotation = .degrees(baseRotation + sin(angle + 0.6) * swayDegrees)
    }
}

#Preview {
    AnimatedBrandBackground()
}
