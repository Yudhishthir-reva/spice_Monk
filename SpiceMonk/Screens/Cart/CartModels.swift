//
//  CartModels.swift
//  SpiceMonk
//

import Foundation

/// One line from `GET customer/cart`. Prices arrive as numbers (unlike catalog strings).
struct CartItem: Decodable, Identifiable {
    let cartId: Int
    let productId: Int
    let productName: String
    let productImage: String?
    let variantId: Int
    let variantName: String
    var qty: Int
    var mrp: Double
    var customerPrice: Double
    var saveAmount: Double
    let discountPercent: Double
    var subtotal: Double
    var availableQty: Int
    let minOrderQty: Int?
    let maxOrderQty: Int?

    var id: Int { cartId > 0 ? cartId : productId * 10_000 + variantId }

    var inStock: Bool { availableQty > 0 }

    var hasDiscount: Bool { customerPrice < mrp && mrp > 0 }

    /// Same truncation as home cards.
    var discountPercentTruncated: Int { Int(discountPercent) }

    var displayPrice: Double { customerPrice > 0 ? customerPrice : mrp }

    var savingsPerUnit: Double { saveAmount > 0 ? saveAmount : max(mrp - displayPrice, 0) }

    var unitPriceLabel: String { Self.rupees(displayPrice) }
    var mrpLabel: String { Self.rupees(mrp) }
    var subtotalLabel: String { Self.rupees(subtotal) }

    enum CodingKeys: String, CodingKey {
        case qty, mrp, subtotal
        case cartId = "cart_id"
        case productId = "product_id"
        case productName = "product_name"
        case productImage = "product_image"
        case variantId = "variant_id"
        case variantName = "variant_name"
        case customerPrice = "customer_price"
        case saveAmount = "save_amount"
        case discountPercent = "discount_percent"
        case availableQty = "avl_qty"
        case minOrderQty = "min_order_qty"
        case maxOrderQty = "max_order_qty"
    }

    init(
        cartId: Int,
        productId: Int,
        productName: String,
        productImage: String?,
        variantId: Int,
        variantName: String,
        qty: Int,
        mrp: Double,
        customerPrice: Double,
        saveAmount: Double,
        discountPercent: Double,
        subtotal: Double,
        availableQty: Int,
        minOrderQty: Int? = 1,
        maxOrderQty: Int? = nil
    ) {
        self.cartId = cartId
        self.productId = productId
        self.productName = productName
        self.productImage = productImage
        self.variantId = variantId
        self.variantName = variantName
        self.qty = qty
        self.mrp = mrp
        self.customerPrice = customerPrice
        self.saveAmount = saveAmount
        self.discountPercent = discountPercent
        self.subtotal = subtotal
        self.availableQty = availableQty
        self.minOrderQty = minOrderQty
        self.maxOrderQty = maxOrderQty
    }

