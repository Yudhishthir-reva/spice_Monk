//
//  OrderModels.swift
//  SpiceMonk
//

import Foundation

struct OrderStatus: Decodable {
    let code: Int
    let label: String
    let color: String
}

struct OrderTimelineStep: Decodable, Identifiable {
    let label: String
    let date: String?
    let completed: Bool

    var id: String { label }
}

struct OrderExpectedDate: Decodable {
    let label: String
    let date: String
}

struct OrderItem: Decodable, Identifiable {
    let id: Int
    let orderNo: String
    let date: String
    let totalAmount: Double
    let paymentType: String
    let paymentLabel: String
    let itemsCount: Int
    let productImages: [String]
    let status: OrderStatus
    let timeline: [OrderTimelineStep]
    let expectedDate: OrderExpectedDate
    let canTrack: Bool
    let canRepeat: Bool

    enum CodingKeys: String, CodingKey {
        case id, date, status, timeline
        case orderNo = "order_no"
        case totalAmount = "total_amount"
        case paymentType = "payment_type"
        case paymentLabel = "payment_label"
        case itemsCount = "items_count"
        case productImages = "product_images"
        case expectedDate = "expected_date"
        case canTrack = "can_track"
        case canRepeat = "can_repeat"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        totalAmount = container.decodeDoubleLeniently(forKey: .totalAmount) ?? 0
        paymentType = container.decodeStringLeniently(forKey: .paymentType) ?? ""
        paymentLabel = container.decodeStringLeniently(forKey: .paymentLabel) ?? ""
        itemsCount = container.decodeIntLeniently(forKey: .itemsCount) ?? 0
        productImages = (try? container.decode([String].self, forKey: .productImages)) ?? []
        status = try container.decode(OrderStatus.self, forKey: .status)
        timeline = (try? container.decode([OrderTimelineStep].self, forKey: .timeline)) ?? []
        expectedDate = try container.decode(OrderExpectedDate.self, forKey: .expectedDate)
        canTrack = container.decodeBoolLeniently(forKey: .canTrack) ?? false
        canRepeat = container.decodeBoolLeniently(forKey: .canRepeat) ?? false
    }

    var totalAmountLabel: String {
        "₹\(Int(totalAmount.rounded()))"
    }
}

struct OrdersResponse: Decodable {
    let status: Bool?
    let message: String?
    let orders: [OrderItem]
    let pagination: PageInfo

    enum CodingKeys: String, CodingKey {
        case status, message, data, pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        orders = (try? container.decode([OrderItem].self, forKey: .data)) ?? []
        pagination = (try? container.decode(PageInfo.self, forKey: .pagination)) ?? .empty
    }
}

// MARK: - Order Detail Models

struct OrderDetailAddress: Decodable {
    let fullName: String
    let mobile: String
    let address: String

    enum CodingKeys: String, CodingKey {
        case address
        case fullName = "full_name"
        case mobile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fullName = container.decodeStringLeniently(forKey: .fullName) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        address = container.decodeStringLeniently(forKey: .address) ?? ""
    }
}

struct OrderDetailItem: Decodable, Identifiable {
    let productId: Int
    let productName: String
    let productImage: String?
    let variantId: Int
    let weight: String
    let mrp: Double
    let customerPrice: Double
    let saveAmount: Double
    let discountPercent: Double
    let qty: Int
    let price: Double

    var id: String { "\(productId)-\(variantId)" }

    enum CodingKeys: String, CodingKey {
        case weight, mrp, qty, price
        case productId = "product_id"
        case productName = "product_name"
        case productImage = "product_image"
        case variantId = "variant_id"
        case customerPrice = "customer_price"
        case saveAmount = "save_amount"
        case discountPercent = "discount_percent"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productId = container.decodeIntLeniently(forKey: .productId) ?? 0
        productName = container.decodeStringLeniently(forKey: .productName) ?? ""
        productImage = container.decodeStringLeniently(forKey: .productImage)
        variantId = container.decodeIntLeniently(forKey: .variantId) ?? 0
        weight = container.decodeStringLeniently(forKey: .weight) ?? ""
        mrp = container.decodeDoubleLeniently(forKey: .mrp) ?? 0
        customerPrice = container.decodeDoubleLeniently(forKey: .customerPrice) ?? 0
        saveAmount = container.decodeDoubleLeniently(forKey: .saveAmount) ?? 0
        discountPercent = container.decodeDoubleLeniently(forKey: .discountPercent) ?? 0
        qty = container.decodeIntLeniently(forKey: .qty) ?? 1
        price = container.decodeDoubleLeniently(forKey: .price) ?? 0
    }
}

struct OrderDetail: Decodable, Identifiable {
    let id: Int
    let orderNo: String
    let date: String
    let status: String
    let statusCode: Int
    let paymentType: String
    let paymentStatus: String
    let totalMrp: Double
    let itemsTotal: Double
    let totalSave: Double
    let deliveryCharge: Double
    let handlingCharge: Double
    let packingCharge: Double
    let couponCode: String?
    let couponDiscount: Double
    let totalAmount: Double
    let notes: String?
    let items: [OrderDetailItem]
    let deliveryAddress: OrderDetailAddress

