//
//  APIRouter.swift
//  SpiceMonk
//

enum APIRouter: RouterManagable {

    case sendOTP
    case verifyOTP
    case refreshToken
    case home
    /// Shares its path with `storeAddress`; the two differ only by HTTP method.
    case addressList
    case addressDetail(id: Int)
    case setDefaultAddress(id: Int)
    case storeAddress
    case cityByPincode
    case widgetProducts
    case categoryProducts
    case brandProducts
    case bannerProducts
    case productDetail
    case relatedProducts
    case productSuggestions
    case productSearch
    case cart
    case cartAdd
    case cartRemove
    case cartClear
    case cartUpdate
    case coupons
    case couponApply
    case couponValidate
    case orders
    case orderDetail(id: Int)
    case orderCancel
    case orderPlace
    case paymentInitiate
    case paymentVerify

    var endPointUrl: String {
        switch self {
        case .sendOTP:
            return "customer/auth/send-otp"
        case .verifyOTP:
            return "customer/auth/verify-otp"
        case .refreshToken:
            return "customer/auth/refresh-token"
        case .home:
            return "customer/home"
        case .addressList:
            return "customer/address"
        case .addressDetail(let id):
            return "customer/address/\(id)"
        case .setDefaultAddress(let id):
            return "customer/address/\(id)/default"
        case .storeAddress:
            return "customer/address"
        case .cityByPincode:
            return "customer/address/by-pincode"
        case .widgetProducts:
            return "customer/widget/products"
        case .categoryProducts:
            return "customer/category/products"
        case .brandProducts:
            return "customer/brand/products"
        case .bannerProducts:
            return "customer/banner/products"
        case .productDetail:
            return "customer/product/detail"
        case .relatedProducts:
            return "customer/product/related"
        case .productSuggestions:
            return "customer/product/suggestions"
        case .productSearch:
            return "customer/product/search"
        case .cart:
            return "customer/cart"
        case .cartAdd:
            return "customer/cart/add"
        case .cartRemove:
            return "customer/cart/remove"
        case .cartClear:
            return "customer/cart/clear"
        case .cartUpdate:
            return "customer/cart/update"
        case .coupons:
            return "customer/coupons"
        case .couponApply:
            return "customer/coupon/apply"
        case .couponValidate:
            return "customer/coupon/validate"
        case .orders:
            return "customer/orders"
        case .orderDetail(let id):
            return "customer/orders/\(id)"
        case .orderCancel:
            return "customer/order/cancel"
        case .orderPlace:
            return "customer/order/place"
        case .paymentInitiate:
            return "customer/payment/initiate"
        case .paymentVerify:
            return "customer/payment/verify"
        }
    }

    var requestType: RequestMethodType {
        switch self {
        case .addressList, .addressDetail, .cart, .coupons, .orders, .orderDetail:
            return .get
        case .cartClear:
            return .delete
        default:
            return .post
        }
    }
}
