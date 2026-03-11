//
//  ProfileSetupView.swift
//  Pari
//
//  Collect username + display name after OTP verification.
//

import SwiftUI

struct ProfileSetupView: View {
    let userId: UUID

    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Button {
                            Task { await AuthStore.shared.signOut() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(PariTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(PariTheme.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 6)

                        Text("Set up your profile")
                            .font(PariTheme.titleFont())
                            .foregroundStyle(.primary)
                            .padding(.bottom, 4)

                        Text("Choose a username and how you want to appear.")
                            .font(PariTheme.uiFont(size: 15))
                            .foregroundStyle(PariTheme.secondaryText)

                        VStack(alignment: .leading, spacing: 16) {
                            labeledField("Username", text: $username, placeholder: "e.g. wine_lover")
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            labeledField("Display name", text: $displayName, placeholder: "Your name")

                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(PariTheme.uiFont(size: 13))
                                .foregroundStyle(.red)
                        }

                        PrimaryButton("Continue", enabled: canSubmit && !isSaving) {
                            Task { await save() }
                        }
                        .padding(.top, 12)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 40)
                    .padding(.bottom, 60)
                }

                if isSaving {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .navigationBarHidden(true)
        }
        .task { await loadExistingProfile() }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(PariTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(PariTheme.secondaryText)
            TextField(placeholder, text: text)
                .font(PariTheme.uiFont(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var canSubmit: Bool {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUsername.count >= 2 && !trimmedDisplayName.isEmpty
    }

    private func loadExistingProfile() async {
        do {
            if let profile = try await AuthService.getProfile(userId: userId) {
                username = profile.username
                displayName = profile.fullName ?? ""
            }
        } catch {
            // Non-fatal: continue with empty fields
        }
    }

    private func save() async {
        guard canSubmit else { return }
        isSaving = true
        errorMessage = nil
        do {
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await AuthService.upsertProfile(
                userId: userId,
                username: trimmedUsername,
                fullName: trimmedDisplayName,
                email: nil
            )
            AuthStore.shared.markProfileCompleted()
            await ProfileStore.shared.load()
            dismiss()
        } catch {
            errorMessage = AuthService.friendlyMessage(for: error)
        }
        isSaving = false
    }
}
