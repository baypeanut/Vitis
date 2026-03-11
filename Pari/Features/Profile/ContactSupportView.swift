//
//  ContactSupportView.swift
//  Pari
//
//  Pari Concierge: minimalist in-app support.
//

import SwiftUI

struct ContactSupportView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var contactEmail: String = ""
    @State private var subject: SupportTicketSubject = .feedback
    @State private var message: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    private let messagePlaceholder = "How can we refine your experience?"

    private var canSend: Bool {
        let email = contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return NSPredicate(format: "SELF MATCHES %@", #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#).evaluate(with: email) && !msg.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.backgroundPrimary(for: colorScheme).ignoresSafeArea()

                if didSucceed {
                    successContent
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                } else {
                    formContent
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                }

                if isSending {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .navigationTitle("Contact Concierge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.accentWine(for: colorScheme))
                }
            }
            .onAppear {
                contactEmail = AuthStore.shared.userSnapshot?.email ?? ""
            }
        }
    }

    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(PariTheme.accentWineMuted(for: colorScheme))
            Text("Your message has been received.")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                .multilineTextAlignment(.center)
            Text("Our concierge will reach out shortly.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SerifTitleText(title: "Direct Support")
                Text("We're here to help. Share your thoughts or questions below.")
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact email")
                        .font(PariTheme.uiFont(size: 13, weight: .medium))
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    TextField("", text: $contactEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .font(PariTheme.uiFont(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(PariTheme.placeholderBackground(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(PariTheme.borderSubtle(for: colorScheme), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject")
                        .font(PariTheme.uiFont(size: 13, weight: .medium))
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    Menu {
                        ForEach(SupportTicketSubject.allCases) { option in
                            Button(option.rawValue) {
                                subject = option
                            }
                        }
                    } label: {
                        HStack {
                            Text(subject.rawValue)
                                .font(PariTheme.uiFont(size: 16))
                                .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(PariTheme.placeholderBackground(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(PariTheme.borderSubtle(for: colorScheme), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(PariTheme.uiFont(size: 13, weight: .medium))
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text(messagePlaceholder)
                                .font(PariTheme.uiFont(size: 16))
                                .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        TextEditor(text: $message)
                            .font(PariTheme.uiFont(size: 16))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .background(PariTheme.placeholderBackground(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(PariTheme.borderSubtle(for: colorScheme), lineWidth: 1)
                    )
                }

                if let err = errorMessage {
                    Text(err)
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(PariTheme.dangerMuted(for: colorScheme))
                }

                Button {
                    Task { await send() }
                } label: {
                    Text("Send")
                        .font(PariTheme.uiFont(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSend ? PariTheme.accentWine(for: colorScheme) : PariTheme.textDisabled(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSend || isSending)
                .buttonStyle(.plain)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 48)
        }
    }

    private func send() async {
        guard canSend else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await SupportService.submitTicket(
                subject: subject.rawValue,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                contactEmail: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            withAnimation(.easeInOut(duration: 0.4)) {
                didSucceed = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
