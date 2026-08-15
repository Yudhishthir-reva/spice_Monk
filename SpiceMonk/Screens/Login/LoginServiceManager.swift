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

    /// The echoed code, but only when it is a complete 6-digit OTP the boxes can actually hold.
    static func usableOTP(from otp: String?) -> String {
        let digits = otp?.filter(\.isNumber) ?? ""
        return digits.count == 6 ? digits : ""
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
