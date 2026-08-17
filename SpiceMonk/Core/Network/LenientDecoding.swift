//
//  LenientDecoding.swift
//  SpiceMonk
//

import Foundation

extension KeyedDecodingContainer {

    /// Reads a text field the API is inconsistent about quoting: `verify-otp` returns `mobile` as a
    /// bare number while `seller_id` beside it is quoted. `JSONDecoder` is strict, so asking for
    /// `String` there fails the *entire* response and a valid login looks like a server error.
    /// Android's decoder runs with `isLenient`, which is why the same payload works there.
    func decodeStringLeniently(forKey key: Key) -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let integer = try? decodeIfPresent(Int64.self, forKey: key) {
            return String(integer)
        }
        if let number = try? decodeIfPresent(Double.self, forKey: key) {
            return number.formatted(.number.grouping(.never))
        }
        return nil
    }

    /// Same tolerance for whole numbers, which arrive quoted on some endpoints.
    func decodeIntLeniently(forKey key: Key) -> Int? {
        if let integer = try? decodeIfPresent(Int.self, forKey: key) {
            return integer
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Int(string)
        }
        return nil
    }

    func decodeBoolLeniently(forKey key: Key) -> Bool? {
        if let bool = try? decodeIfPresent(Bool.self, forKey: key) {
            return bool
        }
        if let integer = try? decodeIfPresent(Int.self, forKey: key) {
            return integer != 0
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return ["1", "true", "yes"].contains(string.lowercased())
        }
        return nil
    }

    func decodeDoubleLeniently(forKey key: Key) -> Double? {
        if let number = try? decodeIfPresent(Double.self, forKey: key) {
            return number
        }
        if let integer = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(integer)
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Double(string)
        }
        return nil
    }
}
