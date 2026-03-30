//
//  OnboardingViewModel.swift
//  Pari
//
//  State, validation, and completion for 3-step onboarding. MVVM.
//  Steps: Phone → Account (email+password) → Identity (name+username)
//

import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .phone

    // Step 1: Phone
    var countryCode = PhoneFormatter.defaultCountryCode
    var phoneRaw = ""
    var phoneError: String?

    // Step 2: Account (email + password)
    var email = ""
    var emailError: String?
    var password = ""
    var showPassword = false
    var passwordError: String?

    // Step 3: Identity (name + username)
    var firstName = ""
    var lastName = ""
    var username = ""
    var usernameAvailable: Bool?
    var usernameChecking = false
    var usernameError: String?
    private var usernameTask: Task<Void, Never>?

    var isLoading = false
    var completionError: String?

    private let emailPredicate = NSPredicate(format: "SELF MATCHES %@", #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#)
    private let usernameDebounceNs: UInt64 = 300_000_000

    // MARK: - Validation

    var phoneE164: String? {
        PhoneFormatter.normalizeToE164(countryCode: countryCode, raw: phoneRaw)
    }

    private var isPhoneValid: Bool {
        PhoneValidator.isValid(countryCode: countryCode, raw: phoneRaw)
    }

    private var isEmailValid: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !e.isEmpty && emailPredicate.evaluate(with: e)
    }

    private var isPasswordValid: Bool {
        guard password.count >= 8 && password.count <= 20 else { return false }
        let hasLetter = password.contains { $0.isLetter }
        let hasNumber = password.contains { $0.isNumber }
        let hasSpecial = password.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }
        return hasLetter && hasNumber && hasSpecial
    }

    private var isNameValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isUsernameValid: Bool {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return u.count >= 2 && usernameAvailable == true
    }

    func canContinuePhone() -> Bool {
        phoneError = nil
        let digits = phoneRaw.filter { $0.isNumber }

        // For US numbers, require exactly 10 digits
        if countryCode == "+1" {
            return digits.count == 10 && isPhoneValid
        }

        // For other countries, use standard validation
        return isPhoneValid
    }

    func canContinueAccount() -> Bool {
        emailError = nil
        passwordError = nil

        let emailOk: Bool
        if !isEmailValid {
            if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emailError = "Please enter a valid email."
            }
            emailOk = false
        } else {
            emailOk = true
        }

        let passwordOk: Bool
        if !isPasswordValid {
            if !password.isEmpty { passwordError = "Password must meet requirements." }
            passwordOk = false
        } else {
            passwordOk = true
        }

        return emailOk && passwordOk
    }

    func canContinueIdentity() -> Bool {
        isNameValid && isUsernameValid
    }

    // MARK: - Username availability (debounced)

    func scheduleUsernameCheck() {
        usernameTask?.cancel()
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard u.count >= 2 else {
            usernameAvailable = nil
            usernameError = nil
            return
        }
        usernameChecking = true
        usernameAvailable = nil
        usernameError = nil
        usernameTask = Task {
            try? await Task.sleep(nanoseconds: usernameDebounceNs)
            guard !Task.isCancelled else { return }
            let available = await ProfileService.checkUsernameAvailable(u)
            guard !Task.isCancelled else { return }
            usernameChecking = false
            usernameAvailable = available
            if !available { usernameError = "That username is taken." }
        }
    }

    // MARK: - Navigation

    func back() {
        completionError = nil
        if let prev = currentStep.previous {
            currentStep = prev
        }
    }

    func continueToNext() {
        completionError = nil
        switch currentStep {
        case .phone:
            if !canContinuePhone() { return }
            currentStep = .account
        case .account:
            if !canContinueAccount() { return }
            currentStep = .identity
            scheduleUsernameCheck()
        case .identity:
            if !canContinueIdentity() { return }
            Task { await completeOnboarding() }
        }
    }

    var canContinueForCurrentStep: Bool {
        switch currentStep {
        case .phone: return isPhoneValid
        case .account: return isEmailValid && isPasswordValid
        case .identity: return isNameValid && isUsernameValid
        }
    }

    // MARK: - Completion

    func completeOnboarding() async {
        guard let e164 = phoneE164 else { return }
        let em = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pw = password
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let un = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !em.isEmpty, pw.count >= 8, !fn.isEmpty, un.count >= 2, usernameAvailable == true else {
            completionError = "Please fill in all required fields."
            return
        }

        isLoading = true
        completionError = nil

        do {
            try await OnboardingService.complete(
                phoneE164: e164,
                email: em,
                password: pw,
                firstName: fn,
                lastName: ln.isEmpty ? nil : ln,
                username: un,
                avatarJpegData: nil
            )
        } catch {
            completionError = (error as NSError).localizedDescription
            isLoading = false
            return
        }

        isLoading = false
        AnalyticsService.signupCompleted()
        NotificationCenter.default.post(name: .pariSessionReady, object: nil)
        NotificationCenter.default.post(name: .pariProfileUpdated, object: nil)
    }
}
