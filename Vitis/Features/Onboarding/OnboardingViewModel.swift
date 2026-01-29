//
//  OnboardingViewModel.swift
//  Vitis
//
//  State, validation, and completion for onboarding. MVVM.
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

    // Step 2: Email
    var email = ""
    var emailError: String?

    // Step 3: Password
    var password = ""
    var showPassword = false
    var passwordError: String?

    // Step 4: Name
    var firstName = ""
    var lastName = ""

    // Step 5: Username
    var username = ""
    var usernameAvailable: Bool?
    var usernameChecking = false
    var usernameError: String?
    private var usernameTask: Task<Void, Never>?

    // Step 6: Photo
    var avatarJpegData: Data?
    var photoSkipped = false

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
        guard isPhoneValid else {
            if !phoneRaw.trimmingCharacters(in: .whitespaces).isEmpty {
                phoneError = "Please enter a valid phone number."
            }
            return false
        }
        return true
    }

    func canContinueEmail() -> Bool {
        emailError = nil
        guard isEmailValid else {
            if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emailError = "Please enter a valid email."
            }
            return false
        }
        return true
    }

    func canContinuePassword() -> Bool {
        passwordError = nil
        guard isPasswordValid else {
            if !password.isEmpty { passwordError = "Password must meet requirements." }
            return false
        }
        return true
    }

    func canContinueName() -> Bool {
        isNameValid
    }

    func canContinueUsername() -> Bool {
        isUsernameValid
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
            currentStep = .email
        case .email:
            if !canContinueEmail() { return }
            currentStep = .password
        case .password:
            if !canContinuePassword() { return }
            currentStep = .name
        case .name:
            if !canContinueName() { return }
            currentStep = .username
            scheduleUsernameCheck()
        case .username:
            if !canContinueUsername() { return }
            currentStep = .photo
        case .photo:
            break
        }
    }

    func skipPhoto() {
        photoSkipped = true
        Task { await completeOnboarding() }
    }

    func submitPhotoAndContinue() {
        Task { await completeOnboarding() }
    }

    var canContinueForCurrentStep: Bool {
        switch currentStep {
        case .phone: return isPhoneValid
        case .email: return isEmailValid
        case .password: return isPasswordValid
        case .name: return isNameValid
        case .username: return isUsernameValid
        case .photo: return true
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
            completionError = "Lütfen tüm zorunlu alanları doldurun."
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
                avatarJpegData: avatarJpegData
            )
        } catch {
            completionError = (error as NSError).localizedDescription
            isLoading = false
            return
        }

        isLoading = false
        NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
        NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
    }
}
