//
//  RequestConstant.swift
//  SpiceMonk
//

import Foundation

enum RequestConstants {
    typealias EndPoint = RouterManagable
    typealias Param = Any
    typealias Header = [String: String]
}

enum RequestContentType {
    case json
    case urlEncoded
    /// What the SpiceMonk API expects on its auth endpoints — the same encoding Postman sends
    /// for `--form` fields, so a boundary has to travel with the header.
    case multipartForm

    func headerValue(boundary: String) -> String {
        switch self {
        case .json:
            return "application/json"
        case .urlEncoded:
            return "application/x-www-form-urlencoded"
        case .multipartForm:
            return "multipart/form-data; boundary=\(boundary)"
        }
    }
}

enum RequestMethodType: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

/// Every value that differs between environments hangs off this enum, so switching is the single
/// `currentEnvironment` line in `AppConstant.swift` and nothing else has to be remembered.
enum RequestEnvironmentType {
    case stagging
    case production

    var baseURL: String {
        switch self {
        case .stagging:
            return "https://spicemonk.in/staging/api"
        case .production:
            return "https://spicemonk.in/965874/api"
        }
    }

    /// Customer-facing policies page linked from the login screen.
    var policiesURL: URL? {
        URL(string: "\(webOrigin)/SpiceMonk_B2C_Policies_and_Terms.html")
    }

    /// Origin the gateway checkout page is loaded under. It has to track the API host, because the
    /// payment keys are registered per domain — a production origin over a staging order is
    /// exactly the mismatch the gateway rejects.
    var webOrigin: String {
        switch self {
        case .stagging:
            return "https://spicemonk.trudataa.com"
        case .production:
            return "https://spicemonk.in"
        }
    }
}

enum RequestError: Error {
    case noInternet
    case serverError
    case invalidURL
    case invalidResponse
    case invalidData
    case unAuthroizedUser
    case forbidenRequest
    case invalidPayloadData
    case unknownError
    case apiMessage(String)

    var errorString: String {
        switch self {
        case .noInternet:
            return "No internet connection."
        case .serverError:
            return "Server is not working."
        case .invalidURL:
            return "Invalid URL."
        case .invalidResponse:
            return "Invalid response."
        case .invalidData:
            return "Invalid data."
        case .unAuthroizedUser:
            return "Unauthorized user."
        case .invalidPayloadData:
            return "Invalid payload."
        case .unknownError:
            return "Something went wrong."
        case .forbidenRequest:
            return "Forbidden request."
        case .apiMessage(let message):
            return message
        }
    }
}
