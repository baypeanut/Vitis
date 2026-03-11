//
//  AppearanceSettingsView.swift
//  Pari
//
//  Appearance: System, Light, Dark. Stored in AppStorage, applied at root.
//

import SwiftUI

enum AppearanceOption: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

enum AppearanceStorage {
    private static let key = "appearance_preference"

    @AppStorage(key) static var rawValue: String = AppearanceOption.system.rawValue

    static var current: AppearanceOption {
        get {
            AppearanceOption(rawValue: rawValue) ?? .system
        }
        set {
            rawValue = newValue.rawValue
        }
    }

    static var currentDisplayName: String {
        current.rawValue
    }

    static var resolvedColorScheme: ColorScheme? {
        resolvedColorScheme(for: rawValue)
    }

    static func resolvedColorScheme(for raw: String) -> ColorScheme? {
        switch AppearanceOption(rawValue: raw) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selected: AppearanceOption = AppearanceStorage.current

    var body: some View {
        List {
            ForEach(AppearanceOption.allCases, id: \.self) { option in
                Button {
                    selected = option
                    AppearanceStorage.current = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                            .font(PariTheme.uiFont(size: 16))
                            .foregroundStyle(.primary)
                        Spacer()
                        if selected == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PariTheme.accent(for: colorScheme))
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PariTheme.backgroundPrimary(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selected = AppearanceStorage.current
        }
    }
}
