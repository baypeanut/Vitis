//
//  TastingSessionView.swift
//  Pari
//
//  Group mode. Start a table, read the code out, and get the bottle that suits
//  everyone sitting at it.
//
//  The code is the growth mechanism: the fourth person has a concrete reason to
//  install the app at the exact moment the product is proving itself. A feed was
//  never going to produce that.
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class TastingSessionViewModel {
    enum Step {
        case start
        case atTable(TastingSession, [GroupWineSuggestion])
        case working
        case failed(String)
    }

    var step: Step = .start
    var joinCode = ""

    func host() async {
        step = .working
        do {
            let session = try await TastingSessionService.create()
            await loadSuggestions(for: session)
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    func join() async {
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 4 else { return }
        step = .working
        do {
            let session = try await TastingSessionService.join(code: code)
            await loadSuggestions(for: session)
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        guard case .atTable(let session, _) = step else { return }
        await loadSuggestions(for: session)
    }

    private func loadSuggestions(for session: TastingSession) async {
        do {
            let wines = try await TastingSessionService.suggestions(sessionId: session.id)
            step = .atTable(session, wines)
        } catch {
            // The table exists even if we cannot rank for it yet, so stay in it.
            step = .atTable(session, [])
        }
    }

    func leave() async {
        if case .atTable(let session, _) = step {
            await TastingSessionService.leave(sessionId: session.id)
        }
        joinCode = ""
        step = .start
    }
}

struct TastingSessionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    let currentUserId: UUID?

    @State private var viewModel = TastingSessionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background(for: colorScheme).ignoresSafeArea()
                content
            }
            .navigationTitle("The Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Task { await viewModel.leave(); isPresented = false }
                    }
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.accent(for: colorScheme))
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .start:
            startScreen
        case .working:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(PariTheme.accent(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .atTable(let session, let wines):
            tableScreen(session, wines)
        case .failed(let message):
            VStack(spacing: 16) {
                Text(message)
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                Button("Back") { viewModel.step = .start }
                    .font(PariTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(PariTheme.accent(for: colorScheme))
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Start

    private var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Image(systemName: "person.2.wave.2")
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundStyle(PariTheme.accentWine(for: colorScheme))
                Text("One bottle, several palates")
                    .font(.system(.title3, design: .serif, weight: .regular))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                Text("Start a table and read the code out. We'll find the wine that suits everyone sitting at it.")
                    .font(PariTheme.uiFont(size: 14))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Button {
                Task { await viewModel.host() }
            } label: {
                Text("Start a table")
                    .font(PariTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PariTheme.accentWine(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)

            VStack(spacing: 10) {
                Text("or join one")
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                HStack(spacing: 10) {
                    TextField("CODE", text: $viewModel.joinCode)
                        .font(.system(.title3, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 12)
                        .background(PariTheme.backgroundSecondary(for: colorScheme))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(PariTheme.divider(for: colorScheme), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: viewModel.joinCode) { _, new in
                            // Codes are five upper-case alphanumerics. Normalising as
                            // they type saves a failed round trip for a stray space.
                            let cleaned = String(new.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(5))
                            if cleaned != new { viewModel.joinCode = cleaned }
                        }
                    Button("Join") {
                        Task { await viewModel.join() }
                    }
                    .font(PariTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(viewModel.joinCode.count >= 4
                                     ? PariTheme.accent(for: colorScheme)
                                     : PariTheme.textTertiary(for: colorScheme))
                    .disabled(viewModel.joinCode.count < 4)
                }
                .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - At the table

    private func tableScreen(_ session: TastingSession, _ wines: [GroupWineSuggestion]) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                codeBanner(session)

                if wines.isEmpty {
                    Text("Nobody at this table has rated enough wine yet. Log a few and pull down to refresh.")
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 40)
                } else {
                    ForEach(wines) { suggestion in
                        NavigationLink {
                            WineCardView(wine: suggestion.wine, activityId: nil, currentUserId: currentUserId)
                        } label: {
                            row(suggestion)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 24)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func codeBanner(_ session: TastingSession) -> some View {
        VStack(spacing: 6) {
            Text(session.code)
                .font(.system(size: 34, weight: .medium, design: .monospaced))
                .tracking(6)
                .foregroundStyle(PariTheme.accentWine(for: colorScheme))
            Text(session.memberCount == 1
                 ? "Read this out. Nobody else has joined yet."
                 : "\(session.memberCount) at the table")
                .font(PariTheme.uiFont(size: 13))
                .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func row(_ s: GroupWineSuggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(s.wine.producer)
                    .font(PariTheme.uiFont(size: 12))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    .lineLimit(1)
                Text(s.wine.name)
                    .font(PariTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let region = s.wine.region {
                    Text(region)
                        .font(PariTheme.uiFont(size: 12))
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }
                // The number that actually decides whether to order it. A mean can
                // hide one person having a bad evening; this cannot.
                Text("worst fit at the table \(Int((s.worstMember * 100).rounded()))%")
                    .font(PariTheme.uiFont(size: 11))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    .padding(.top, 2)
            }
            Spacer(minLength: 8)
            VStack(spacing: 1) {
                Text("\(Int((s.groupMean * 100).rounded()))")
                    .font(.system(.body, design: .serif, weight: .medium))
                    .foregroundStyle(PariTheme.accent(for: colorScheme))
                Text("table")
                    .font(PariTheme.uiFont(size: 10))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
