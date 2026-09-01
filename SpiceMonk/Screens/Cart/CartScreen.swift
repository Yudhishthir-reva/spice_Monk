//
//  CartScreen.swift
//  SpiceMonk
//

import SwiftUI

/// Cart UI matches Android reference: green header, address card, SLA banner, grouped items,
/// payment method, coupon, bill details, cancellation note, and a sticky proceed bar.
struct CartScreen: View {

    @ObservedObject var cart = CartStore.shared
    @ObservedObject var addressViewModel: AddressViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingClear = false
    @State private var isPickingAddress = false
    @State private var isAddingAddress = false
    @State private var isApplyingCoupon = false
    @State private var showCelebrationModal = false
    @State private var celebrationCoupon: AppliedCouponData? = nil
    @State private var isPickingPaymentMethod = false
    @State private var navigateToOrderId: Int? = nil
    @State private var placedOrderData: OrderPlaceData? = nil
    @State private var prepaidInitiateData: PaymentInitiateData? = nil
    @State private var pendingOrderPlaceData: OrderPlaceData? = nil

    init(addressViewModel: AddressViewModel = AddressViewModel()) {
        self.addressViewModel = addressViewModel
    }

    private var itemCount: Int {
        cart.summary.totalItems > 0 ? cart.summary.totalItems : cart.items.reduce(0) { $0 + $1.qty }
    }

    private var couponDiscount: Double {
        guard cart.isAppliedCouponValid else { return 0 }
        if cart.couponDiscount > 0 {
            return cart.couponDiscount
        }
        guard let coupon = cart.appliedCoupon else { return 0 }
        if coupon.discountAmount > 0 {
            return coupon.discountAmount
        }
        let itemsCustomerPrice = max(cart.summary.totalMrp - cart.summary.totalSavings, 0)
        if coupon.type == "flat" {
            return coupon.discountValue
        } else if coupon.type == "percentage" {
            return itemsCustomerPrice * coupon.discountValue / 100.0
        }
        return coupon.discountValue
    }

    private var grandTotalAmount: Double {
        if cart.grandTotal > 0 {
            return cart.grandTotal
        }
        let itemsCustomerPrice = max(cart.summary.totalMrp - cart.summary.totalSavings, 0)
        let discount = couponDiscount
        let totalCharges: Double
        if !cart.charges.isEmpty {
            totalCharges = cart.charges.reduce(0) { sum, charge in
                sum + (charge.isFree ? 0 : charge.amount)
            }
        } else {
            totalCharges = 70 + 10 + 20
        }
        return max(itemsCustomerPrice - discount + totalCharges, 0)
    }