    init(from added: CartAddItem, productName: String = "", productImage: String? = nil, variantName: String = "") {
        self.init(
            cartId: added.cartId,
            productId: added.productId,
            productName: productName,
            productImage: productImage,
            variantId: added.variantId,
            variantName: variantName,
            qty: added.qty,
            mrp: added.mrp,
            customerPrice: added.customerPrice,
            saveAmount: max(added.mrp - added.customerPrice, 0),
            discountPercent: 0,
            subtotal: added.customerPrice * Double(max(added.qty, 0)),
            availableQty: added.availableQty,
            minOrderQty: added.minOrderQty,
            maxOrderQty: added.maxOrderQty
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cartId = container.decodeIntLeniently(forKey: .cartId) ?? 0
        productId = container.decodeIntLeniently(forKey: .productId) ?? 0
        productName = container.decodeStringLeniently(forKey: .productName) ?? ""
        productImage = container.decodeStringLeniently(forKey: .productImage)
        variantId = container.decodeIntLeniently(forKey: .variantId) ?? 0
        variantName = container.decodeStringLeniently(forKey: .variantName) ?? ""
        qty = container.decodeIntLeniently(forKey: .qty)
            ?? Int(container.decodeDoubleLeniently(forKey: .qty) ?? 0)
        mrp = container.decodeDoubleLeniently(forKey: .mrp) ?? 0
        customerPrice = container.decodeDoubleLeniently(forKey: .customerPrice) ?? 0
        saveAmount = container.decodeDoubleLeniently(forKey: .saveAmount) ?? 0
        discountPercent = container.decodeDoubleLeniently(forKey: .discountPercent) ?? 0
        subtotal = container.decodeDoubleLeniently(forKey: .subtotal) ?? 0
        availableQty = container.decodeIntLeniently(forKey: .availableQty) ?? 0
        minOrderQty = container.decodeIntLeniently(forKey: .minOrderQty)
        maxOrderQty = container.decodeIntLeniently(forKey: .maxOrderQty)
    }

    static func money(_ value: Double) -> String {
        rupees(value)
    }

    /// Android cart UI prints whole rupees (`%.0f`).
    static func rupees(_ value: Double) -> String {
        "₹\(Int(value.rounded()))"
    }

    mutating func apply(_ update: CartAddItem) {
        qty = update.qty
        mrp = update.mrp
        customerPrice = update.customerPrice
        availableQty = update.availableQty
        saveAmount = max(mrp - customerPrice, 0)
        subtotal = customerPrice * Double(max(qty, 0))
    }

    mutating func setQty(_ newQty: Int) {
        qty = max(newQty, 0)
        subtotal = customerPrice * Double(qty)
    }
}

struct CartCharge: Decodable, Identifiable {
    let title: String
    let amount: Double
    let isFree: Bool
    let freeAbove: String?

    var id: String { title }

    var formattedAmount: String {
        isFree ? "FREE" : CartItem.rupees(amount)
    }

    enum CodingKeys: String, CodingKey {
        case title, amount
        case isFree = "is_free"
        case freeAbove = "free_above"
    }

    init(title: String, amount: Double, isFree: Bool = false, freeAbove: String? = nil) {
        self.title = title
        self.amount = amount
        self.isFree = isFree
        self.freeAbove = freeAbove
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.decodeStringLeniently(forKey: .title) ?? ""
        amount = container.decodeDoubleLeniently(forKey: .amount) ?? 0
        isFree = container.decodeBoolLeniently(forKey: .isFree) ?? false
        freeAbove = container.decodeStringLeniently(forKey: .freeAbove)
    }
}

struct CartDeliveryInfo: Decodable {
    let title: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case title, description
    }

    init(title: String, description: String) {
        self.title = title
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.decodeStringLeniently(forKey: .title) ?? ""
        description = container.decodeStringLeniently(forKey: .description) ?? ""
    }
}

struct CartSummary: Decodable {
    let totalItems: Int
    let totalMrp: Double
    let totalCustomerPrice: Double
    let totalSavings: Double

    static let empty = CartSummary(totalItems: 0, totalMrp: 0, totalCustomerPrice: 0, totalSavings: 0)

    var itemCountLabel: String {
        totalItems == 1 ? "1 item" : "\(totalItems) items"
    }

    var mrpLabel: String { CartItem.money(totalMrp) }
    var payLabel: String { CartItem.rupees(totalCustomerPrice) }
    var savingsLabel: String { CartItem.rupees(totalSavings) }

    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case totalMrp = "total_mrp"
        case totalCustomerPrice = "total_customer_price"
        case totalSavings = "total_savings"
    }

    init(totalItems: Int, totalMrp: Double, totalCustomerPrice: Double, totalSavings: Double) {
        self.totalItems = totalItems
        self.totalMrp = totalMrp
        self.totalCustomerPrice = totalCustomerPrice
        self.totalSavings = totalSavings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalItems = container.decodeIntLeniently(forKey: .totalItems)
            ?? Int(container.decodeDoubleLeniently(forKey: .totalItems) ?? 0)
        totalMrp = container.decodeDoubleLeniently(forKey: .totalMrp) ?? 0
        totalCustomerPrice = container.decodeDoubleLeniently(forKey: .totalCustomerPrice) ?? 0
        totalSavings = container.decodeDoubleLeniently(forKey: .totalSavings) ?? 0
    }
}

