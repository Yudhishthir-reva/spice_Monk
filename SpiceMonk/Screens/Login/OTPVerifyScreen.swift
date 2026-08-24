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

                // Top Leaves Decoration (Only small animated drifting leaves)
                TopLeavesDecor(showsBranches: false)
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

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(hex: "1F6335"))
                                .frame(width: 42, height: 42)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                        }
                        .padding(.top, max(geo.safeAreaInsets.top, 12) + 8)

                        Text("Verify your number")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "144E27"))
                            .padding(.top, 24)

                        // Subtle leaf divider
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(Color(hex: "7CAE8B").opacity(0.6))
                                .frame(width: 24, height: 1)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "3F8E4D"))
                            Rectangle()
                                .fill(Color(hex: "7CAE8B").opacity(0.6))
                                .frame(width: 24, height: 1)
                        }
                        .padding(.top, 8)

                        HStack(spacing: 4) {
                            Text("OTP sent to +91 \(formattedMobile)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(hex: "3D5E48"))
                            Button("Change") {
                                dismiss()
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "1F6335"))
                        }
                        .padding(.top, 12)

                        // OTP Verification Card
                        VStack(spacing: 20) {
                            otpBoxes

                            Button {
                                isOTPFocused = false
                                viewModel.verifyOTP()
                            } label: {
                                HStack {
                                    if viewModel.isShowProcessing {
                                        ProgressView()
                                            .tint(.white)
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Spacer()
                                        Text("Verify OTP")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.22))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
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
                            .disabled(viewModel.isShowProcessing)
                        }
                        .padding(18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 6)
                        .padding(.top, 24)

                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .foregroundStyle(Color(hex: "1F6335"))
                                Text(viewModel.canResend ? "Didn't get the code?" : "Resend OTP in \(viewModel.timerText)")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "3D5E48"))

                            Spacer()

                            Button("Resend Now") {
                                viewModel.resendOTP()
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(viewModel.canResend ? Color(hex: "1F6335") : AppTheme.textMuted)
                            .disabled(!viewModel.canResend)
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 6)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .ignoresSafeArea()
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

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let isActive = viewModel.otp.count == index && isOTPFocused
                    let digit = character(at: index)

                    ZStack {
                        if digit.isEmpty {
                            Circle()
                                .fill(Color(hex: "9BD1B1"))
                                .frame(width: 7, height: 7)
                        } else {
                            Text(digit)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "FBFDFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isActive ? Color(hex: "1F6335") : Color(hex: "D3E4DA"),
                                lineWidth: isActive ? 1.6 : 1.2
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

#Preview {
    OTPVerifyScreen(mobile: "9876543210")
}
