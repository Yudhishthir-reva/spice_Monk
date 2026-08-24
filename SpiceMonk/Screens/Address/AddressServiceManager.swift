//
//  AddressServiceManager.swift
//  SpiceMonk
//

import Foundation
import Combine

class AddressServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchAddresses() -> AnyPublisher<AddressListResponse, Error> {
        networkService.request(
            APIRouter.addressList,
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchAddress(id: Int) -> AnyPublisher<AddressDetailResponse, Error> {
        networkService.request(
            APIRouter.addressDetail(id: id),
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func setDefaultAddress(id: Int) -> AnyPublisher<StatusResponse, Error> {
        networkService.request(
            APIRouter.setDefaultAddress(id: id),
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func deleteAddress(id: Int) -> AnyPublisher<StatusResponse, Error> {
        networkService.request(
            APIRouter.deleteAddress(id: id),
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func storeAddress(params: RequestConstants.Param) -> AnyPublisher<AddressDetailResponse, Error> {
        networkService.request(
            APIRouter.storeAddress,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func lookupPincode(_ pinCode: String) -> AnyPublisher<PincodeLookupResponse, Error> {
        networkService.request(
            APIRouter.cityByPincode,
            params: ["pin_code": pinCode],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
