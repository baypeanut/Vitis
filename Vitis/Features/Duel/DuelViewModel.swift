//
//  DuelViewModel.swift
//  Vitis
//
//  MVVM for duel flow. Fetches pair from Supabase, persists comparison, updates rankings.
//

import Foundation

@MainActor
@Observable
final class DuelViewModel {
    var wineA: Wine?
    var wineB: Wine?
    var wineAIsNew = false
    var selectedWinnerID: UUID?
    var isLoading = false
    var errorMessage: String?
    var needsAuth = false

    var canSubmit: Bool {
        guard wineA != nil, wineB != nil, let winner = selectedWinnerID else { return false }
        return winner == wineA?.id || winner == wineB?.id
    }

    init() {}

    func selectWinner(_ wineID: UUID) {
        guard wineID == wineA?.id || wineID == wineB?.id else { return }
        selectedWinnerID = wineID
    }

    func loadNextPair() async {
        let uid = await AuthService.currentUserId()
        if uid == nil && AppConstants.authRequired {
            needsAuth = true
            return
        }
        needsAuth = false
        guard let uid else {
            errorMessage = "Enable auth or sign in to rank wines."
            return
        }
        isLoading = true
        errorMessage = nil
        selectedWinnerID = nil
        wineA = nil
        wineB = nil
        wineAIsNew = false

        do {
            if let (a, b, isNew) = try await DuelService.fetchNextPair(userId: uid) {
                wineA = a
                wineB = b
                wineAIsNew = isNew
            } else {
                // TODO: Use Had cellar items as duel candidates when feasible. Candidate pool = cellar_items where user_id=currentUserId, status='had'. If not enough, empty state + point to Cellar "+".
                errorMessage = "Not enough wines. Add some in Cellar."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func submitComparison() async {
        guard canSubmit, let winner = selectedWinnerID,
              let a = wineA, let b = wineB else { return }
        let uid = await AuthService.currentUserId()
        guard let uid else {
            needsAuth = true
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            try await DuelService.submitComparison(userId: uid, wineA: a, wineB: b, winnerId: winner)
            await loadNextPair()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
