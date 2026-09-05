//
//  LoginServiceManager.swift
//  SpiceMonk
//

import Foundation
import Combine

class LoginServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func sendOTP(
        params: RequestConstants.Param,
        headers: RequestConstants.Header
    ) -> AnyPublisher<OTPSendModel, Error> {
        networkService.request(APIRouter.sendOTP, params: params, headers: headers)
    }

    func verifyOTP(
        params: RequestConstants.Param,
        headers: RequestConstants.Header
    ) -> AnyPublisher<OTPVerifyModel, Error> {
        networkService.request(APIRouter.verifyOTP, params: params, headers: headers)
    }

    func guestLogin() -> AnyPublisher<GuestLoginResponse, Error> {
        networkService.request(APIRouter.guestLogin, params: [String: Any](), headers: [:])
    }

    func mergeGuestCart(guestToken: String) -> AnyPublisher<StatusResponse, Error> {
        networkService.request(
            APIRouter.mergeGuestCart,
            params: ["guest_token": guestToken],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}

struct OTPSendModel: Decodable {
    var status: Bool?
    var message: String?
    /// Only present on staging, where the backend echoes the code it just sent.
    var otp: String?

    enum CodingKeys: String, CodingKey {
        case status, message, otp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        otp = container.decodeStringLeniently(forKey: .otp)
    }
}

struct OTPVerifyModel: Decodable {
    var status: Bool?
    var message: String?
    var accessToken: String?
    var refreshToken: String?
    var expiresIn: Int?
    var sellerId: String?
    var mobile: String?
    var name: String?
    var isNew: Bool?

    enum CodingKeys: String, CodingKey {
        case status, message, mobile, name
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case sellerId = "seller_id"
        case isNew = "is_new"
    }

    /// Decoded field by field rather than synthesised, because the endpoint mixes quoted and
    /// unquoted scalars — see `decodeStringLeniently`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        accessToken = container.decodeStringLeniently(forKey: .accessToken)
        refreshToken = container.decodeStringLeniently(forKey: .refreshToken)
        expiresIn = container.decodeIntLeniently(forKey: .expiresIn)
        sellerId = container.decodeStringLeniently(forKey: .sellerId)
        mobile = container.decodeStringLeniently(forKey: .mobile)
        name = container.decodeStringLeniently(forKey: .name)
        isNew = container.decodeBoolLeniently(forKey: .isNew)
    }
}

struct GuestLoginResponse: Decodable {
    let status: Bool?
    let isGuest: Bool?
    let guestToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case isGuest = "is_guest"
        case guestToken = "guest_token"
        case expiresIn = "expires_in"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        isGuest = container.decodeBoolLeniently(forKey: .isGuest)
        guestToken = container.decodeStringLeniently(forKey: .guestToken)
        expiresIn = container.decodeIntLeniently(forKey: .expiresIn)
    }
}
