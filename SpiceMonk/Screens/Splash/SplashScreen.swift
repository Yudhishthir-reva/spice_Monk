//
//  SplashScreen.swift
//  SpiceMonk
//

import SwiftUI

/// Branded splash — matches the spices_mountains visual identity with top leaf branches,
/// animated SpiceMonk logo, tagline, value badges, and mountain artwork pinned flush to the bottom.
struct SplashScreen: View {

    private let minimumDwell: TimeInterval = 2.0

    @State private var logoEntrance: Double = 0
    @State private var showsHeader = false
    @State private var showsBadges = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Background Wash
                LinearGradient(
                    colors: [
                        Color(hex: "EDF7EE"),
                        Color(hex: "E3F2E6"),
                        Color(hex: "D8EBE0")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Top Leaves Decoration & Floating Leaf Particles
                TopLeavesDecor()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Bottom Spices & Mountains Illustration (flush to bottom edge)
                Image("spices_mountains")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width)
                    .frame(height: min(geo.size.height * 0.38, 290), alignment: .bottom)
                    .clipped()
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)

                // Centered Splash Content
                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    // Logo & Header
                    VStack(spacing: 4) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 116, height: 116)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                            }
                            .shadow(color: Color.black.opacity(0.10), radius: 10, y: 5)
                            .opacity(logoEntrance)
                            .scaleEffect(0.7 + 0.3 * logoEntrance)
                            .rotationEffect(.degrees((1 - logoEntrance) * -12))

                        // "Welcome to" with leaf accents
                        HStack(spacing: 6) {
                            Image(systemName: "leaf.fill")
                                .font(.appFont(size: 13))
                                .foregroundStyle(Color(hex: "3F8E4D"))
                                .rotationEffect(.degrees(-20))

                            Text("Welcome to")
                                .font(.appFont(size: 26, weight: .bold, design: .serif))
                                .foregroundStyle(Color(hex: "1F5F32"))

                            Image(systemName: "leaf.fill")
                                .font(.appFont(size: 13))
                                .foregroundStyle(Color(hex: "3F8E4D"))
                                .rotationEffect(.degrees(40))
                        }
                        .padding(.top, 8)
                        .opacity(showsHeader ? 1 : 0)
                        .offset(y: showsHeader ? 0 : 8)

                        // "SpiceMonk" with leaf
                        HStack(spacing: 6) {
                            Text("SpiceMonk")
                                .font(.appFont(size: 38, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(hex: "144E27"))

                            Image(systemName: "leaf.fill")
                                .font(.appFont(size: 20))
                                .foregroundStyle(Color(hex: "3F8E4D"))
                                .rotationEffect(.degrees(25))
                        }
                        .opacity(showsHeader ? 1 : 0)
                        .offset(y: showsHeader ? 0 : 8)

                        // Subtle leaf divider
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(Color(hex: "7CAE8B").opacity(0.6))
                                .frame(width: 28, height: 1)
                            Image(systemName: "leaf.fill")
                                .font(.appFont(size: 9))
                                .foregroundStyle(Color(hex: "3F8E4D"))
                            Rectangle()
                                .fill(Color(hex: "7CAE8B").opacity(0.6))
                                .frame(width: 28, height: 1)
                        }
                        .padding(.top, 4)
                        .opacity(showsHeader ? 1 : 0)

                        Text("India's finest flavours,\ndelivered to your doorstep.")
                            .font(.appFont(size: 15, weight: .medium))
                            .foregroundStyle(Color(hex: "2C4F38"))
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                            .opacity(showsHeader ? 1 : 0)
                            .offset(y: showsHeader ? 0 : 8)
                    }

                    Spacer(minLength: 16)

                    // 3 Feature Badges
                    HStack(spacing: 8) {
                        featureBadge(
                            icon: "leaf.fill",
                            title: "100%",
                            subtitle: "Pure Spices"
                        )
                        featureBadge(
                            icon: "shippingbox.fill",
                            title: "Hygienically",
                            subtitle: "Packed"
                        )
                        featureBadge(
                            icon: "truck.box.fill",
                            title: "Fast & Safe",
                            subtitle: "Delivery"
                        )
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    }
                    .padding(.horizontal, 20)
                    .opacity(showsBadges ? 1 : 0)
                    .offset(y: showsBadges ? 0 : 12)

                    Spacer(minLength: min(geo.size.height * 0.30, 230))
                }
                .padding(.top, geo.safeAreaInsets.top)
                .padding(.bottom, geo.safeAreaInsets.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: runEntrance)
    }

    private func featureBadge(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)

                Image(systemName: icon)
                    .font(.appFont(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "1F6335"))
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.appFont(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "1C3D26"))
                Text(subtitle)
                    .font(.appFont(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "1C3D26"))
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private func runEntrance() {
        AppStatusManager.shared.checkStatus()

        withAnimation(.spring(response: 0.65, dampingFraction: 0.62)) {
            logoEntrance = 1
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.18)) {
            showsHeader = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.35)) {
            showsBadges = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + minimumDwell) {
            if UserDefaultManager.shared.isUserLoggedIn {
                AppRootManager.shared.setRootView(view: HomeScreen())
            } else {
                AppRootManager.shared.setRootView(view: LoginScreen())
            }
        }
    }
}

#Preview {
    SplashScreen()
}