struct CartResponse: Decodable {
    let status: Bool?
    let message: String?
    let items: [CartItem]
    let summary: CartSummary
    let charges: [CartCharge]
    let coupon: AppliedCouponData?
    let couponDiscount: Double
    let deliveryInfo: CartDeliveryInfo?
    let grandTotal: Double

    enum CodingKeys: String, CodingKey {
        case status, message, data, summary, charges, coupon
        case couponDiscount = "coupon_discount"
        case deliveryInfo = "delivery_info"
        case grandTotal = "grand_total"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        items = (try? container.decode([CartItem].self, forKey: .data)) ?? []
        summary = (try? container.decode(CartSummary.self, forKey: .summary)) ?? .empty
        charges = (try? container.decode([CartCharge].self, forKey: .charges)) ?? []
        coupon = try? container.decodeIfPresent(AppliedCouponData.self, forKey: .coupon)
        couponDiscount = container.decodeDoubleLeniently(forKey: .couponDiscount) ?? 0
        deliveryInfo = try? container.decodeIfPresent(CartDeliveryInfo.self, forKey: .deliveryInfo)
        grandTotal = container.decodeDoubleLeniently(forKey: .grandTotal) ?? 0
    }
}

/// `POST customer/cart/add`. Failures may arrive as HTTP 4xx or as `status: false` on 200.
struct CartAddResponse: Decodable {
    let status: Bool?
    let message: String?
    let item: CartAddItem?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        item = try? container.decode(CartAddItem.self, forKey: .data)
    }
}

struct CartAddItem: Decodable {
    let cartId: Int
    let productId: Int
    let variantId: Int
    let qty: Int
    let mrp: Double
    let customerPrice: Double
    let availableQty: Int
    let minOrderQty: Int?
    let maxOrderQty: Int?

    enum CodingKeys: String, CodingKey {
        case qty, mrp
        case cartId = "cart_id"
        case productId = "product_id"
        case variantId = "variant_id"
        case customerPrice = "customer_price"
        case availableQty = "avl_qty"
        case minOrderQty = "min_order_qty"
        case maxOrderQty = "max_order_qty"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cartId = container.decodeIntLeniently(forKey: .cartId) ?? 0
        productId = container.decodeIntLeniently(forKey: .productId) ?? 0
        variantId = container.decodeIntLeniently(forKey: .variantId) ?? 0
        qty = container.decodeIntLeniently(forKey: .qty)
            ?? Int(container.decodeDoubleLeniently(forKey: .qty) ?? 0)
        mrp = container.decodeDoubleLeniently(forKey: .mrp) ?? 0
        customerPrice = container.decodeDoubleLeniently(forKey: .customerPrice) ?? 0
        availableQty = container.decodeIntLeniently(forKey: .availableQty) ?? 0
        minOrderQty = container.decodeIntLeniently(forKey: .minOrderQty)
        maxOrderQty = container.decodeIntLeniently(forKey: .maxOrderQty)
    }
}

// MARK: - Coupon Models

struct Coupon: Decodable, Identifiable {
    let id: Int
    let code: String
    let name: String
    let description: String
    let type: String
    let discountValue: Double
    let maxDiscount: Double?
    let minOrderValue: Double
    let isFirstOrderOnly: Bool
    let endDate: String
    let isEligible: Bool
    let ineligibleReason: String?
    let discountText: String

    enum CodingKeys: String, CodingKey {
        case id, code, name, description, type
        case discountValue = "discount_value"
        case maxDiscount = "max_discount"
        case minOrderValue = "min_order_value"
        case isFirstOrderOnly = "is_first_order_only"
        case endDate = "end_date"
        case isEligible = "is_eligible"
        case ineligibleReason = "ineligible_reason"
        case discountText = "discount_text"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        code = container.decodeStringLeniently(forKey: .code) ?? ""
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        description = container.decodeStringLeniently(forKey: .description) ?? ""
        type = container.decodeStringLeniently(forKey: .type) ?? ""
        discountValue = container.decodeDoubleLeniently(forKey: .discountValue) ?? 0
        maxDiscount = container.decodeDoubleLeniently(forKey: .maxDiscount)
        minOrderValue = container.decodeDoubleLeniently(forKey: .minOrderValue) ?? 0
        isFirstOrderOnly = container.decodeBoolLeniently(forKey: .isFirstOrderOnly) ?? false
        endDate = container.decodeStringLeniently(forKey: .endDate) ?? ""
        isEligible = container.decodeBoolLeniently(forKey: .isEligible) ?? false
        ineligibleReason = container.decodeStringLeniently(forKey: .ineligibleReason)
        discountText = container.decodeStringLeniently(forKey: .discountText) ?? ""
    }
}

