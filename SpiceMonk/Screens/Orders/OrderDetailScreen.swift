//
//  OrderDetailScreen.swift
//  SpiceMonk
//

import SwiftUI

struct OrderDetailScreen: View {

    let orderId: Int
    @StateObject private var viewModel = OrderDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingCancel = false
    @State private var showCart = false
    @State private var isRepeatingOrder = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.order == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError {
                VStack(spacing: 16) {
                    Text(error)
                        .font(.appFont(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        viewModel.load(orderId: orderId)
                    }
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let order = viewModel.order {
                orderDetailContent(order)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(hex: "F5F5F5"))
        .navigationDestination(isPresented: $showCart) {
            CartScreen()
        }
        .onAppear {
            viewModel.load(orderId: orderId)
        }
    }

    private func orderDetailContent(_ order: OrderDetail) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    statusCard(order)
                    itemsCard(order)
                    savingsBanner(order)
                    billSummaryCard(order)
                    addressCard(order)
                    paymentCard(order)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            VStack(spacing: 0) {
                FloatingCartBar {
                    showCart = true
                }
                stickyBottomBar(order)
            }
        }
        .spiceNavigationBar()
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(order.orderNo)
                        .font(.appFont(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(order.date)
                        .font(.appFont(size: 11))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .alert("Cancel Order", isPresented: $isConfirmingCancel) {
            Button("Cancel Order", role: .destructive) {
                viewModel.cancel(orderId: order.id, reason: "Changed my mind") { success, message in
                    CartStore.shared.toastMessage = message
                    CartStore.shared.isShowToastView = true
                }
            }
            Button("Go Back", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this order?")
        }
    }

    // MARK: - Status Card

    private func statusCard(_ order: OrderDetail) -> some View {
        let statusColor: Color
        switch order.statusCode {
        case 3, 4: // Shipped, Delivered
            statusColor = Color(hex: "4CAF50")
        case 5: // Cancelled
            statusColor = Color(hex: "F44336")
        default: // Pending, Confirmed, Processing
            statusColor = Color(hex: "FFB300")
        }

        return HStack {
            Text("Order status")
                .font(.appFont(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(order.status)
                    .font(.appFont(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "F4F4F5"))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
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

    // MARK: - Items Card

    private func itemsCard(_ order: OrderDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(order.items.count) \(order.items.count == 1 ? "item" : "items") in this order")
                .font(.appFont(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.top, 14)

            VStack(spacing: 0) {
                ForEach(Array(order.items.enumerated()), id: \.element.id) { index, item in
                    itemRow(item)

                    if index < order.items.count - 1 {
                        Divider()
                            .padding(.horizontal, 14)
                    }
                }
            }
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private func itemRow(_ item: OrderDetailItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Product image
            RemoteImage(url: item.productImage, contentMode: .fit)
                .padding(4)
                .frame(width: 54, height: 54)
                .background(AppTheme.imageTile)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Details
            VStack(alignment: .leading, spacing: 3) {
                Text(item.productName.uppercased())
                    .font(.appFont(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(item.weight)
                        .font(.appFont(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "F4F4F5"))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Text("Qty \(item.qty)")
                        .font(.appFont(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "F4F4F5"))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                HStack(spacing: 6) {
                    Text("₹\(Int(item.customerPrice.rounded()))")
                        .font(.appFont(size: 13, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)

                    if item.mrp > item.customerPrice {
                        Text("₹\(Int(item.mrp.rounded()))")
                            .font(.appFont(size: 10))
                            .strikethrough()
                            .foregroundStyle(AppTheme.textMuted)

                        Text("\(Int(item.discountPercent.rounded()))% off")
                            .font(.appFont(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.brandGreen)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Line totals on the right
            VStack(alignment: .trailing, spacing: 2) {
                Text("₹\(Int(item.price.rounded()))")
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if item.saveAmount > 0 {
                    Text("Saved ₹\(Int((item.saveAmount * Double(item.qty)).rounded()))")
                        .font(.appFont(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Savings Banner

    @ViewBuilder
    private func savingsBanner(_ order: OrderDetail) -> some View {
        if order.totalSave > 0 {
            HStack(spacing: 8) {
                Image(systemName: "piggybank.fill")
                    .font(.appFont(size: 15))
                    .foregroundStyle(AppTheme.brandGreen)

                Text("You saved ₹\(Int(order.totalSave.rounded())) on this order")
                    .font(.appFont(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.brandGreen.opacity(0.18), lineWidth: 1)
            }
        }
    }

    // MARK: - Bill Summary

    private func billSummaryCard(_ order: OrderDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.appFont(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.brandGreen)
                Text("Bill summary")
                    .font(.appFont(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Divider()

            billRow(label: "Total MRP", value: "₹\(Int(order.totalMrp.rounded()))", color: AppTheme.textSecondary)

            if order.totalSave > 0 {
                billRow(label: "Product discount", value: "-₹\(Int(order.totalSave.rounded()))", color: AppTheme.brandGreen)
            }

            billRow(label: "Item total", value: "₹\(Int(order.itemsTotal.rounded()))", color: AppTheme.textSecondary)
            billRow(label: "Delivery charge", value: "₹\(Int(order.deliveryCharge.rounded()))", color: AppTheme.textSecondary)
            billRow(label: "Handling charge", value: "₹\(Int(order.handlingCharge.rounded()))", color: AppTheme.textSecondary)
            billRow(label: "Packing charge", value: "₹\(Int(order.packingCharge.rounded()))", color: AppTheme.textSecondary)

            if let coupon = order.couponCode, order.couponDiscount > 0 {
                billRow(label: "Coupon (\(coupon))", value: "-₹\(Int(order.couponDiscount.rounded()))", color: AppTheme.brandGreen)
            }

            Divider()

            HStack {
                Text("Amount to pay")
                    .font(.appFont(size: 15, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("₹\(Int(order.totalAmount.rounded()))")
                    .font(.appFont(size: 16, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
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

    private func billRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.appFont(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.appFont(size: 13, weight: .bold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Delivered Address

    private func addressCard(_ order: OrderDetail) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.appFont(size: 18))
                .foregroundStyle(AppTheme.brandGreen)
                .frame(width: 38, height: 38)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Delivered to")
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(order.deliveryAddress.fullName)
                    .font(.appFont(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(order.deliveryAddress.address)
                    .font(.appFont(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)

                Text(order.deliveryAddress.mobile)
                    .font(.appFont(size: 12))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Payment Card

    private func paymentCard(_ order: OrderDetail) -> some View {
        HStack(spacing: 12) {
            Image(systemName: order.paymentType == "cod" ? "banknote.fill" : "creditcard.fill")
                .font(.appFont(size: 16))
                .foregroundStyle(AppTheme.brandGreen)
                .frame(width: 38, height: 38)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Payment")
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                let label = order.paymentType == "cod" ? "Cash on Delivery" : "Paid Online"
                Text("\(label) · \(order.paymentStatus)")
                    .font(.appFont(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Sticky Bottom Bar

    private func stickyBottomBar(_ order: OrderDetail) -> some View {
        VStack(spacing: 12) {
            // Repeat Order CTA
            Button {
                repeatOrder(order)
            } label: {
                Group {
                    if isRepeatingOrder {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Order these again")
                            .font(.appFont(size: 15, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppTheme.brandGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isRepeatingOrder)

            // Cancel button (only for pending or confirmed orders)
            if order.statusCode == 0 || order.statusCode == 1 {
                Button {
                    cancelOrder(order)
                } label: {
                    Text("Cancel order")
                        .font(.appFont(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "F4F4F6") == Color.white ? .red : AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: .black.opacity(0.06), radius: 10, y: -4)
    }

    // MARK: - CTAs Actions

    private func repeatOrder(_ order: OrderDetail) {
        let items = order.items.map {
            CartStore.RepeatOrderItem(productId: $0.productId, variantId: $0.variantId, qty: $0.qty)
        }
        guard !items.isEmpty else { return }

        isRepeatingOrder = true
        CartStore.shared.repeatOrder(items: items) { added, _ in
            isRepeatingOrder = false
            if added > 0 {
                CartStore.shared.toastMessage = "Added \(added) item\(added == 1 ? "" : "s") to your cart!"
                CartStore.shared.isShowToastView = true
                dismiss()
            } else {
                CartStore.shared.toastMessage = "Could not add items to your cart."
                CartStore.shared.isShowToastView = true
            }
        }
    }

    private func cancelOrder(_ order: OrderDetail) {
        isConfirmingCancel = true
    }
}
