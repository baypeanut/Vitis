//
//  PhoneNumberInputModel.swift
//  Pari
//
//  Shared phone number state for entry flows.
//

import Foundation

@MainActor
@Observable
final class PhoneNumberInputModel {
    var selectedCountry: Country
    var nationalNumber: String = ""

    init(defaultCountry: Country? = nil) {
        self.selectedCountry = defaultCountry ?? CountriesStore.shared.defaultCountry
    }

    var e164: String? {
        PhoneNumberFormatter.toE164(country: selectedCountry, rawInput: nationalNumber)
    }

    func reset() {
        nationalNumber = ""
    }
}
