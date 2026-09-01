//
//  ApplyCouponSheet.swift
//  SpiceMonk
//

import SwiftUI
import Combine

struct ApplyCouponSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cart = CartStore.shared
    var onCouponApplied: ((AppliedCouponData) -> Void)? = nil

    @State private var coupons: [Coupon] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var couponInput = ""
    @State private var applyError: String? = nil
    @State private var applyingCode: String? = nil

    private let service = CartServiceManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drag handle space or header spacing
                Divider()

                // Enter coupon code row
                HStack(spacing: 12) {
                    TextField("Enter coupon code", text: $couponInput)
                        .font(.appFont(size: 14, weight: .medium))
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

                    let trimmed = couponInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    let isApplyingThis = applyingCode == trimmed && !trimmed.isEmpty

                    Button {
                        applyCouponCode(trimmed)
                    } label: {
                        Group {
                            if isApplyingThis {
                                ProgressView()
                                    .tint(AppTheme.brandGreen)
                                    .scaleEffect(0.85)
                            } else {
                                Text("APPLY")
                                    .font(.appFont(size: 14, weight: .bold))
                                    .foregroundStyle(trimmed.isEmpty ? Color(hex: "A3B8B0") : AppTheme.brandGreen)
                            }
                        }
                        .frame(width: 80, height: 48)
                        .background(trimmed.isEmpty ? Color(hex: "E2E8F0").opacity(0.6) : AppTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(trimmed.isEmpty || applyingCode != nil)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(hex: "F9F9F9"))

                if let applyError {
                    Text(applyError)
                        .font(.appFont(size: 12, weight: .semibold))
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
                                .font(.appFont(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                loadCoupons()
                            }
                            .font(.appFont(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.brandGreen)
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if coupons.isEmpty {
                        VStack(spacing: 8) {
                            Text("No Coupons Available")
                                .font(.appFont(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Check back later for exciting offers!")
                                .font(.appFont(size: 13))
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
                            .font(.appFont(size: 16))
                            .foregroundStyle(AppTheme.brandGreen)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.appFont(size: 18, weight: .semibold))
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
        let isApplyingThis = applyingCode == coupon.code.uppercased()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 0) {
                // Code badge
                Text(coupon.code)
                    .font(.appFont(size: 12, weight: .bold))
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
                    applyCouponCode(coupon.code)
                } label: {
                    if isApplyingThis {
                        ProgressView()
                            .tint(AppTheme.brandGreen)
                            .scaleEffect(0.75)
                    } else {
                        Text("APPLY")
                            .font(.appFont(size: 13, weight: .bold))
                            .foregroundStyle(coupon.isEligible ? AppTheme.brandGreen : Color(hex: "A3B8B0"))
                    }
                }
                .disabled(!coupon.isEligible || applyingCode != nil)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(coupon.discountText)
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(coupon.description)
                    .font(.appFont(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            if !coupon.isEligible, let reason = coupon.ineligibleReason {
                Text(reason)
                    .font(.appFont(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .padding(.top, 2)
            } else {
                Text("Valid till \(coupon.endDate)")
                    .font(.appFont(size: 11))
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
                    loadError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { response in
                coupons = response.coupons
            }
            .store(in: &cancellables)
    }

    private func applyCouponCode(_ rawCode: String) {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }

        applyingCode = code
        applyError = nil

        service.applyCoupon(code: code)
            .receive(on: RunLoop.main)
            .sink { completion in
                applyingCode = nil
                if case .failure(let error) = completion {
                    applyError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { response in
                applyingCode = nil
                if response.status == true, let appliedData = response.data {
                    cart.appliedCoupon = appliedData
                    cart.couponDiscount = appliedData.discountAmount
                    cart.grandTotal = appliedData.finalTotal
                    cart.refresh()
                    dismiss()
                    onCouponApplied?(appliedData)
                } else {
                    applyError = response.message ?? "Failed to apply coupon."
                }
            }
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}
