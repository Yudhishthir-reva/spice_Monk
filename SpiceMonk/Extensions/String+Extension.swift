//
//  String+Extension.swift
//  SpiceMonk
//

import Foundation
import SwiftUI

extension String {
    var trim: String {
        trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    var isEmptyString: Bool {
        trim.isEmpty
    }

    var priceLabel: String {
        let trimmedString = trim
        return trimmedString.hasPrefix("₹") ? trimmedString : "₹\(trimmedString.removeZerosFromEnd(max: 2))"
    }

    func removeZerosFromEnd(min minDigitAfterDecimal: Int = 0, max maxDigitAfterDecimal: Int = 2) -> String {
        let formatter = NumberFormatter()
        let number = NSNumber(value: Double(self) ?? 0.0)
        formatter.minimumFractionDigits = minDigitAfterDecimal
        formatter.maximumFractionDigits = maxDigitAfterDecimal
        return String(formatter.string(from: number) ?? "")
    }

    func isValidIndianMobileNumber() -> Bool {
        let pattern = "^[6-9]\\d{9}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: utf16.count)

        if let match = regex?.firstMatch(in: self, options: [], range: range) {
            return match.range.length == utf16.count
        }
        return false
    }

    var hexToColor: Color {
        Color(hex: self)
    }
}

extension Date {
    var millisecondsSince1970: Int64 {
        Int64((timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds: Int) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }

    func get(_ component: Calendar.Component, calendar: Calendar = Calendar.current) -> Int {
        calendar.component(component, from: self)
    }
}
