//
//  SplashScreen.swift
//  SpiceMonk
//

import SwiftUI

/// Branded splash — the SpiceMonk mark springs in over a cream backdrop alive with spices: some spin
/// in place at the edges, a couple roll all the way across, and the whole field fades up on launch.
/// Held for a minimum dwell while the session resolves, so cold launch reads as a brand moment.
struct SplashScreen: View {

    private let minimumDwell: TimeInterval = 1.8

    @State private var logoEntrance: Double = 0
    @State private var showsWordmark = false
    @State private var showsTagline = false

    var body: some View {
        ZStack {
            AnimatedBrandBackground()
            SplashSpiceField()

            VStack(spacing: 0) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .opacity(logoEntrance)
                    .scaleEffect(0.7 + 0.3 * logoEntrance)
                    .rotationEffect(.degrees((1 - logoEntrance) * -14))

                Text("SpiceMonk")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.top, 24)
                    .opacity(showsWordmark ? 1 : 0)
                    .offset(y: showsWordmark ? 0 : 8)

                Text("Pure Spices · Direct To You")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 6)
                    .opacity(showsTagline ? 1 : 0)
                    .offset(y: showsTagline ? 0 : 8)
            }
        }
        .onAppear(perform: runEntrance)
    }

    private func runEntrance() {
        withAnimation(.spring(response: 0.62, dampingFraction: 0.6)) {
            logoEntrance = 1
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
            showsWordmark = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.28)) {
            showsTagline = true
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