    var body: some View {
        Group {
            if cart.isLoading && cart.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = cart.loadError, cart.isEmpty {
                HomeErrorState(message: error) {
                    cart.load()
                }
            } else if cart.isEmpty {
                emptyState
            } else {
                cartBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Group {
                Color(hex: "F5F5F5")
                if let orderId = navigateToOrderId {
                    NavigationLink(
                        destination: OrderDetailScreen(orderId: orderId),
                        isActive: Binding(
                            get: { navigateToOrderId != nil },
                            set: { active in if !active { navigateToOrderId = nil } }
                        ),
                        label: { EmptyView() }
                    )
                }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OrderPlacedSuccessfully"))) { notification in
            if let placedData = notification.object as? OrderPlaceData {
                placedOrderData = placedData
            }
        }
        .fullScreenCover(item: $placedOrderData) { data in
            OrderSuccessScreen(
                orderData: data,
                onTrack: {
                    placedOrderData = nil
                    // Wait briefly or trigger navigate to detail screen
                    navigateToOrderId = data.orderId
                },
                onDismiss: {
                    placedOrderData = nil
                    dismiss()
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OrderInitiatedPrepaidPayment"))) { notification in
            if let initiateData = notification.object as? PaymentInitiateData,
               let placeData = notification.userInfo?["orderPlaceData"] as? OrderPlaceData {
                pendingOrderPlaceData = placeData
                prepaidInitiateData = initiateData
            }
        }
        .sheet(item: $prepaidInitiateData) { initiateData in
            PaymentSimulationSheet(
                initiateData: initiateData,
                onSuccess: {
                    cart.clearCartAfterPrepaidSuccess()
                    if let placeData = pendingOrderPlaceData {
                        placedOrderData = placeData
                    }
                    pendingOrderPlaceData = nil
                },
                onFailure: { error in
                    cart.toastMessage = error
                    cart.isShowToastView = true
                    pendingOrderPlaceData = nil
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.brandGreen, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.appFont(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Shopping Cart")
                        .font(.appFont(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    if !cart.isEmpty, itemCount > 0 {
                        Text(itemCount == 1 ? "1 item" : "\(itemCount) items")
                            .font(.appFont(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            if !cart.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isConfirmingClear = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.appFont(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .disabled(cart.isClearing)
                }
            }
        }
        .alert("Clear Cart?", isPresented: $isConfirmingClear) {
            Button("Clear", role: .destructive) { cart.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove all items from your cart?")
        }
        .tint(.white)
        .onAppear {
            cart.load()
            addressViewModel.load()
        }
        .sheet(isPresented: $isPickingAddress) {
            AddressPickerSheet(viewModel: addressViewModel)
        }
        .sheet(isPresented: $isAddingAddress) {
            AddressFormScreen { _ in
                addressViewModel.load()
            }
        }
        .sheet(isPresented: $isApplyingCoupon) {
            ApplyCouponSheet { applied in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    celebrationCoupon = applied
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showCelebrationModal = true
                    }
                }
            }
        }
        .overlay {
            if showCelebrationModal, let coupon = celebrationCoupon {
                CouponCelebrationModalView(coupon: coupon) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showCelebrationModal = false
                        celebrationCoupon = nil
                    }
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .sheet(isPresented: $isPickingPaymentMethod) {
            PaymentMethodPickerSheet()
        }
        .cartStoreToast()
    }

    private var cartBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    deliveryAddressCard
                    deliverySlaBanner
                    itemsCard
                    paymentMethodCard
                    couponCard
                    billDetailsCard
                    cancellationNote
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .refreshable { await waitForRefresh() }

            stickyCheckoutBar
        }
    }

    // MARK: - Address

    private var deliveryAddressCard: some View {
        let address = addressViewModel.defaultAddress
        return HStack(spacing: 12) {
            Image(systemName: address == nil ? "mappin.and.ellipse" : "house.fill")
                .font(.appFont(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.brandGreen)
                .frame(width: 38, height: 38)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let address {
                    HStack(spacing: 6) {
                        Text("Delivering to")
                            .font(.appFont(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(address.fullName.isEmptyString ? "Home" : address.fullName)
                            .font(.appFont(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                    }
                    Text(address.cartDeliveryLine)
                        .font(.appFont(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                } else {
                    Text("No delivery address selected")
                        .font(.appFont(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Add an address to proceed to checkout")
                        .font(.appFont(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(address == nil ? "Add" : "Change") {
                if address == nil {
                    isAddingAddress = true
                } else {
                    isPickingAddress = true
                }
            }
            .font(.appFont(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.brandGreen)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private var deliverySlaBanner: some View {
        let title = cart.deliveryInfo?.title.isEmptyString == false ? cart.deliveryInfo!.title : "Delivery in 2 - 7 Days"
        let description = cart.deliveryInfo?.description.isEmptyString == false ? cart.deliveryInfo!.description : "Shipment packed & dispatched from your nearest SpiceMonk hub ( Same day Delivery in Jaipur )"

        return HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.appFont(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.brandGreen)
                .frame(width: 28, height: 28)
                .background(AppTheme.brandGreen.opacity(0.18))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.appFont(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
                Text(description)
                    .font(.appFont(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.brandGreen.opacity(0.2), lineWidth: 1)
        }
    }

    // MARK: - Items

    private var itemsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(cart.items.enumerated()), id: \.element.id) { index, item in
                CartItemRow(
                    item: item,
                    isBusy: cart.isUpdating(item) || cart.isRemoving(item),
                    onIncrement: { cart.changeQty(item, by: 1) },
                    onDecrement: { cart.changeQty(item, by: -1) }
                )
                .opacity(cart.isRemoving(item) ? 0.45 : 1)

                if index < cart.items.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
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

    // MARK: - Payment Method

    private var paymentMethodCard: some View {
        Button {
            isPickingPaymentMethod = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: cart.paymentMethod.icon)
                    .font(.appFont(size: 16))
                    .foregroundStyle(AppTheme.brandGreen)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Paying by")
                        .font(.appFont(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(cart.paymentMethod.rawValue)
                        .font(.appFont(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer(minLength: 0)

                Text("Change")
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.brandGreen)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Coupon

    private var couponCard: some View {
        Group {
            if let coupon = cart.appliedCoupon, !cart.isAppliedCouponValid {
                invalidCouponBanner(coupon: coupon)
            } else {
                couponActionCard
            }
        }
    }

    private var couponActionCard: some View {
        Button {
            if cart.appliedCoupon != nil {
                cart.removeCoupon()
            } else {
                isApplyingCoupon = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .font(.appFont(size: 16))
                    .foregroundStyle(AppTheme.brandGreen)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if let coupon = cart.appliedCoupon {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(coupon.code) applied")
                            .font(.appFont(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Saving of \(CartItem.rupees(couponDiscount)) applied successfully")
                            .font(.appFont(size: 11))
                            .foregroundStyle(AppTheme.brandGreen)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Apply Coupon")
                            .font(.appFont(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Select or enter coupon code")
                            .font(.appFont(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                Text(cart.appliedCoupon != nil ? "Remove" : "Apply")
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(cart.appliedCoupon != nil ? .red : AppTheme.brandGreen)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func invalidCouponBanner(coupon: AppliedCouponData) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.appFont(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "D32F2F"))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(coupon.code) is invalid")
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "B71C1C"))

                Text(cart.couponValidationMessage ?? "This coupon is not valid for your current cart.")
                    .font(.appFont(size: 12))
                    .foregroundStyle(Color(hex: "C62828"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                cart.removeCoupon()
            } label: {
                Text("Remove")
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "B71C1C"))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(hex: "FDF0F1"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "F5C6CB"), lineWidth: 1)
        }
    }

    // MARK: - Bill

    private var billDetailsCard: some View {
        let summary = cart.summary
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.appFont(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.brandGreen)
                Text("Bill Details")
                    .font(.appFont(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Divider()

            billRow(label: "Items Total (MRP)", value: CartItem.rupees(summary.totalMrp), color: AppTheme.textSecondary)

            if summary.totalSavings > 0 {
                billRow(
                    label: "Product Discount",
                    value: "-\(CartItem.rupees(summary.totalSavings))",
                    color: AppTheme.brandGreen
                )
                billRow(
                    label: "Items Total",
                    value: CartItem.rupees(summary.totalCustomerPrice),
                    color: AppTheme.textSecondary
                )
            }

            if couponDiscount > 0, cart.isAppliedCouponValid {
                billRow(
                    label: "Coupon Discount",
                    value: "-\(CartItem.rupees(couponDiscount))",
                    color: AppTheme.brandGreen
                )
            }

            if !cart.charges.isEmpty {
                ForEach(cart.charges) { charge in
                    if charge.isFree {
                        billRow(
                            label: charge.title,
                            value: "FREE",
                            strike: charge.amount > 0 ? CartItem.rupees(charge.amount) : nil,
                            color: AppTheme.brandGreen
                        )
                    } else {
                        billRow(
                            label: charge.title,
                            value: CartItem.rupees(charge.amount),
                            color: AppTheme.textSecondary
                        )
                    }
                }
            } else {
                billRow(label: "Delivery Charges", value: "₹70", color: AppTheme.textSecondary)
                billRow(label: "Handling Charges", value: "₹10", color: AppTheme.textSecondary)
                billRow(label: "Packing Charges", value: "₹20", color: AppTheme.textSecondary)
            }

            Divider()

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Grand Total")
                        .font(.appFont(size: 15, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Inclusive of all taxes")
                        .font(.appFont(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                }
                Spacer()
                Text(CartItem.rupees(grandTotalAmount))
                    .font(.appFont(size: 18, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            let totalSavedAmount = summary.totalSavings + couponDiscount
            if totalSavedAmount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.appFont(size: 14))
                        .foregroundStyle(AppTheme.brandGreen)
                    Text("Yay! You're saving \(CartItem.rupees(totalSavedAmount)) on this order")
                        .font(.appFont(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private func billRow(label: String, value: String, strike: String? = nil, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.appFont(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            if let strike {
                Text(strike)
                    .font(.appFont(size: 11))
                    .strikethrough()
                    .foregroundStyle(AppTheme.textMuted)
            }
            Text(value)
                .font(.appFont(size: 13, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private var cancellationNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.appFont(size: 15))
                .foregroundStyle(AppTheme.brandGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cancellation Policy")
                    .font(.appFont(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Orders cannot be cancelled once packed. Please ensure your delivery address is accurate before placing order.")
                    .font(.appFont(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Sticky bar

    private var stickyCheckoutBar: some View {
        VStack(spacing: 0) {
            // Address strip
            Button {
                if addressViewModel.defaultAddress == nil {
                    isAddingAddress = true
                } else {
                    isPickingAddress = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.appFont(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.brandGreen)
                    Text(stickyAddressLabel)
                        .font(.appFont(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("Change")
                        .font(.appFont(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.accentSoft)
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TO PAY")
                        .font(.appFont(size: 10, weight: .heavy))
                        .foregroundStyle(AppTheme.textMuted)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(CartItem.rupees(grandTotalAmount))
                            .font(.appFont(size: 20, weight: .heavy))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Text(cart.paymentMethod.rawValue)
                        .font(.appFont(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Button {
                    if let address = addressViewModel.defaultAddress {
                        cart.placeOrder(addressId: address.id)
                    } else {
                        cart.toastMessage = "Please select a delivery address."
                        cart.isShowToastView = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Place Order")
                            .font(.appFont(size: 16, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.appFont(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.ctaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(cart.isClearing || cart.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .shadow(color: .black.opacity(0.12), radius: 14, y: -4)
    }

    private var stickyAddressLabel: String {
        if let address = addressViewModel.defaultAddress {
            let line = address.cartStickyLine
            return line.isEmpty ? "Delivering to: \(address.fullName)" : "Delivering to: \(line)"
        }
        return "Select delivery address"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart.badge.minus")
                .font(.appFont(size: 44, weight: .medium))
                .foregroundStyle(AppTheme.brandGreen)
                .frame(width: 110, height: 110)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            Text("Your Cart is Empty")
                .font(.appFont(size: 22, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 16)

            Text("Explore our premium spices, powders, and seasonings to start cooking healthy!")
                .font(.appFont(size: 15))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text("Start Shopping")
                        .font(.appFont(size: 16, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.appFont(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.ctaGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.top, 20)
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F5F5F5"))
        .refreshable { await waitForRefresh() }
    }

    private func waitForRefresh() async {
        cart.refresh()
        while cart.isRefreshing {
            try? await Task.sleep(for: .milliseconds(80))
        }
    }
}

private struct CartItemRow: View {
    
    let item: CartItem
    var isBusy: Bool = false
    var onIncrement: () -> Void = {}
    var onDecrement: () -> Void = {}
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NavigationLink {
                ProductDetailScreen(
                    productId: item.productId,
                    seedName: item.productName,
                    seedImageUrl: item.productImage
                )
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    image
                    details
                }
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            
            CartQtyStepper(
                qty: item.qty,
                inStock: item.inStock,
                canIncrement: item.inStock && item.qty < incrementLimit,
                isBusy: isBusy,
                compact: true,
                onIncrement: onIncrement,
                onDecrement: onDecrement
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var incrementLimit: Int {
        var limit = Int.max
        if item.availableQty > 0 { limit = min(limit, item.availableQty) }
        if let maxQty = item.maxOrderQty, maxQty > 0 { limit = min(limit, maxQty) }
        return limit
    }
    
    private var image: some View {
        RemoteImage(url: item.productImage, contentMode: .fit)
            .padding(4)
            .frame(width: 60, height: 60)
            .background(AppTheme.imageTile)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                if !item.inStock {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.55))
                }
            }
    }
    
    private func formatPrice(_ val: Double) -> String {
        String(format: "₹%.1f", val)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.productName.uppercased())
                .font(.appFont(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
            
            if !item.variantName.isEmptyString {
                Text(item.variantName)
                    .font(.appFont(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 6) {
                Text(formatPrice(item.displayPrice))
                    .font(.appFont(size: 15, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                
                if item.hasDiscount {
                    Text(formatPrice(item.mrp))
                        .font(.appFont(size: 11))
                        .strikethrough()
                        .foregroundStyle(AppTheme.textMuted)
                }
                
                if item.savingsPerUnit > 0 {
                    Text("Save \(CartItem.rupees(item.savingsPerUnit))")
                        .font(.appFont(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(AppTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CartQtyStepper: View {

    let qty: Int
    var inStock: Bool = true
    var canIncrement: Bool = true
    var isBusy: Bool = false
    var compact: Bool = false
    var listing: Bool = false
    var fullWidth: Bool = false
    var onIncrement: () -> Void
    var onDecrement: () -> Void

    private var height: CGFloat { listing ? 30 : (compact ? 32 : 38) }
    private var width: CGFloat { listing ? 76 : (compact ? 88 : 104) }
    private var iconSize: CGFloat { listing ? 12 : (compact ? 14 : 16) }
    private var hitSize: CGFloat { listing ? 24 : (compact ? 24 : 30) }
    private var corner: CGFloat { listing ? 8 : 10 }
    private var addFont: CGFloat { listing ? 12 : (compact ? 12 : 13) }

    var body: some View {
        Group {
            if !inStock {
                Text("Sold out")
                    .font(.appFont(size: compact ? 11 : 12, weight: .bold))
                    .foregroundStyle(Color(hex: "71717A"))
                    .frame(height: compact ? 30 : 36)
                    .padding(.horizontal, 10)
                    .background(Color(hex: "E4E4E7"))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if qty == 0 {
                Button(action: onIncrement) {
                    Text("ADD +")
                        .font(.appFont(size: addFont, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(AppTheme.brandGreen)
                        .frame(maxWidth: fullWidth ? .infinity : nil)
                        .frame(width: fullWidth ? nil : width, height: height)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .stroke(AppTheme.brandGreen, lineWidth: listing ? 1.4 : 1.5)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                }
                .buttonStyle(.borderless)
                .disabled(!canIncrement)
            } else {
                HStack(spacing: 0) {
                    Button(action: onDecrement) {
                        Image(systemName: "minus")
                            .font(.appFont(size: iconSize, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: hitSize, height: hitSize)
                    }

                    Text("\(qty)")
                        .font(.appFont(size: listing ? 12 : (compact ? 13 : 14), weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)

                    Button(action: onIncrement) {
                        Image(systemName: "plus")
                            .font(.appFont(size: iconSize, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: hitSize, height: hitSize)
                    }
                    .disabled(!canIncrement)
                }
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(width: fullWidth ? nil : width, height: height)
                .background(AppTheme.brandGreen)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                .buttonStyle(.borderless)
            }
        }
    }
}
