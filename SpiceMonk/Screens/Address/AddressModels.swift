//
//  AddressModels.swift
//  SpiceMonk
//

import Foundation

/// The `state` and `city` objects nested in an address — both are just an id and a display name.
struct NamedReference: Decodable, Identifiable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }
}

struct Address: Decodable, Identifiable {
    let id: Int
    let fullName: String
    let mobile: String
    let alternateMobile: String?
    let pinCode: String
    let area: String
    let houseFlatNo: String
    let landmark: String?
    /// Mutable so the picker can reflect a tap immediately, before the server confirms the change.
    var isDefault: Bool
    let state: NamedReference?
    let city: NamedReference?

    enum CodingKeys: String, CodingKey {
        case id, area, landmark, state, city, mobile
        case fullName = "full_name"
        case alternateMobile = "alternate_mobile"
        case pinCode = "pin_code"
        case houseFlatNo = "house_flat_no"
        case isDefault = "is_default"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        fullName = container.decodeStringLeniently(forKey: .fullName) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        alternateMobile = container.decodeStringLeniently(forKey: .alternateMobile)
        pinCode = container.decodeStringLeniently(forKey: .pinCode) ?? ""
        area = container.decodeStringLeniently(forKey: .area) ?? ""
        houseFlatNo = container.decodeStringLeniently(forKey: .houseFlatNo) ?? ""
        landmark = container.decodeStringLeniently(forKey: .landmark)
        isDefault = container.decodeBoolLeniently(forKey: .isDefault) ?? false
        state = try? container.decodeIfPresent(NamedReference.self, forKey: .state)
        city = try? container.decodeIfPresent(NamedReference.self, forKey: .city)
    }

    /// One-line form for the home header, where only a truncated glance fits. Any component the
    /// backend left blank is skipped so the line never shows stray commas.
    var shortLine: String {
        [houseFlatNo, area]
            .filter { !$0.isEmptyString }
            .joined(separator: ", ")
    }

    /// The full postal form, for lists where the user is picking between saved addresses.
    var fullLine: String {
        let cityAndPin = [city?.name, pinCode.isEmptyString ? nil : pinCode]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")

        return [houseFlatNo, area, landmark, cityAndPin, state?.name]
            .compactMap { $0 }
            .filter { !$0.isEmptyString }
            .joined(separator: ", ")
    }
}

struct AddressListResponse: Decodable {
    let status: Bool?
    let message: String?
    let addresses: [Address]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        addresses = (try? container.decode([Address].self, forKey: .data)) ?? []
    }
}

/// `store`, `update` and `show` all return the single affected address under `data`.
struct AddressDetailResponse: Decodable {
    let status: Bool?
    let message: String?
    let address: Address?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        address = try? container.decodeIfPresent(Address.self, forKey: .data)
    }
}

/// `by-pincode` is the only way to obtain the `state_id` and `city_id` that saving an address
/// requires — there is no endpoint listing states or cities — so the form is built around it.
struct PincodeLocation: Decodable {
    let cityId: Int
    let cityName: String
    let stateId: Int
    let stateName: String

    enum CodingKeys: String, CodingKey {
        case cityId = "city_id"
        case cityName = "city_name"
        case stateId = "state_id"
        case stateName = "state_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cityId = container.decodeIntLeniently(forKey: .cityId) ?? 0
        cityName = container.decodeStringLeniently(forKey: .cityName) ?? ""
        stateId = container.decodeIntLeniently(forKey: .stateId) ?? 0
        stateName = container.decodeStringLeniently(forKey: .stateName) ?? ""
    }
}

struct PincodeLookupResponse: Decodable {
    let status: Bool?
    let message: String?
    let location: PincodeLocation?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        location = try? container.decodeIfPresent(PincodeLocation.self, forKey: .data)
    }
}

/// Shape shared by the write endpoints (`set-default`, `delete`), whose `data` is an empty object.
struct StatusResponse: Decodable {
    let status: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
    }
}
