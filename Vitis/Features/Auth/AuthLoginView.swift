//
//  AuthLoginView.swift
//  Vitis
//
//  Real Supabase Auth login: email + password, signInWithPassword. Show real errors.
//

import SwiftUI

struct AuthLoginView: View {
    @Binding var isPresented: Bool
    @State private var countryCode = PhoneFormatter.defaultCountryCode
    @State private var phoneRaw = ""
    @State private var otpCode = ""
    @State private var authState: AuthState = .enterPhone
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showForgotPassword = false
    @State private var resendCooldown: Int = 0
    @State private var resendTimer: Task<Void, Never>?

    enum AuthState: Equatable {
        case enterPhone
        case enterOTP(phone: String)
        case verifying
    }
    
    private var phoneE164: String? {
        PhoneFormatter.normalizeToE164(countryCode: countryCode, raw: phoneRaw)
    }
    
    private var isPhoneValid: Bool {
        PhoneValidator.isValid(countryCode: countryCode, raw: phoneRaw)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    SerifTitleText(title: authState == .enterPhone ? "Log in" : "Enter code")
                    Text(authState == .enterPhone ? "Sign in with your phone number." : "We sent a code to your phone.")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText)

                    if authState == .enterPhone {
                        phoneInputSection
                    } else if case .enterOTP(let phone) = authState {
                        otpInputSection(phone: phone)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(.red)
                    }

                    PrimaryButton(authState == .enterPhone ? "Send Code" : "Verify", enabled: canSubmit && !isLoading) {
                        Task { await submit() }
                    }

                    Button("Recover account via email") {
                        showForgotPassword = true
                    }
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .padding(.top, 4)

                    #if DEBUG
                    if !AppConstants.authRequired {
                        Button("Sign in as test user") {
                            Task { await signInAsTestUser() }
                        }
                        .font(VitisTheme.uiFont(size: 14))
                        .foregroundStyle(VitisTheme.accent)
                        .padding(.top, 8)
                    }
                    #endif
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                if isLoading {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.2)
                }
            }
            .navigationTitle("Log in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accent)
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(isPresented: $showForgotPassword)
            }
            .onReceive(NotificationCenter.default.publisher(for: .vitisDeepLinkResetPassword)) { _ in
                showForgotPassword = false
            }
        }
    }
    
    private var phoneInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Menu {
                    Button("+1") { countryCode = "+1" }
                    Button("+44") { countryCode = "+44" }
                    Button("+90") { countryCode = "+90" }
                    Button("+49") { countryCode = "+49" }
                    Button("+33") { countryCode = "+33" }
                } label: {
                    HStack(spacing: 4) {
                        Text(countryCode)
                            .font(VitisTheme.uiFont(size: 16))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.vertical, 12)
                }
                
                UnderlineTextField(
                    placeholder: "Phone number",
                    text: $phoneRaw,
                    keyboardType: .numberPad,
                    textContentType: .telephoneNumber
                )
                .onChange(of: phoneRaw) { _, newValue in
                    let digits = newValue.filter { $0.isNumber }
                    if digits.count > 10 {
                        phoneRaw = String(digits.prefix(10))
                    } else {
                        phoneRaw = digits
                    }
                    errorMessage = nil
                }
            }
        }
    }
    
    private func otpInputSection(phone: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sent to \(PhoneFormatter.displayString(e164: phone))")
                .font(VitisTheme.uiFont(size: 13))
                .foregroundStyle(VitisTheme.secondaryText)
            
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    OTPDigitBox(
                        digit: digitAt(index),
                        isFocused: index == otpCode.count
                    )
                }
            }
            .background(
                TextField("", text: $otpCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .opacity(0)
                    .onChange(of: otpCode) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits.count > 6 {
                            otpCode = String(digits.prefix(6))
                        } else {
                            otpCode = digits
                        }
                        errorMessage = nil
                        
                        if otpCode.count == 6 {
                            Task { await verifyOTP() }
                        }
                    }
            )
            
            if resendCooldown > 0 {
                Text("Resend code in \(resendCooldown)s")
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            } else {
                Button("Resend code") {
                    Task { await resendOTP() }
                }
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.accent)
                .disabled(isLoading)
            }
        }
    }
    
    private func digitAt(_ index: Int) -> String? {
        guard index < otpCode.count else { return nil }
        let idx = otpCode.index(otpCode.startIndex, offsetBy: index)
        return String(otpCode[idx])
    }

    private var canSubmit: Bool {
        switch authState {
        case .enterPhone:
            return isPhoneValid
        case .enterOTP:
            return otpCode.count == 6
        case .verifying:
            return false
        }
    }

    private func submit() async {
        switch authState {
        case .enterPhone:
            await sendOTP()
        case .enterOTP:
            await verifyOTP()
        case .verifying:
            break
        }
    }
    
    private func sendOTP() async {
        guard let e164 = phoneE164 else {
            errorMessage = "Invalid phone number"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let result = await AuthService.signInWithPhone(e164)
        
        isLoading = false
        
        switch result {
        case .success:
            authState = .enterOTP(phone: e164)
            startResendCooldown()
        case .failure(let msg):
            errorMessage = msg
        }
    }
    
    private func verifyOTP() async {
        guard case .enterOTP(let phone) = authState else { return }
        guard otpCode.count == 6 else {
            errorMessage = "Please enter the 6-digit code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        authState = .verifying
        
        let result = await AuthService.verifyPhoneOTP(phone: phone, token: otpCode)
        
        isLoading = false
        
        switch result {
        case .success:
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
            isPresented = false
        case .failure(let msg):
            errorMessage = msg
            otpCode = ""
            authState = .enterOTP(phone: phone)
        }
    }
    
    private func resendOTP() async {
        guard case .enterOTP(let phone) = authState else { return }
        guard resendCooldown == 0 else { return }
        
        isLoading = true
        errorMessage = nil
        
        let result = await AuthService.signInWithPhone(phone)
        
        isLoading = false
        
        switch result {
        case .success:
            startResendCooldown()
        case .failure(let msg):
            errorMessage = msg
        }
    }
    
    private func startResendCooldown() {
        resendCooldown = 60
        resendTimer?.cancel()
        resendTimer = Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                resendCooldown -= 1
            }
        }
    }

    #if DEBUG
    private func signInAsTestUser() async {
        let em = AppConstants.devTestEmail
        let pw = AppConstants.devTestPassword
        isLoading = true
        errorMessage = nil
        let result = await AuthService.signIn(email: em, password: pw)
        isLoading = false
        switch result {
        case .success:
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
            isPresented = false
        case .failure(let msg):
            errorMessage = msg
        }
    }
    #endif
}

