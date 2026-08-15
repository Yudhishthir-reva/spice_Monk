//
//  NetworkServiceManagable.swift
//  SpiceMonk
//

import Foundation
import Combine

protocol NetworkServiceManagable {
    func request<T: Decodable>(
        _ endpoint: RouterManagable,
        params: RequestConstants.Param,
        headers: RequestConstants.Header
    ) -> AnyPublisher<T, Error>
}
