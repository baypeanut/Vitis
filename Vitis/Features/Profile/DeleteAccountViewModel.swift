//
//  DeleteAccountViewModel.swift
//  Vitis
//
//  Two-step typed confirmation for account deletion.
//

import Foundation

@MainActor
@Observable
final class DeleteAccountViewModel {
    static let confirmationKeyword = "DELETE"

    var confirmationText = ""
    var isDeleting = false
    var errorMessage: String?

    var canDelete: Bool {
        confirmationText == Self.confirmationKeyword
    }

    func delete(onSuccess: () -> Void) async {
        guard canDelete, !isDeleting else { return }
        isDeleting = true
        errorMessage = nil

        let result = await AuthService.deleteAccount()
        isDeleting = false

        switch result {
        case .success:
            onSuccess()
        case .failure(let message):
            errorMessage = message
        }
    }
}
