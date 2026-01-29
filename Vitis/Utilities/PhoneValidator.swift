//
//  PhoneValidator.swift
//  Vitis
//
//  Validate phone for onboarding. +1 → 10 digits; E.164 normalized.
//

import Foundation

enum PhoneValidator {
    /// Valid if normalizeToE164 returns non‑nil. US +1: exactly 10 digits.
    static func isValid(countryCode: String = PhoneFormatter.defaultCountryCode, raw: String) -> Bool {
        PhoneFormatter.normalizeToE164(countryCode: countryCode, raw: raw) != nil
    }
}
