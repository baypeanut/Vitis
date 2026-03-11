//
//  DeleteAccountView.swift
//  Pari
//
//  Two-step typed confirmation + re-auth for account deletion.
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    var onDeleteSuccess: () -> Void

    @State private var viewModel = DeleteAccountViewModel()
    @FocusState private var isConfirmationFocused: Bool
    @FocusState private var isOTPFocused: Bool

    private var deleteButtonEnabled: Bool {
        viewModel.canProceedToDelete && !viewModel.isDeleting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background(for: colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        explanationSection
                        confirmationSection
                        if viewModel.needsReAuth {
                            reAuthSection
                        }
                        if let err = viewModel.errorMessage {
                            Text(err)
                                .font(PariTheme.uiFont(size: 13))
                                .foregroundStyle(PariTheme.dangerMuted(for: colorScheme))
                        }
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
                        viewModel.cancelResendCooldown()
                        isPresented = false
                    }
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.accent(for: colorScheme))
                }
            }
        }
        .onAppear {
            isConfirmationFocused = true
            Task { await viewModel.loadUserSnapshot() }
        }
        .onDisappear {
            viewModel.cancelResendCooldown()
        }
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This will permanently delete your account.")
                .font(PariTheme.uiFont(size: 16))
                .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
            Text("Your profile, tastings, ratings, follows, and all associated data will be removed. This cannot be undone.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
        }
    }

    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type DELETE to confirm")
                .font(PariTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            TextField("", text: $viewModel.confirmationText)
                .font(.system(size: 16, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(PariTheme.placeholderBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.canDelete ? PariTheme.success.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .focused($isConfirmationFocused)
                .accessibilityLabel("Type DELETE to confirm")
                .accessibilityHint("Type the word DELETE exactly to enable the next step")
        }
    }

    @ViewBuilder
    private var reAuthSection: some View {
        if viewModel.canDelete {
            VStack(alignment: .leading, spacing: 12) {
                Text("Verify identity")
                    .font(PariTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))

                if viewModel.reAuthStep == .typedConfirmation {
                    Button {
                        Task { await viewModel.sendReAuthOTP() }
                    } label: {
                        Text("Send verification code")
                            .font(PariTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PariTheme.secondaryElevated(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(viewModel.isSendingOTP)
                    .buttonStyle(.plain)
                } else if viewModel.reAuthStep == .awaitingCode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter the 6-digit code sent to your phone")
                            .font(PariTheme.uiFont(size: 13))
                            .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        TextField("••••••", text: $viewModel.otpCode)
                            .font(PariTheme.uiFont(size: 20, weight: .semibold))
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(PariTheme.placeholderBackground(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($isOTPFocused)
                        HStack {
                            Button {
                                Task { await viewModel.sendReAuthOTP() }
                            } label: {
                                if viewModel.reAuthResendCooldown > 0 {
                                    Text("Resend in \(viewModel.reAuthResendCooldown)s")
                                } else {
                                    Text("Resend code")
                                }
                            }
                            .font(PariTheme.uiFont(size: 13))
                            .foregroundStyle(viewModel.reAuthResendCooldown > 0 ? PariTheme.tertiaryText(for: colorScheme) : PariTheme.accent(for: colorScheme))
                            .disabled(viewModel.reAuthResendCooldown > 0)
                            .buttonStyle(.plain)
                            Spacer()
                            Button {
                                Task { await viewModel.verifyReAuthOTP() }
                            } label: {
                                Text("Verify")
                                    .font(PariTheme.uiFont(size: 14, weight: .medium))
                            }
                            .disabled(viewModel.otpCode.filter { $0.isNumber }.count != 6 || viewModel.isVerifyingOTP)
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PariTheme.success)
                        Text("Identity verified")
                            .font(PariTheme.uiFont(size: 14))
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    }
                }
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
                    .font(PariTheme.uiFont(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(deleteButtonEnabled ? PariTheme.dangerMuted(for: colorScheme) : PariTheme.dangerMuted(for: colorScheme).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!deleteButtonEnabled)
            .buttonStyle(.plain)
            .accessibilityLabel("Delete account")
            .accessibilityHint(deleteButtonEnabled ? "Permanently delete your account" : "Complete the steps above to enable")

            Button("Cancel") {
                isPresented = false
            }
            .font(PariTheme.uiFont(size: 15, weight: .medium))
            .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            .buttonStyle(.plain)
        }
    }
}
