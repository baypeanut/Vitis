//
//  DeleteAccountView.swift
//  Vitis
//
//  Two-step typed confirmation for account deletion.
//

import SwiftUI

struct DeleteAccountView: View {
    @Binding var isPresented: Bool
    var onDeleteSuccess: () -> Void

    @State private var viewModel = DeleteAccountViewModel()
    @FocusState private var isConfirmationFocused: Bool

    private var deleteButtonEnabled: Bool {
        viewModel.canDelete && !viewModel.isDeleting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        explanationSection
                        confirmationSection
                        Spacer(minLength: 24)
                        actionsSection
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }

                if viewModel.isDeleting {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accent)
                }
            }
        }
        .onAppear {
            isConfirmationFocused = true
        }
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This will permanently delete your account.")
                .font(VitisTheme.uiFont(size: 16))
                .foregroundStyle(.primary)
            Text("All your tastings, ratings, and profile data will be removed.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
        }
    }

    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type DELETE to confirm")
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.secondaryText)
            TextField("", text: $viewModel.confirmationText)
                .font(.system(size: 16, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.canDelete ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .focused($isConfirmationFocused)
                .accessibilityLabel("Type DELETE to confirm")
                .accessibilityHint("Type the word DELETE exactly to enable the delete button")

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.delete {
                        isPresented = false
                        onDeleteSuccess()
                    }
                }
            } label: {
                Text("Delete account")
                    .font(VitisTheme.uiFont(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(deleteButtonEnabled ? Color.red : Color.red.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!deleteButtonEnabled)
            .buttonStyle(.plain)
            .accessibilityLabel("Delete account")
            .accessibilityHint(deleteButtonEnabled ? "Permanently delete your account" : "Type DELETE to enable")

            Button("Cancel") {
                isPresented = false
            }
            .font(VitisTheme.uiFont(size: 15, weight: .medium))
            .foregroundStyle(VitisTheme.secondaryText)
            .buttonStyle(.plain)
        }
    }

}
