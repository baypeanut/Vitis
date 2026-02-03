//
//  PhoneNumberInputModel.swift
//  Vitis
//
//  Shared phone number state for entry flows.
//

import Foundation

@MainActor
@Observable
final class PhoneNumberInputModel {
    var selectedCountry: Country
    var nationalNumber: String = ""

    init(defaultCountry: Country = CountriesStore.shared.defaultCountry) {
        self.selectedCountry = defaultCountry
    }

    var e164: String? {
        PhoneNumberFormatter.toE164(country: selectedCountry, rawInput: nationalNumber)
    }

    func reset() {
        nationalNumber = ""
    }
}