    enum CodingKeys: String, CodingKey {
        case id, date, status, notes, items
        case orderNo = "order_no"
        case statusCode = "status_code"
        case paymentType = "payment_type"
        case paymentStatus = "payment_status"
        case totalMrp = "total_mrp"
        case itemsTotal = "items_total"
        case totalSave = "total_save"
        case deliveryCharge = "delivery_charge"
        case handlingCharge = "handling_charge"
        case packingCharge = "packing_charge"
        case couponCode = "coupon_code"
        case couponDiscount = "coupon_discount"
        case totalAmount = "total_amount"
        case deliveryAddress = "delivery_address"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        statusCode = container.decodeIntLeniently(forKey: .statusCode) ?? 0
        paymentType = container.decodeStringLeniently(forKey: .paymentType) ?? ""
        paymentStatus = container.decodeStringLeniently(forKey: .paymentStatus) ?? ""
        totalMrp = container.decodeDoubleLeniently(forKey: .totalMrp) ?? 0
        itemsTotal = container.decodeDoubleLeniently(forKey: .itemsTotal) ?? 0
        totalSave = container.decodeDoubleLeniently(forKey: .totalSave) ?? 0
        deliveryCharge = container.decodeDoubleLeniently(forKey: .deliveryCharge) ?? 0
        handlingCharge = container.decodeDoubleLeniently(forKey: .handlingCharge) ?? 0
        packingCharge = container.decodeDoubleLeniently(forKey: .packingCharge) ?? 0
        couponCode = container.decodeStringLeniently(forKey: .couponCode)
        couponDiscount = container.decodeDoubleLeniently(forKey: .couponDiscount) ?? 0
        totalAmount = container.decodeDoubleLeniently(forKey: .totalAmount) ?? 0
        notes = container.decodeStringLeniently(forKey: .notes)
        items = (try? container.decode([OrderDetailItem].self, forKey: .items)) ?? []
        deliveryAddress = try container.decode(OrderDetailAddress.self, forKey: .deliveryAddress)
    }
}

struct OrderDetailResponse: Decodable {
    let status: Bool?
    let message: String?
    let order: OrderDetail?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        order = try? container.decode(OrderDetail.self, forKey: .data)
    }
}

// MARK: - Order Placement Models

struct OrderPlaceData: Decodable, Identifiable, Equatable {
    var id: Int { orderId }
    let orderId: Int
    let orderNo: String
    let paymentType: String
    let itemsTotal: Double
    let deliveryCharge: Double
    let handlingCharge: Double
    let packingCharge: Double
    let couponDiscount: Double
    let grandTotal: Double

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderNo = "order_no"
        case paymentType = "payment_type"
        case itemsTotal = "items_total"
        case deliveryCharge = "delivery_charge"
        case handlingCharge = "handling_charge"
        case packingCharge = "packing_charge"
        case couponDiscount = "coupon_discount"
        case grandTotal = "grand_total"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        paymentType = container.decodeStringLeniently(forKey: .paymentType) ?? ""
        itemsTotal = container.decodeDoubleLeniently(forKey: .itemsTotal) ?? 0
        deliveryCharge = container.decodeDoubleLeniently(forKey: .deliveryCharge) ?? 0
        handlingCharge = container.decodeDoubleLeniently(forKey: .handlingCharge) ?? 0
        packingCharge = container.decodeDoubleLeniently(forKey: .packingCharge) ?? 0
        couponDiscount = container.decodeDoubleLeniently(forKey: .couponDiscount) ?? 0
        grandTotal = container.decodeDoubleLeniently(forKey: .grandTotal) ?? 0
    }
}

struct OrderPlaceResponse: Decodable {
    let status: Bool?
    let message: String?
    let data: OrderPlaceData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        data = try? container.decode(OrderPlaceData.self, forKey: .data)
    }
}

// MARK: - Cashfree Payment Models

struct PaymentInitiateData: Decodable, Identifiable {
    var id: Int { orderId }
    let orderId: Int
    let cfOrderId: String
    let paymentSessionId: String
    let orderAmount: Double
    let environment: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case cfOrderId = "cf_order_id"
        case paymentSessionId = "payment_session_id"
        case orderAmount = "order_amount"
        case environment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        cfOrderId = container.decodeStringLeniently(forKey: .cfOrderId) ?? ""
        paymentSessionId = container.decodeStringLeniently(forKey: .paymentSessionId) ?? ""
        orderAmount = container.decodeDoubleLeniently(forKey: .orderAmount) ?? 0
        environment = container.decodeStringLeniently(forKey: .environment) ?? ""
    }
}

struct PaymentInitiateResponse: Decodable {
    let status: Bool?
    let message: String?
    let data: PaymentInitiateData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        data = try? container.decode(PaymentInitiateData.self, forKey: .data)
    }
}

struct PaymentVerifyData: Decodable {
    let orderId: Int
    let paymentStatus: String
    let isPaid: Bool
    let orderAmount: Double

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case paymentStatus = "payment_status"
        case isPaid = "is_paid"
        case orderAmount = "order_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        paymentStatus = container.decodeStringLeniently(forKey: .paymentStatus) ?? ""
        isPaid = container.decodeBoolLeniently(forKey: .isPaid) ?? false
        orderAmount = container.decodeDoubleLeniently(forKey: .orderAmount) ?? 0
    }
}

struct PaymentVerifyResponse: Decodable {
    let status: Bool?
    let message: String?
    let data: PaymentVerifyData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        data = try? container.decode(PaymentVerifyData.self, forKey: .data)
    }
}
