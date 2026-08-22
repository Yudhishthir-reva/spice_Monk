//
//  ApplyCouponSheet.swift
//  SpiceMonk
//

import SwiftUI
import Combine

struct ApplyCouponSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cart = CartStore.shared

    @State private var coupons: [Coupon] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var couponInput = ""
    @State private var applyError: String? = nil

    private let service = CartServiceManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drag handle space or header spacing
                Divider()

                // Enter coupon code row
                HStack(spacing: 12) {
                    TextField("Enter coupon code", text: $couponInput)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        }

                    Button {
                        applyManualCode()
                    } label: {
                        Text("APPLY")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(couponInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(hex: "A3B8B0") : AppTheme.brandGreen)
                            .frame(width: 80, height: 48)
                            .background(couponInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(hex: "E2E8F0").opacity(0.6) : AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(couponInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(hex: "F9F9F9"))

                if let applyError {
                    Text(applyError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                // Coupon list
                Group {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = loadError {
                        VStack(spacing: 12) {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                loadCoupons()
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.brandGreen)
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if coupons.isEmpty {
                        VStack(spacing: 8) {
                            Text("No Coupons Available")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Check back later for exciting offers!")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(coupons) { coupon in
                                    couponCard(coupon)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "F5F5F5"))
            }
            .navigationTitle("Apply Coupon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.brandGreen)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            loadCoupons()
        }
    }

    private func couponCard(_ coupon: Coupon) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 0) {
                // Code badge
                Text(coupon.code)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(AppTheme.brandGreen.opacity(0.3), lineWidth: 1)
                    }

                Spacer()

                // Apply button
                Button {
                    applyCoupon(coupon)
                } label: {
                    Text("APPLY")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(coupon.isEligible ? AppTheme.brandGreen : Color(hex: "A3B8B0"))
                }
                .disabled(!coupon.isEligible)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(coupon.discountText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(coupon.description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            if !coupon.isEligible, let reason = coupon.ineligibleReason {
                Text(reason)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .padding(.top, 2)
            } else {
                Text("Valid till \(coupon.endDate)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Logic

    private func loadCoupons() {
        isLoading = true
        loadError = nil
        service.fetchCoupons()
            .receive(on: RunLoop.main)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    loadError = error.localizedDescription
                }
            } receiveValue: { response in
                coupons = response.coupons
            }
            .store(in: &cancellables)
    }

    private func applyManualCode() {
        let code = couponInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }
        
        applyError = nil
        
        if let found = coupons.first(where: { $0.code.uppercased() == code }) {
            if found.isEligible {
                applyCoupon(found)
            } else {
                applyError = found.ineligibleReason ?? "This coupon is not eligible for your order."
            }
        } else {
            // Simulated validation
            applyError = "Invalid coupon code. Please check and try again."
        }
    }

    private func applyCoupon(_ coupon: Coupon) {
        cart.appliedCoupon = coupon
        cart.toastMessage = "Coupon \(coupon.code) applied successfully!"
        cart.isShowToastView = true
        dismiss()
    }

    @State private var cancellables = Set<AnyCancellable>()
}
