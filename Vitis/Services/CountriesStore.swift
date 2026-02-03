//
//  CountriesStore.swift
//  Vitis
//
//  Loads country metadata used for phone number entry.
//

import Foundation

struct Country: Codable, Identifiable, Hashable {
    let isoCode: String
    let name: String
    let callingCode: String

    var id: String { isoCode }

    var displayCallingCode: String {
        "+\(callingCode)"
    }

    var flagEmoji: String {
        let base: UInt32 = 0x1F1E6
        var scalarView = String.UnicodeScalarView()
        for scalar in isoCode.uppercased().unicodeScalars {
            guard let offset = scalar.value.asciiOffset,
                  let flagScalar = UnicodeScalar(base + offset) else { continue }
            scalarView.append(flagScalar)
        }
        return String(scalarView)
    }
}

private extension UInt32 {
    var asciiOffset: UInt32? {
        guard self >= 65, self <= 90 else { return nil }
        return self - 65
    }
}

final class CountriesStore {
    static let shared = CountriesStore()

    let countries: [Country]
    let pinnedCountries: [Country]
    let defaultCountry: Country

    private init() {
        let decoded = CountriesStore.loadCountries()
        let allCountries = decoded.sorted { $0.name < $1.name }

        let pinnedCodes = ["US", "GB", "TR", "DE", "FR", "NL", "CA", "AU"]
        let pinned = pinnedCodes.compactMap { code in
            allCountries.first(where: { $0.isoCode == code })
        }

        let localeRegion: String?
        if #available(iOS 16.0, *) {
            localeRegion = Locale.current.region?.identifier
        } else {
            localeRegion = Locale.current.regionCode
        }

        if
            let regionCode = localeRegion?.uppercased(),
            let match = allCountries.first(where: { $0.isoCode == regionCode })
        {
            self.defaultCountry = match
        } else if let us = allCountries.first(where: { $0.isoCode == "US" }) {
            self.defaultCountry = us
        } else if let first = allCountries.first {
            self.defaultCountry = first
        } else {
            self.defaultCountry = Country(isoCode: "US", name: "United States", callingCode: "1")
        }

        countries = allCountries
        pinnedCountries = pinned
    }

    private static func loadCountries() -> [Country] {
        guard
            let url = Bundle.main.url(forResource: "Countries", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([Country].self, from: data)
        else {
            return [Country(isoCode: "US", name: "United States", callingCode: "1")]
        }
        return decoded
    }
}
