//
//  DevLoginViewModel.swift
//  Vitis
//
//  Dev-only login: find by username or email, set dev user id on success.
//

import Foundation

@MainActor
@Observable
final class DevLoginViewModel {
    var identifier = ""
    var errorMessage: String?
    var isLoading = false

    func submit() async {
        let q = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            errorMessage = "Enter username or email."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        guard let account = await DevLoginService.findDevAccount(identifier: q) else {
            errorMessage = "Account not found."
            return
        }
        DevSignupService.setDevUserId(account.id)
        NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
        NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
    }
}