// MARK: - AuthLoginViewContent (for navigation push, no NavigationStack wrapper)

struct AuthLoginViewContent: View {
    @Environment(\.dismiss) private var dismiss
    @State private var countryCode = PhoneFormatter.defaultCountryCode
    @State private var phoneRaw = ""
    @State private var otpCode = ""
    @State private var authState: AuthState = .enterPhone
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showForgotPassword = false
    @State private var resendCooldown: Int = 0
    @State private var resendTimer: Task<Void, Never>?

    enum AuthState: Equatable {
        case enterPhone
        case enterOTP(phone: String)
        case verifying
    }
    
    private var phoneE164: String? {
        PhoneFormatter.normalizeToE164(countryCode: countryCode, raw: phoneRaw)
    }
    
    private var isPhoneValid: Bool {
        PhoneValidator.isValid(countryCode: countryCode, raw: phoneRaw)
    }

    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                SerifTitleText(title: authState == .enterPhone ? "Log in" : "Enter code")
                Text(authState == .enterPhone ? "Sign in with your phone number." : "We sent a code to your phone.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)

                if authState == .enterPhone {
                    phoneInputSection
                } else if case .enterOTP(let phone) = authState {
                    otpInputSection(phone: phone)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }

                PrimaryButton(authState == .enterPhone ? "Send Code" : "Verify", enabled: canSubmit && !isLoading) {
                    Task { await submit() }
                }

                Button("Recover account via email") {
                    showForgotPassword = true
                }
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(VitisTheme.secondaryText)
                .padding(.top, 4)

                #if DEBUG
                if !AppConstants.authRequired {
                    Button("Sign in as test user") {
                        Task { await signInAsTestUser() }
                    }
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.accent)
                    .padding(.top, 8)
                }
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            if isLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.2)
            }
        }
        .navigationTitle("Log in")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(isPresented: $showForgotPassword)
        }
        .onReceive(NotificationCenter.default.publisher(for: .vitisDeepLinkResetPassword)) { _ in
            showForgotPassword = false
        }
    }
    
    private var phoneInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Menu {
                    Button("+1") { countryCode = "+1" }
                    Button("+44") { countryCode = "+44" }
                    Button("+90") { countryCode = "+90" }
                    Button("+49") { countryCode = "+49" }
                    Button("+33") { countryCode = "+33" }
                } label: {
                    HStack(spacing: 4) {
                        Text(countryCode)
                            .font(VitisTheme.uiFont(size: 16))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.vertical, 12)
                }
                
                UnderlineTextField(
                    placeholder: "Phone number",
                    text: $phoneRaw,
                    keyboardType: .numberPad,
                    textContentType: .telephoneNumber
                )
                .onChange(of: phoneRaw) { _, newValue in
                    let digits = newValue.filter { $0.isNumber }
                    if digits.count > 10 {
                        phoneRaw = String(digits.prefix(10))
                    } else {
                        phoneRaw = digits
                    }
                    errorMessage = nil
                }
            }
        }
    }
    
    private func otpInputSection(phone: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sent to \(PhoneFormatter.displayString(e164: phone))")
                .font(VitisTheme.uiFont(size: 13))
                .foregroundStyle(VitisTheme.secondaryText)
            
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    OTPDigitBox(
                        digit: digitAt(index),
                        isFocused: index == otpCode.count
                    )
                }
            }
            .background(
                TextField("", text: $otpCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .opacity(0)
                    .onChange(of: otpCode) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits.count > 6 {
                            otpCode = String(digits.prefix(6))
                        } else {
                            otpCode = digits
                        }
                        errorMessage = nil
                        
                        if otpCode.count == 6 {
                            Task { await verifyOTP() }
                        }
                    }
            )
            
            if resendCooldown > 0 {
                Text("Resend code in \(resendCooldown)s")
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            } else {
                Button("Resend code") {
                    Task { await resendOTP() }
                }
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.accent)
                .disabled(isLoading)
            }
        }
    }
    
    private func digitAt(_ index: Int) -> String? {
        guard index < otpCode.count else { return nil }
        let idx = otpCode.index(otpCode.startIndex, offsetBy: index)
        return String(otpCode[idx])
    }

    private var canSubmit: Bool {
        switch authState {
        case .enterPhone:
            return isPhoneValid
        case .enterOTP:
            return otpCode.count == 6
        case .verifying:
            return false
        }
    }

    private func submit() async {
        switch authState {
        case .enterPhone:
            await sendOTP()
        case .enterOTP:
            await verifyOTP()
        case .verifying:
            break
        }
    }
    
    private func sendOTP() async {
        guard let e164 = phoneE164 else {
            errorMessage = "Invalid phone number"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let result = await AuthService.signInWithPhone(e164)
        
        isLoading = false
        
        switch result {
        case .success:
            authState = .enterOTP(phone: e164)
            startResendCooldown()
        case .failure(let msg):
            errorMessage = msg
        }
    }
    
    private func verifyOTP() async {
        guard case .enterOTP(let phone) = authState else { return }
        guard otpCode.count == 6 else {
            errorMessage = "Please enter the 6-digit code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        authState = .verifying
        
        let result = await AuthService.verifyPhoneOTP(phone: phone, token: otpCode)
        
        isLoading = false
        
        switch result {
        case .success:
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
            dismiss()
        case .failure(let msg):
            errorMessage = msg
            otpCode = ""
            authState = .enterOTP(phone: phone)
        }
    }
    
    private func resendOTP() async {
        guard case .enterOTP(let phone) = authState else { return }
        guard resendCooldown == 0 else { return }
        
        isLoading = true
        errorMessage = nil
        
        let result = await AuthService.signInWithPhone(phone)
        
        isLoading = false
        
        switch result {
        case .success:
            startResendCooldown()
        case .failure(let msg):
            errorMessage = msg
        }
    }
    
    private func startResendCooldown() {
        resendCooldown = 60
        resendTimer?.cancel()
        resendTimer = Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                resendCooldown -= 1
            }
        }
    }

    #if DEBUG
    private func signInAsTestUser() async {
        let em = AppConstants.devTestEmail
        let pw = AppConstants.devTestPassword
        isLoading = true
        errorMessage = nil
        let result = await AuthService.signIn(email: em, password: pw)
        isLoading = false
        switch result {
        case .success:
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
            dismiss()
        case .failure(let msg):
            errorMessage = msg
        }
    }
    #endif
}
