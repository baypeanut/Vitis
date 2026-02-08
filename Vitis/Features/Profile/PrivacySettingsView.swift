//
//  PrivacySettingsView.swift
//  Vitis
//
//  Privacy settings: Cellar, Wishlist, Activity visibility (Everyone vs Friends).
//

import SwiftUI

struct PrivacySettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings: PrivacySettings = .default
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var currentUserId: UUID?

    var body: some View {
        List {
            Section {
                policyRow(title: "Cellar", value: settings.cellarVisibility) { v in
                    settings.cellarVisibility = v
                    Task { await save(.cellar(v)) }
                }
                policyRow(title: "Wishlist", value: settings.wishlistVisibility) { v in
                    settings.wishlistVisibility = v
                    Task { await save(.wishlist(v)) }
                }
                policyRow(title: "Recent activity", value: settings.activityVisibility) { v in
                    settings.activityVisibility = v
                    Task { await save(.activity(v)) }
                }
            }
            Section {
                Text("Friends are people who follow you and you follow back.")
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    .padding(.vertical, 4)
            }
            if let err = errorMessage {
                Section {
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VitisTheme.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            currentUserId = await AuthService.currentUserId()
            await load()
        }
    }

    private enum SaveField {
        case cellar(PrivacyVisibility)
        case wishlist(PrivacyVisibility)
        case activity(PrivacyVisibility)
    }

    private func policyRow(title: String, value: PrivacyVisibility, onSelect: @escaping (PrivacyVisibility) -> Void) -> some View {
        HStack {
            Text(title)
                .font(VitisTheme.uiFont(size: 16))
            Spacer()
            Picker("", selection: Binding(get: { value }, set: { onSelect($0) })) {
                ForEach(PrivacyVisibility.allCases, id: \.self) { v in
                    Text(v.displayName).tag(v)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        guard let uid = currentUserId else { return }
        do {
            settings = try await ProfileService.fetchPrivacySettings(userId: uid)
        } catch {
            errorMessage = ErrorMessage.userFacing(for: error)
        }
    }

    private func save(_ field: SaveField) async {
        guard let uid = currentUserId else { return }
        isSaving = true
        errorMessage = nil
        let previous = settings
        do {
            switch field {
            case .cellar(let v):
                try await ProfileService.updatePrivacySettings(userId: uid, cellarVisibility: v)
            case .wishlist(let v):
                try await ProfileService.updatePrivacySettings(userId: uid, wishlistVisibility: v)
            case .activity(let v):
                try await ProfileService.updatePrivacySettings(userId: uid, activityVisibility: v)
            }
        } catch {
            errorMessage = ErrorMessage.userFacing(for: error)
            settings = previous
        }
        isSaving = false
    }
}
