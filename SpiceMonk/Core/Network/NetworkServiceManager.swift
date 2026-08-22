//
//  NetworkServiceManager.swift
//  SpiceMonk
//

import Foundation
import Combine

class NetworkServiceManager: NetworkServiceManagable {

    static let shared = NetworkServiceManager()

    private init() {}

    func request<T: Decodable>(
        _ endpoint: RouterManagable,
        params: RequestConstants.Param,
        headers: RequestConstants.Header
    ) -> AnyPublisher<T, Error> {
        guard NetworkMonitor.shared.isConnected else {
            return Fail(error: RequestError.noInternet)
                .eraseToAnyPublisher()
        }

        guard let url = URL(string: endpoint.urlString) else {
            return Fail(error: RequestError.invalidURL)
                .eraseToAnyPublisher()
        }

        var targetURL = url
        let isGet = endpoint.requestType == .get
        let rawFields = Self.fields(from: params)
        let hasParams = !rawFields.isEmpty

        if isGet && hasParams {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var queryItems = components.queryItems ?? []
                for field in rawFields {
                    queryItems.append(URLQueryItem(name: field.key, value: field.value))
                }
                components.queryItems = queryItems
                if let combinedURL = components.url {
                    targetURL = combinedURL
                }
            }
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: targetURL)
        request.httpMethod = endpoint.requestType.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Endpoints like `customer/home` are POSTs that take nothing but the auth header. Sending a
        // Content-Type with an empty form body would describe a payload that is not there.
        let hasPayload = !isGet && hasParams
        if hasPayload {
            request.setValue(
                endpoint.contentType.headerValue(boundary: boundary),
                forHTTPHeaderField: "Content-Type"
            )
        }

        #if DEBUG
        print("===================================================================")
        print("API:\n", targetURL)
        print("===================================================================")
        print("Parameter:\n", params)
        print("===================================================================")
        print("Header:\n", headers)
        print("===================================================================")
        #endif

        if hasPayload {
            switch endpoint.contentType {
            case .json:
                do {
                    request.httpBody = try JSONSerialization.data(
                        withJSONObject: params,
                        options: .fragmentsAllowed
                    )
                } catch {
                    return Fail(error: error)
                        .eraseToAnyPublisher()
                }
            case .urlEncoded:
                request.httpBody = Self.urlEncodedBody(from: params)
            case .multipartForm:
                request.httpBody = Self.multipartBody(from: params, boundary: boundary)
            }
        }

        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        return URLSession.shared.dataTaskPublisher(for: request)
            .subscribe(on: DispatchQueue.global(qos: .background))
            .mapError { error -> Error in
                if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                    return RequestError.noInternet
                }
                return error
            }
            .tryMap { data, response -> Data in
                #if DEBUG
                print(response)
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    print("==================================================================")
                    print("Response:\n", json)
                    print("==================================================================")
                } catch {
                    print(error)
                }
                #endif

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw RequestError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return data
                default:
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String, !message.isEmpty {
                        throw RequestError.apiMessage(message)
                    }
                    throw RequestError.unknownError
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    /// `multipart/form-data` body of plain text fields — the wire format Postman produces for
    /// `--form mobile=…`, which is what the SpiceMonk auth endpoints parse.
    private static func multipartBody(from params: RequestConstants.Param, boundary: String) -> Data {
        var body = Data()

        for (key, value) in fields(from: params) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))

        return body
    }

    private static func urlEncodedBody(from params: RequestConstants.Param) -> Data {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let pairs = fields(from: params).map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }

    /// Form encodings only carry text, so values are flattened to strings up front. Sorted so a
    /// given payload always produces an identical body, which keeps logs and tests comparable.
    private static func fields(from params: RequestConstants.Param) -> [(key: String, value: String)] {
        guard let dictionary = params as? [String: Any] else { return [] }
        return dictionary
            .map { (key: $0.key, value: String(describing: $0.value)) }
            .sorted { $0.key < $1.key }
    }
}
