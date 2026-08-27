//
//  AddressModels.swift
//  SpiceMonk
//

import Foundation

/// A place on an address. The backend has sent these two ways — nested as `{"id":2,"name":"Mumbai"}`
/// from the write endpoints, and as a bare `"Mumbai"` from the list — so both are accepted rather
/// than pinning the model to whichever shape was seen last.
struct PlaceReference: Decodable {
    /// Absent when the backend sent only a name, so callers that need the id must look it up.
    let id: Int?
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let name = try? single.decode(String.self) {
            self.id = nil
            self.name = name
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id)
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
    let state: PlaceReference?
    /// The list calls this `district` while the write endpoints nest it under `city`; both land here.
    let city: PlaceReference?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id, area, landmark, state, city, district, mobile, latitude, longitude
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
        state = try? container.decodeIfPresent(PlaceReference.self, forKey: .state)
        city = (try? container.decodeIfPresent(PlaceReference.self, forKey: .district))
            ?? (try? container.decodeIfPresent(PlaceReference.self, forKey: .city))
        latitude = container.decodeDoubleLeniently(forKey: .latitude)
        longitude = container.decodeDoubleLeniently(forKey: .longitude)
    }

    var cityName: String? {
        city?.name.isEmptyString == false ? city?.name : nil
    }

    var stateName: String? {
        state?.name.isEmptyString == false ? state?.name : nil
    }

    /// One-line form for the home header, where only a truncated glance fits. Any component the
    /// backend left blank is skipped so the line never shows stray commas.
    var shortLine: String {
        [houseFlatNo, area]
            .filter { !$0.isEmptyString }
            .joined(separator: ", ")
    }

    /// Cart address card: `house, area, district - pin`, matching Android.
    var cartDeliveryLine: String {
        var parts = [houseFlatNo, area]
        if let city = cityName, !city.isEmptyString {
            parts.append(city)
        }
        let place = parts.filter { !$0.isEmptyString }.joined(separator: ", ")
        if pinCode.isEmptyString { return place }
        return place.isEmpty ? pinCode : "\(place) - \(pinCode)"
    }

    var cartStickyLine: String {
        var parts = [area]
        if let city = cityName, !city.isEmptyString {
            parts.append(city)
        }
        return parts.filter { !$0.isEmptyString }.joined(separator: ", ")
    }

    /// The full postal form, for lists where the user is picking between saved addresses.
    var fullLine: String {
        let cityAndPin = [cityName, pinCode.isEmptyString ? nil : pinCode]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")

        return [houseFlatNo, area, landmark, cityAndPin, stateName]
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

/// Fills in the state and district for a PIN so the customer does not have to type them. Saving takes
/// these as plain names, so no ids are needed. The backend has spelled the pair several ways while the
/// address API changed, and each spelling is accepted rather than betting on one.
struct PincodeLocation: Decodable {
    let pinCode: String?
    let state: String
    let district: String
    let areas: [String]

    enum CodingKeys: String, CodingKey {
        case state, district, city, areas
        case pinCode = "pin_code"
        case stateName = "state_name"
        case districtName = "district_name"
        case cityName = "city_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pinCode = container.decodeStringLeniently(forKey: .pinCode)
        state = container.decodeStringLeniently(forKey: .state)
            ?? container.decodeStringLeniently(forKey: .stateName)
            ?? ""
        district = container.decodeStringLeniently(forKey: .district)
            ?? container.decodeStringLeniently(forKey: .districtName)
            ?? container.decodeStringLeniently(forKey: .cityName)
            ?? container.decodeStringLeniently(forKey: .city)
            ?? ""
        let rawAreas = (try? container.decodeIfPresent([String].self, forKey: .areas)) ?? []
        areas = rawAreas.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var isUsable: Bool {
        !state.isEmptyString && !district.isEmptyString
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

/// Shape shared by the write endpoints (`/{id}/default`, `delete`), whose `data` is an empty object.
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
