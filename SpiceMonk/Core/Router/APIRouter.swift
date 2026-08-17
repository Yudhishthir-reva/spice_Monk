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
        }
    }

    var requestType: RequestMethodType {
        switch self {
        case .addressList, .addressDetail:
            return .get
        default:
            return .post
        }
    }
}
