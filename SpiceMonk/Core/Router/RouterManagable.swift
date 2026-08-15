//
//  RouterManagable.swift
//  SpiceMonk
//

import Foundation

protocol RouterManagable {
    var endPointUrl: String { get }
    var requestType: RequestMethodType { get }
    var urlString: String { get }
    var contentType: RequestContentType { get }
    var baseURL: String { get }
}

extension RouterManagable {

    var baseURL: String {
        switch currentEnvironment {
        case .stagging:
            return "https://spicemonk.revateam.com/api"
        case .production:
            return "https://spicemonk.revateam.com/api"
        }
    }

    var urlString: String {
        "\(baseURL)/\(endPointUrl)"
    }

    var requestType: RequestMethodType {
        .post
    }

    var contentType: RequestContentType {
        .multipartForm
    }
}
