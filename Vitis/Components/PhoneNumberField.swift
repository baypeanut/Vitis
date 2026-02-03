//
//  PhoneNumberField.swift
//  Vitis
//
//  Reusable phone input with country picker and helper text.
//

import SwiftUI

struct PhoneNumberField: View {
    @Binding var selectedCountry: Country
    @Binding var nationalNumber: String

    var label: String?
    var placeholder: String = "555 123 4567"
    var helperText: String?

    @State private var showCountryPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let label {
                Text(label)
                    .font(VitisTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            }

            Button {
                showCountryPicker = true
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Text(selectedCountry.flagEmoji)
                        Text("\(selectedCountry.name) (\(selectedCountry.displayCallingCode))")
                    }
                    .font(VitisTheme.uiFont(size: 16))
                    .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView(selectedCountry: $selectedCountry)
            }

            TextField(placeholder, text: sanitizedBinding)
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .font(VitisTheme.uiFont(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let helperText {
                Text(helperText)
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
        }
    }

    private var sanitizedBinding: Binding<String> {
        Binding(
            get: { nationalNumber },
            set: { newValue in
                nationalNumber = PhoneNumberFormatter.sanitizeUserInput(newValue)
            }
        )
    }
}

private struct CountryPickerView: View {
    @Binding var selectedCountry: Country
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var store: CountriesStore { .shared }

    private var filteredPinned: [Country] {
        filter(countries: store.pinnedCountries)
    }

    private var filteredCountries: [Country] {
        filter(countries: store.countries)
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredPinned.isEmpty {
                    Section("Suggested") {
                        ForEach(filteredPinned) { country in
                            row(for: country)
                        }
                    }
                }
                Section("All countries") {
                    ForEach(filteredCountries) { country in
                        row(for: country)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select country")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        }
    }

    private func row(for country: Country) -> some View {
        Button {
            selectedCountry = country
            dismiss()
        } label: {
            HStack {
                Text(country.flagEmoji)
                    .frame(width: 32)
                VStack(alignment: .leading) {
                    Text(country.name)
                        .foregroundStyle(.primary)
                    Text(country.isoCode)
                        .font(VitisTheme.uiFont(size: 12))
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                Spacer()
                Text(country.displayCallingCode)
                    .foregroundStyle(VitisTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    private func filter(countries: [Country]) -> [Country] {
        guard !searchText.isEmpty else { return countries }
        let query = searchText.lowercased()
        let digitsQuery = query.filter { $0.isNumber }
        return countries.filter { country in
            country.name.lowercased().contains(query)
                || country.isoCode.lowercased().contains(query)
                || (!digitsQuery.isEmpty && country.callingCode.contains(digitsQuery))
        }
    }
}
