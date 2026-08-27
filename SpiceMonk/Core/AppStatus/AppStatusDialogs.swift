//
//  AppStatusDialogs.swift
//  SpiceMonk
//
//

import SwiftUI

// MARK: - Maintenance View

struct MaintenanceDialogView: View {

    @ObservedObject private var manager = AppStatusManager.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.accentSoft)
                        .frame(width: 84, height: 84)

                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(AppTheme.brandGreen)
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("MAINTENANCE")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(AppTheme.brandGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentSoft)
                        .clipShape(Capsule())

                    Text("We'll Be Back Soon!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("SpiceMonk is undergoing scheduled maintenance to make your shopping experience even fresher. Please check back shortly.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Retry Button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    manager.checkStatus()
                } label: {
                    HStack(spacing: 8) {
                        if manager.isCheckingStatus {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .bold))
                        }
                        Text(manager.isCheckingStatus ? "Checking..." : "Retry")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(manager.isCheckingStatus)
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Update Dialog View (Force & Soft)

struct AppUpdateDialogView: View {

    let isForce: Bool
    let message: String
    let onUpdate: () -> Void
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.accentSoft)
                        .frame(width: 84, height: 84)

                    Image(systemName: isForce ? "arrow.triangle.2.circlepath.circle.fill" : "sparkles")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(AppTheme.brandGreen)
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text(isForce ? "UPDATE REQUIRED" : "NEW VERSION AVAILABLE")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(AppTheme.brandGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentSoft)
                        .clipShape(Capsule())

                    Text(isForce ? "Time to Update!" : "Exciting New Updates!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(message.isEmptyString ? "A brand new version of SpiceMonk is ready with exciting features, improvements, and freshest flavours. Update now to enjoy the best experience." : message)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 10) {
                    // Update CTA
                    Button(action: onUpdate) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                            Text("Update Now")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.brandGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // Optional Later CTA
                    if !isForce, let onDismiss = onDismiss {
                        Button(action: onDismiss) {
                            Text("Maybe Later")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - View Modifier for Overlays

struct AppStatusOverlayModifier: ViewModifier {

    @ObservedObject private var manager = AppStatusManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            if manager.isMaintenance {
                MaintenanceDialogView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(999999)
            } else if manager.isForceUpdate {
                AppUpdateDialogView(
                    isForce: true,
                    message: manager.updateMessage,
                    onUpdate: {
                        if let url = manager.resolvedUpdateURL {
                            UIApplication.shared.open(url)
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(999998)
            } else if manager.isSoftUpdate {
                AppUpdateDialogView(
                    isForce: false,
                    message: manager.updateMessage,
                    onUpdate: {
                        if let url = manager.resolvedUpdateURL {
                            UIApplication.shared.open(url)
                        }
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            manager.dismissSoftUpdate()
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(999997)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.isMaintenance)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.isForceUpdate)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.isSoftUpdate)
    }
}

extension View {
    func handleAppStatusOverlays() -> some View {
        modifier(AppStatusOverlayModifier())
    }
}
