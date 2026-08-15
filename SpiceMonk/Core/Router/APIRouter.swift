//
//  APIRouter.swift
//  SpiceMonk
//

enum APIRouter: RouterManagable {

    case sendOTP
    case verifyOTP
    case refreshToken

    var endPointUrl: String {
        switch self {
        case .sendOTP:
            return "customer/auth/send-otp"
        case .verifyOTP:
            return "customer/auth/verify-otp"
        case .refreshToken:
            return "customer/auth/refresh-token"
        }
    }
}
