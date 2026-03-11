//
//  ReportSheetView.swift
//  Pari
//
//  Generic report sheet. Accepts content type + IDs; submits via ReportService.
//  Used from FeedItemView (post reports), CommentSheetView (comment reports),
//  and UserProfileView (profile reports).
//

import SwiftUI

struct ReportSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let contentType: ReportContentType
    let contentId: UUID
    let reportedUserId: UUID
    @Binding var isPresented: Bool

    @State private var selectedReason: ReportReason?
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background(for: colorScheme).ignoresSafeArea()
                if didSubmit {
                    successView
                } else {
                    reasonList
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                }
            }
        }
    }

    private var reasonList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Why are you reporting this?")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            Divider().background(PariTheme.border(for: colorScheme))

            ForEach(ReportReason.allCases) { reason in
                Button {
                    selectedReason = reason
                    Task { await submit(reason: reason) }
                } label: {
                    HStack {
                        Text(reason.displayName)
                            .font(PariTheme.uiFont(size: 16))
                            .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                        Spacer()
                        if isSubmitting && selectedReason == reason {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)

                Divider()
                    .background(PariTheme.border(for: colorScheme))
                    .padding(.leading, 24)
            }

            if let err = errorMessage {
                Text(err)
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }
            Spacer()
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(PariTheme.accent(for: colorScheme))
            Text("Report submitted")
                .font(PariTheme.uiFont(size: 18, weight: .semibold))
                .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
            Text("Thank you. We will review this report and take appropriate action.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Done") { isPresented = false }
                .font(PariTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(PariTheme.accent(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit(reason: ReportReason) async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await ReportService.submitReport(
                contentType: contentType,
                contentId: contentId,
                reportedUserId: reportedUserId,
                reason: reason
            )
            didSubmit = true
        } catch {
            errorMessage = "Could not submit report. Please try again."
            selectedReason = nil
        }
        isSubmitting = false
    }
}
