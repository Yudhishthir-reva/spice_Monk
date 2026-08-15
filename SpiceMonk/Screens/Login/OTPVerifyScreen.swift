//
//  OTPVerifyScreen.swift
//  SpiceMonk
//

import SwiftUI

struct OTPVerifyScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OTPVerifyViewModel
    @FocusState private var isOTPFocused: Bool

    init(mobile: String, prefilledOTP: String = "") {
        _viewModel = StateObject(
            wrappedValue: OTPVerifyViewModel(mobile: mobile, prefilledOTP: prefilledOTP)
        )
    }

    var body: some View {
        ZStack {
            AnimatedBrandBackground()
            AuthSpiceBackdrop()

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.top, 8)

                Text("Verify your number")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.top, 28)

                AccentDash()
                    .padding(.top, 10)

                HStack(spacing: 4) {
                    Text("OTP sent to +91 \(formattedMobile)")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                    Button("Change") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.brandRed)
                }
                .padding(.top, 12)

                otpBoxes
                    .padding(.top, 28)

                PrimaryActionButton(
                    title: "Verify OTP",
                    icon: "checkmark",
                    isLoading: viewModel.isShowProcessing
                ) {
                    isOTPFocused = false
                    viewModel.verifyOTP()
                }
                .padding(.top, 28)

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        Text(viewModel.canResend ? "Didn't get the code?" : "Resend OTP in \(viewModel.timerText)")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)

                    Spacer()

                    Button("Resend Now") {
                        viewModel.resendOTP()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(viewModel.canResend ? AppTheme.brandRed : AppTheme.textMuted)
                    .disabled(!viewModel.canResend)
                }
                .padding(.top, 16)

                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .navigationBarHidden(true)
        .onAppear {
            isOTPFocused = true
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    private var formattedMobile: String {
        let digits = viewModel.mobile
        guard digits.count == 10 else { return digits }
        let split = digits.index(digits.startIndex, offsetBy: 5)
        return "\(digits[..<split]) \(digits[split...])"
    }

    private var otpBoxes: some View {
        ZStack {
            TextField("", text: $viewModel.otp)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isOTPFocused)
                .opacity(0.01)
                .onChange(of: viewModel.otp) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(6))
                    if digits != newValue {
                        viewModel.otp = digits
                    }
                }

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    let isActive = viewModel.otp.count == index && isOTPFocused
                    let digit = character(at: index)

                    ZStack {
                        if digit.isEmpty {
                            Circle()
                                .fill(AppTheme.otpPlaceholderDot)
                                .frame(width: 7, height: 7)
                        } else {
                            Text(digit)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppTheme.otpBoxBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isActive ? AppTheme.otpBoxBorderActive : AppTheme.otpBoxBorder,
                                lineWidth: isActive ? 1.6 : 1
                            )
                    }
                }
            }
            .animation(.easeOut(duration: 0.18), value: viewModel.otp)
            .onTapGesture {
                isOTPFocused = true
            }
        }
    }

    private func character(at index: Int) -> String {
        guard index < viewModel.otp.count else { return "" }
        let position = viewModel.otp.index(viewModel.otp.startIndex, offsetBy: index)
        return String(viewModel.otp[position])
    }
}
