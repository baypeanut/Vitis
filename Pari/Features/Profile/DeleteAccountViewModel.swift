//
//  DeleteAccountViewModel.swift
//  Pari
//
//  Two-step typed confirmation + re-auth for account deletion.
//

import Foundation

@MainActor
@Observable
final class DeleteAccountViewModel {
    static let confirmationKeyword = "DELETE"

    var confirmationText = ""
    var otpCode = ""
    var isDeleting = false
    var isSendingOTP = false
    var isVerifyingOTP = false
    var errorMessage: String?
    var reAuthStep: ReAuthStep = .typedConfirmation
    var userPhone: String?
    var reAuthResendCooldown = 0
    private var resendTask: Task<Void, Never>?

    enum ReAuthStep {
        case typedConfirmation
        case awaitingCode
        case verified
    }

    var canDelete: Bool {
        confirmationText == Self.confirmationKeyword
    }

    var needsReAuth: Bool {
        userPhone != nil
    }

    var canProceedToDelete: Bool {
        guard canDelete else { return false }
        if needsReAuth {
            return reAuthStep == .verified
        }
        return true
    }

    func loadUserSnapshot() async {
        if let snap = await AuthService.currentUserSnapshot() {
            userPhone = snap.phone
        }
    }

    func sendReAuthOTP() async {
        guard let phone = userPhone else { return }
        isSendingOTP = true
        errorMessage = nil
        do {
            try await AuthService.sendOTP(phoneE164: phone, intent: .loginExisting)
            reAuthStep = .awaitingCode
            startResendCooldown()
        } catch {
            errorMessage = AuthService.friendlyMessage(for: error)
        }
        isSendingOTP = false
    }

    func verifyReAuthOTP() async {
        guard let phone = userPhone else { return }
        let digits = otpCode.filter { $0.isNumber }
        guard digits.count == 6 else { return }
        isVerifyingOTP = true
        errorMessage = nil
        do {
            _ = try await AuthService.verifyOTP(phoneE164: phone, code: digits)
            reAuthStep = .verified
        } catch {
            errorMessage = AuthService.friendlyMessage(for: error)
        }
        isVerifyingOTP = false
    }

    func delete(onSuccess: () -> Void) async {
        guard canProceedToDelete, !isDeleting else { return }
        isDeleting = true
        errorMessage = nil

        // GDPR: delete avatar from storage before removing auth user
        if let userId = await AuthService.currentUserId() {
            await AvatarStorageService.deleteAvatar(userId: userId)
        }

        let result = await AuthService.deleteAccount()
        isDeleting = false

        switch result {
        case .success:
            onSuccess()
        case .failure(let message):
            errorMessage = message
        }
    }

    private func startResendCooldown() {
        resendTask?.cancel()
        reAuthResendCooldown = 60
        resendTask = Task<Void, Never> {
            while reAuthResendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                await MainActor.run {
                    reAuthResendCooldown -= 1
                }
            }
        }
    }

    func cancelResendCooldown() {
        resendTask?.cancel()
        reAuthResendCooldown = 0
    }
}
