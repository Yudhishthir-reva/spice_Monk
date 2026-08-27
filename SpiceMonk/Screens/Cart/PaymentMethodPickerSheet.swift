//
//  PaymentMethodPickerSheet.swift
//  SpiceMonk
//

import SwiftUI

struct PaymentMethodPickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cart = CartStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("How would you like to pay?")
                    .font(.appFont(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appFont(size: 20))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Options List
            VStack(spacing: 16) {
                ForEach(PaymentMethod.allCases) { method in
                    optionRow(method)
                }
            }
            .padding(20)

            Spacer(minLength: 24)

            // Footer note
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.appFont(size: 14))
                    .foregroundStyle(AppTheme.textMuted)

                Text("Online payments are processed securely by Cashfree. We never see or store your card details.")
                    .font(.appFont(size: 11))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .presentationDetents([.fraction(0.42), .medium])
    }

    private func optionRow(_ method: PaymentMethod) -> some View {
        let isSelected = cart.paymentMethod == method

        return Button {
            cart.paymentMethod = method
            dismiss()
        } label: {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: method.icon)
                    .font(.appFont(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Texts
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.rawValue)
                        .font(.appFont(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(method.description)
                        .font(.appFont(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.appFont(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.brandGreen)
                } else {
                    Circle()
                        .stroke(Color.black.opacity(0.12), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? AppTheme.accentSoft.opacity(0.3) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppTheme.brandGreen : Color.black.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}
