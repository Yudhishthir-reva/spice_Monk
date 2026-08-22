//
//  OrderSuccessScreen.swift
//  SpiceMonk
//

import SwiftUI

struct OrderSuccessScreen: View {

    let orderData: OrderPlaceData
    let onTrack: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "F8FAF8").ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Success Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.brandGreen)
                        .frame(width: 96, height: 96)
                        .shadow(color: AppTheme.brandGreen.opacity(0.24), radius: 12, x: 0, y: 6)

                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                }

                // Headings
                VStack(spacing: 8) {
                    Text("Order placed!")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("The monks are packing your spices.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Details Card
                VStack(spacing: 16) {
                    // Order Number Row
                    HStack {
                        Text("Order number")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text(orderData.orderNo)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.brandGreen)
                    }

                    Divider()

                    // Payment Row
                    HStack {
                        let isCod = orderData.paymentType == "cod"
                        Text(isCod ? "Pay on delivery" : "Paid Online")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("₹\(Int(orderData.grandTotal.rounded()))")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    // Pills List
                    HStack(spacing: 10) {
                        let isCod = orderData.paymentType == "cod"
                        
                        // Badge 1
                        HStack(spacing: 5) {
                            Image(systemName: isCod ? "banknote.fill" : "creditcard.fill")
                                .font(.system(size: 12))
                            Text(isCod ? "Pay on delivery" : "Paid Online")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(AppTheme.brandGreen)
                        .background(AppTheme.accentSoft)
                        .clipShape(Capsule())

                        // Badge 2
                        HStack(spacing: 5) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                            Text("Packed shortly")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(AppTheme.brandGreen)
                        .background(AppTheme.accentSoft)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.02), radius: 6, y: 3)

                Spacer()

                // Buttons block
                VStack(spacing: 16) {
                    // Track Button
                    Button(action: onTrack) {
                        HStack(spacing: 8) {
                            Text("Track my order")
                                .font(.system(size: 15, weight: .bold))
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.brandGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppTheme.brandGreen.opacity(0.18), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)

                    // Dismiss Button
                    Button(action: onDismiss) {
                        Text("Continue shopping")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
