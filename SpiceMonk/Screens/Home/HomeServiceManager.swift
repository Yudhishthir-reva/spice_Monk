//
//  HomeServiceManager.swift
//  SpiceMonk
//

import Foundation
import Combine

class HomeServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchHome() -> AnyPublisher<HomeResponse, Error> {
        networkService.request(
            APIRouter.home,
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
