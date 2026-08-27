//
//  SpiceDecorView.swift
//  SpiceMonk
//

import SwiftUI

/// Full-width red CTA shared by every auth step.
struct PrimaryActionButton: View {
    let title: String
    var icon: String = "arrow.right"
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.appFont(size: 18, weight: .semibold))
                    Image(systemName: icon)
                        .font(.appFont(size: 12, weight: .bold))
                        .padding(6)
                        .background(Circle().stroke(.white, lineWidth: 1.4))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.ctaGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(isLoading)
    }
}

/// Three-tone brand rule used under headings.
struct AccentDash: View {
    var body: some View {
        HStack(spacing: 6) {
            Capsule().fill(AppTheme.brandRed).frame(width: 28, height: 4)
            Capsule().fill(AppTheme.accentOrange).frame(width: 10, height: 4)
            Capsule().fill(AppTheme.accentYellow).frame(width: 10, height: 4)
        }
    }
}

/// Reusable Shape for rounding specific corners (e.g. top sheets, bottom dialogs)
struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Global Tap To Dismiss Keyboard

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func addTapGestureToDismissKeyboard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            if window.gestureRecognizers?.contains(where: { $0 is KeyboardDismissTapGesture }) == true {
                return
            }

            let tapGesture = KeyboardDismissTapGesture(target: window, action: #selector(UIView.endEditing))
            tapGesture.requiresExclusiveTouchType = false
            tapGesture.cancelsTouchesInView = false
            tapGesture.delegate = KeyboardDismissGestureDelegate.shared
            window.addGestureRecognizer(tapGesture)
        }
    }
}

private class KeyboardDismissTapGesture: UITapGestureRecognizer {}

private class KeyboardDismissGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissGestureDelegate()

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension View {
    /// Dismiss keyboard when tapping on this view
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}