struct CouponsResponse: Decodable {
    let status: Bool?
    let message: String?
    let cartTotal: Double
    let coupons: [Coupon]

    enum CodingKeys: String, CodingKey {
        case status, message, data
        case cartTotal = "cart_total"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        cartTotal = container.decodeDoubleLeniently(forKey: .cartTotal) ?? 0
        coupons = (try? container.decode([Coupon].self, forKey: .data)) ?? []
    }
}

struct AppliedCouponData: Decodable, Identifiable {
    var id: Int { couponId }
    let couponId: Int
    let code: String
    let name: String
    let type: String
    let discountValue: Double
    let discountAmount: Double
    let cartTotal: Double
    let finalTotal: Double
    let discountText: String

    enum CodingKeys: String, CodingKey {
        case couponId = "coupon_id"
        case code, name, type
        case discountValue = "discount_value"
        case discountAmount = "discount_amount"
        case cartTotal = "cart_total"
        case finalTotal = "final_total"
        case discountText = "discount_text"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        couponId = container.decodeIntLeniently(forKey: .couponId) ?? 0
        code = container.decodeStringLeniently(forKey: .code) ?? ""
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        type = container.decodeStringLeniently(forKey: .type) ?? ""
        discountValue = container.decodeDoubleLeniently(forKey: .discountValue) ?? 0
        discountAmount = container.decodeDoubleLeniently(forKey: .discountAmount) ?? 0
        cartTotal = container.decodeDoubleLeniently(forKey: .cartTotal) ?? 0
        finalTotal = container.decodeDoubleLeniently(forKey: .finalTotal) ?? 0
        discountText = container.decodeStringLeniently(forKey: .discountText) ?? ""
    }

    func updating(discountAmount newAmount: Double) -> AppliedCouponData {
        AppliedCouponData(
            couponId: self.couponId,
            code: self.code,
            name: self.name,
            type: self.type,
            discountValue: self.discountValue,
            discountAmount: newAmount,
            cartTotal: self.cartTotal,
            finalTotal: self.cartTotal - newAmount,
            discountText: self.discountText
        )
    }

    init(
        couponId: Int,
        code: String,
        name: String,
        type: String,
        discountValue: Double,
        discountAmount: Double,
        cartTotal: Double,
        finalTotal: Double,
        discountText: String
    ) {
        self.couponId = couponId
        self.code = code
        self.name = name
        self.type = type
        self.discountValue = discountValue
        self.discountAmount = discountAmount
        self.cartTotal = cartTotal
        self.finalTotal = finalTotal
        self.discountText = discountText
    }
}

struct ApplyCouponResponse: Decodable {
    let status: Bool?
    let message: String?
    let data: AppliedCouponData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        data = try? container.decode(AppliedCouponData.self, forKey: .data)
    }
}

struct CouponValidateResponse: Decodable {
    let status: Bool?
    let message: String?
    let discountAmount: Double

    enum CodingKeys: String, CodingKey {
        case status, message
        case discountAmount = "discount_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        discountAmount = container.decodeDoubleLeniently(forKey: .discountAmount) ?? 0
    }
}

// MARK: - Payment Method

enum PaymentMethod: String, CaseIterable, Identifiable {
    case online = "Pay Online"
    case cod = "Cash on Delivery"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .online: return "creditcard.fill"
        case .cod: return "banknote.fill"
        }
    }

    var description: String {
        switch self {
        case .online: return "UPI, cards, net banking and wallets"
        case .cod: return "Pay the delivery partner when your order arrives"
        }
    }
}
