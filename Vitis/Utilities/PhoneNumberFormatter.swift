//
//  PhoneNumberFormatter.swift
//  Pari
//
//  Lightweight helpers for normalizing numbers into E.164.
//

import Foundation

enum PhoneNumberFormatter {
    static func normalizedDigits(_ raw: String) -> String {
        raw.filter { $0.isNumber }
    }

    static func sanitizeUserInput(_ raw: String) -> String {
        var result = raw.filter { $0.isNumber || $0 == "+" || $0 == " " }
        if let plusIndex = result.firstIndex(of: "+"), plusIndex != result.startIndex {
            result.remove(at: plusIndex)
            result.insert("+", at: result.startIndex)
        }
        let duplicates = result.dropFirst().filter { $0 == "+" }.count
        if duplicates > 0 {
            result.removeAll(where: { $0 == "+" })
            result = "+" + result
        }
        return result
    }

    static func toE164(country: Country, rawInput: String) -> String? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("+") {
            let digits = normalizedDigits(String(trimmed.dropFirst()))
            let candidate = "+" + digits
            return validateE164(candidate) ? candidate : nil
        }

        var digits = normalizedDigits(trimmed)
        if digits.hasPrefix("0") && digits.count > 1 {
            digits.removeFirst()
        }

        guard digits.count >= 6 else { return nil }
        let candidate = "+\(country.callingCode)\(digits)"
        return validateE164(candidate) ? candidate : nil
    }

    static func validateE164(_ e164: String) -> Bool {
        guard e164.hasPrefix("+") else { return false }
        let digits = normalizedDigits(String(e164.dropFirst()))
        return digits.count >= 8 && digits.count <= 15
    }
}
