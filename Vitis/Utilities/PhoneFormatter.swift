//
//  PhoneFormatter.swift
//  Vitis
//
//  Lightweight E.164 normalization. Default +1, US 10 digits. No third‑party libs.
//

import Foundation

enum PhoneFormatter {
    /// Default country code (US).
    static let defaultCountryCode = "+1"

    /// Strip non‑digits, apply +1, enforce 10 digits. Returns nil if invalid.
    static func normalizeToE164(countryCode: String = defaultCountryCode, raw: String) -> String? {
        let digits = raw.filter { $0.isNumber }
        let cc = countryCode.hasPrefix("+") ? String(countryCode.dropFirst()) : countryCode
        let ccDigits = cc.filter { $0.isNumber }
        let normalized: String
        if ccDigits == "1" {
            let ten: String
            if digits.count == 11 && digits.hasPrefix("1") {
                ten = String(digits.dropFirst())
            } else if digits.count == 10 {
                ten = digits
            } else {
                return nil
            }
            normalized = "+1" + ten
        } else {
            guard !ccDigits.isEmpty, !digits.isEmpty else { return nil }
            normalized = "+" + ccDigits + digits
        }
        return normalized
    }

    /// Format for display: (XXX) XXX‑XXXX for +1 US.
    static func displayString(e164: String) -> String {
        let d = e164.filter { $0.isNumber }
        if d.hasPrefix("1") && d.count == 11 {
            let rest = String(d.dropFirst())
            return "(\(rest.prefix(3))) \(rest.dropFirst(3).prefix(3))-\(rest.dropFirst(6))"
        }
        if d.count == 10 {
            return "(\(d.prefix(3))) \(d.dropFirst(3).prefix(3))-\(d.dropFirst(6))"
        }
        return e164
    }
}
