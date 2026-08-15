//
//  LoginScreen.swift
//  SpiceMonk
//

import SwiftUI

struct LoginScreen: View {

    @StateObject var viewModel: LoginViewModel = .init()
    @FocusState private var isMobileFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBrandBackground()
                AuthSpiceBackdrop()

                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isMobileFocused ? 96 : 148, height: isMobileFocused ? 96 : 148)

                    Text("Welcome to SpiceMonk")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 18)

                    AccentDash()
                        .padding(.top, 10)

                    if !isMobileFocused {
                        Text("India's finest flavours, delivered to your doorstep.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                            .padding(.horizontal, 32)
                    }

                    mobileField
                        .padding(.top, isMobileFocused ? 22 : 36)
                        .padding(.horizontal, 22)

                    PrimaryActionButton(title: "Continue", isLoading: viewModel.isShowProcessing) {
                        isMobileFocused = false
                        viewModel.sendOTP()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    Spacer()

                    Text(termsFooter)
                        .font(.system(size: 12))
                }
                .padding(.bottom, 18)
                .animation(.easeInOut(duration: 0.38), value: isMobileFocused)
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $viewModel.goToOTP) {
                OTPVerifyScreen(
                    mobile: viewModel.mobile.trim,
                    prefilledOTP: viewModel.echoedOTP
                )
            }
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    private var termsFooter: AttributedString {
        var lead = AttributedString("By continuing you agree to our ")
        lead.foregroundColor = AppTheme.textSecondary

        var terms = AttributedString("Terms & Privacy Policy")
        terms.foregroundColor = AppTheme.textPrimary
        terms.underlineStyle = .single

        return lead + terms
    }

    private var mobileField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Capsule()
                    .fill(AppTheme.brandRed)
                    .frame(width: 3, height: 12)
                Text("MOBILE NUMBER")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(0.6)
            }

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("🇮🇳")
                    Text("+91")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Rectangle()
                    .fill(AppTheme.fieldDivider)
                    .frame(width: 1, height: 22)

                TextField("98765 43210", text: $viewModel.mobile)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .focused($isMobileFocused)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .onChange(of: viewModel.mobile) { _, newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(10))
                        if digits != newValue {
                            viewModel.mobile = digits
                        }
                    }
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(AppTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        viewModel.mobile.isEmpty ? AppTheme.fieldBorder : AppTheme.brandRed,
                        lineWidth: 1
                    )
            }
        }
    }
}

#Preview {
    LoginScreen()
}
