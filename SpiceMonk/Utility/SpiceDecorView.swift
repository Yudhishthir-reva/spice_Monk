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
                        .font(.system(size: 18, weight: .semibold))
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
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
