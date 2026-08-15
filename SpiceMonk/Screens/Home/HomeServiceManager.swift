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
}
