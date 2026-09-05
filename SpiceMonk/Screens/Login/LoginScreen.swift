//
//  LoginScreen.swift
//  SpiceMonk
//

import SwiftUI

struct LoginScreen: View {

    @StateObject var viewModel: LoginViewModel = .init()
    @FocusState private var isMobileFocused: Bool
    @State private var didCheckAppStatus = false
    @State private var isSkipping = false
    var allowsDismiss: Bool = false

    var body: some View {
        NavigationStack {
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

                    // Scrollable Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Header Section
                            VStack(spacing: 4) {
                                Image("AppLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: isMobileFocused ? 80 : 108, height: isMobileFocused ? 80 : 108)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle()
                                            .stroke(Color.white.opacity(0.85), lineWidth: 2)
                                    }
                                    .shadow(color: Color.black.opacity(0.10), radius: 10, y: 5)
                                    .padding(.top, max(geo.safeAreaInsets.top, 54) + 12)

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
                                .padding(.top, 6)

                                // "SpiceMonk" with leaf
                                HStack(spacing: 6) {
                                    Text("SpiceMonk")
                                        .font(.appFont(size: 36, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Color(hex: "144E27"))

                                    Image(systemName: "leaf.fill")
                                        .font(.appFont(size: 18))
                                        .foregroundStyle(Color(hex: "3F8E4D"))
                                        .rotationEffect(.degrees(25))
                                }

                                // Subtle leaf divider
                                HStack(spacing: 8) {
                                    Rectangle()
                                        .fill(Color(hex: "7CAE8B").opacity(0.6))
                                        .frame(width: 24, height: 1)
                                    Image(systemName: "leaf.fill")
                                        .font(.appFont(size: 9))
                                        .foregroundStyle(Color(hex: "3F8E4D"))
                                    Rectangle()
                                        .fill(Color(hex: "7CAE8B").opacity(0.6))
                                        .frame(width: 24, height: 1)
                                }
                                .padding(.top, 4)

                                Text("India's finest flavours,\ndelivered to your doorstep.")
                                    .font(.appFont(size: 14, weight: .medium))
                                    .foregroundStyle(Color(hex: "2C4F38"))
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }

                            // Center Mobile Input Card
                            mobileInputCard
                                .padding(.horizontal, 20)
                                .padding(.top, 18)

                            // 3 Value Proposition Badges
                            featureBadgesCard
                                .padding(.horizontal, 20)
                                .padding(.top, 14)

                            // Dynamic Spacer
                            Spacer(minLength: isMobileFocused ? 24 : 80)

                            // Bottom Terms & Privacy Banner
                            termsPillBanner
                                .padding(.horizontal, 20)
                                .padding(.bottom, max(geo.safeAreaInsets.bottom, 10) + 6)
                        }
                        .frame(minHeight: geo.size.height)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    if allowsDismiss {
                        VStack {
                            HStack {
                                Spacer()
                                Button {
                                    LoginGate.shared.dismiss()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.appFont(size: 14, weight: .bold))
                                        .foregroundStyle(Color(hex: "1F6335"))
                                        .frame(width: 36, height: 36)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 18)
                                .padding(.top, max(geo.safeAreaInsets.top, 12) + 8)
                            }
                            Spacer()
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: isMobileFocused)
            }
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $viewModel.goToOTP) {
                OTPVerifyScreen(
                    mobile: viewModel.mobile.trim
                )
            }
        }
        .onAppear {
            if !didCheckAppStatus {
                didCheckAppStatus = true
                AppStatusManager.shared.checkStatus()
            }
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    // MARK: - Mobile Input Card

    private var mobileInputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "iphone")
                    .font(.appFont(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "1F6335"))
                Text("MOBILE NUMBER")
                    .font(.appFont(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "1F6335"))
                    .tracking(0.6)
            }

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("🇮🇳")
                        .font(.appFont(size: 18))
                    Text("+91")
                        .font(.appFont(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Rectangle()
                    .fill(Color(hex: "DFEAE2"))
                    .frame(width: 1, height: 24)

                TextField("98765 43210", text: $viewModel.mobile)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .focused($isMobileFocused)
                    .font(.appFont(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .onChange(of: viewModel.mobile) { _, newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(10))
                        if digits != newValue {
                            viewModel.mobile = digits
                        }
                    }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color(hex: "FBFDFB"))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isMobileFocused ? Color(hex: "1F6335") : Color(hex: "D3E4DA"),
                        lineWidth: 1.2
                    )
            }

            Button {
                isMobileFocused = false
                viewModel.sendOTP()
            } label: {
                HStack {
                    if viewModel.isShowProcessing {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Spacer()
                        Text("Continue")
                            .font(.appFont(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 32, height: 32)
                            Image(systemName: "arrow.right")
                                .font(.appFont(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "23703B"), Color(hex: "18562B")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(viewModel.isShowProcessing || isSkipping)

            if !allowsDismiss {
                Button {
                    skipLogin()
                } label: {
                    if isSkipping {
                        ProgressView()
                            .tint(Color(hex: "1F6335"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    } else {
                        Text("Skip login")
                            .font(.appFont(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "1F6335"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isShowProcessing || isSkipping)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 6)
    }

    private func skipLogin() {
        guard !isSkipping else { return }
        isMobileFocused = false
        isSkipping = true
        GuestSessionManager.shared.ensureSession {
            isSkipping = false
            if UserDefaultManager.shared.hasValidGuestToken {
                AppRootManager.shared.setRootView(view: HomeScreen())
            } else {
                viewModel.toastMessage = "Unable to continue as guest. Please try again."
                viewModel.isShowToastView = true
            }
        }
    }

    // MARK: - Feature Highlights

    private var featureBadgesCard: some View {
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
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
    }

    private func featureBadge(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 42, height: 42)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)

                Image(systemName: icon)
                    .font(.appFont(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "1F6335"))
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.appFont(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "1C3D26"))
                Text(subtitle)
                    .font(.appFont(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "1C3D26"))
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Terms & Privacy Banner

    private var termsPillBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.appFont(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "278E48"))

            (
                Text("By continuing you agree to our ")
                    .foregroundColor(Color(hex: "2A4834"))
                +
                Text("Terms & Privacy Policy ›")
                    .foregroundColor(Color(hex: "18562B"))
                    .bold()
            )
            .font(.appFont(size: 11.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.92))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white, lineWidth: 1.2)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    LoginScreen()
}


