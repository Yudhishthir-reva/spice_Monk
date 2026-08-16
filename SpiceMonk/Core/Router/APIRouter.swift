//
//  APIRouter.swift
//  SpiceMonk
//

enum APIRouter: RouterManagable {

    case sendOTP
    case verifyOTP
    case refreshToken
    case home
    case addressList
    case setDefaultAddress
    case storeAddress
    case cityByPincode

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
            return "customer/address/list"
        case .setDefaultAddress:
            return "customer/address/set-default"
        case .storeAddress:
            return "customer/address/store"
        case .cityByPincode:
            return "customer/address/by-pincode"
        }
    }
}
