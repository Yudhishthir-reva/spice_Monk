//
//  SpiceLottie.swift
//  SpiceMonk
//
//  Mirrors Android `SpiceAnim` / `SpiceLottie` — same JSON from designsystem/res/raw.
//

import SwiftUI
import Lottie

/// Spice illustrations and loaders shared with the Android app (`res/raw/*.json`).
enum SpiceAnim: String {
    case loader = "spice_loader"
    case grinder = "spice_grinder"
    case emptyCart = "empty_cart"
    case emptySearch = "empty_search"
    case emptyOrders = "empty_orders"
    case emptyAddress = "empty_address"
    case couponTag = "coupon_tag"
    case paymentProcessing = "payment_processing"
    case outOfStock = "out_of_stock"
    case noNetwork = "no_network"
    case delivery = "delivery_scooter"
    case orderSuccess = "order_success"
    case splash = "spice_splash"
    case confetti = "spice_confetti"
    case cartAdded = "cart_added"

    var loops: Bool {
        switch self {
        case .orderSuccess, .splash, .confetti, .cartAdded:
            return false
        default:
            return true
        }
    }

    /// Frame held when Reduce Motion is on (0…1). Confetti’s last frame is empty.
    var stillProgress: AnimationProgressTime {
        switch self {
        case .confetti: return 0.45
        default: return 1
        }
    }
}

/// Plays a `SpiceAnim` composition from the app bundle.
struct SpiceLottie: UIViewRepresentable {

    let anim: SpiceAnim
    var loopMode: LottieLoopMode? = nil
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var speed: CGFloat = 1
    var onFinished: (() -> Void)? = nil

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let view = LottieAnimationView()
        view.backgroundColor = .clear
        view.contentMode = contentMode
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.animationView = view
        configure(view)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = context.coordinator.animationView else { return }
        if context.coordinator.currentAnim != anim {
            context.coordinator.currentAnim = anim
            configure(view)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(anim: anim)
    }

    private func configure(_ view: LottieAnimationView) {
        view.animation = LottieAnimation.named(anim.rawValue)
        view.contentMode = contentMode
        view.animationSpeed = speed

        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        if reduceMotion {
            view.currentProgress = anim.stillProgress
            view.pause()
            if !anim.loops {
                onFinished?()
            }
            return
        }

        let mode = loopMode ?? (anim.loops ? .loop : .playOnce)
        view.loopMode = mode
        view.play { finished in
            if finished, !anim.loops {
                onFinished?()
            }
        }
    }

    final class Coordinator {
        var animationView: LottieAnimationView?
        var currentAnim: SpiceAnim

        init(anim: SpiceAnim) {
            currentAnim = anim
        }
    }
}

/// Inline spinner — Android `SpiceLoader` default ~64pt.
struct SpiceLoader: View {
    var size: CGFloat = 64
    var speed: CGFloat = 1

    var body: some View {
        SpiceLottie(anim: .loader, speed: speed)
            .frame(width: size, height: size)
            .accessibilityLabel("Loading")
    }
}

/// Full-pane wait with grinder (or another anim) + optional message.
struct SpiceLoadingPane: View {
    var message: String? = nil
    var anim: SpiceAnim = .grinder
    var size: CGFloat = 148

    var body: some View {
        VStack(spacing: 10) {
            SpiceLottie(anim: anim)
                .frame(width: size, height: size)
            if let message, !message.isEmpty {
                Text(message)
                    .font(.appFont(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
