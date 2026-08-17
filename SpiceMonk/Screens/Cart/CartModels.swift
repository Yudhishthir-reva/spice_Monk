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
    let qty: Int
    let mrp: Double
    let customerPrice: Double
    let saveAmount: Double
    let discountPercent: Double
    let subtotal: Double
    let availableQty: Int

    var id: Int { cartId > 0 ? cartId : productId * 10_000 + variantId }

    var inStock: Bool { availableQty > 0 }

    var hasDiscount: Bool { customerPrice < mrp && mrp > 0 }

    /// Same truncation as home cards.
    var discountPercentTruncated: Int { Int(discountPercent) }

    var unitPriceLabel: String { Self.money(customerPrice) }
    var mrpLabel: String { Self.money(mrp) }
    var subtotalLabel: String { Self.money(subtotal) }

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
    }

    static func money(_ value: Double) -> String {
        String(value).priceLabel
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
    var payLabel: String { CartItem.money(totalCustomerPrice) }
    var savingsLabel: String { CartItem.money(totalSavings) }

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

    enum CodingKeys: String, CodingKey {
        case status, message, data, summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        items = (try? container.decode([CartItem].self, forKey: .data)) ?? []
        summary = (try? container.decode(CartSummary.self, forKey: .summary)) ?? .empty
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

    enum CodingKeys: String, CodingKey {
        case qty, mrp
        case cartId = "cart_id"
        case productId = "product_id"
        case variantId = "variant_id"
        case customerPrice = "customer_price"
        case availableQty = "avl_qty"
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
    }
}
