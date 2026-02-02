//
//  AuthView.swift
//  Vitis
//
//  Login / Sign up. Validated, connection check, loading. Quiet Luxury.
//

import SwiftUI

struct AuthView: View {
    @State private var countryCode = PhoneFormatter.defaultCountryCode
    @State private var phoneRaw = ""
    @State private var otpCode = ""
    @State private var authState: AuthState = .enterPhone
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var connectionStatus: ConnectionStatus = .checking
    @State private var resendCooldown: Int = 0
    @State private var resendTimer: Task<Void, Never>?

    var onAuthenticated: () -> Void

    enum AuthState: Equatable {
        case enterPhone
        case enterOTP(phone: String)
        case verifying
    }
    enum ConnectionStatus: Equatable {
        case checking
        case ok
        case failed(String)
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

            ScrollView {
                VStack(spacing: 28) {
                    header
                    connectionBanner
                    form
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)

            if isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .task { await checkConnection() }
        .onChange(of: phoneRaw) { _, _ in errorMessage = nil }
        .onChange(of: otpCode) { _, _ in errorMessage = nil }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Vitis")
                .font(VitisTheme.titleFont())
                .foregroundStyle(.primary)
            Text(authState == .enterPhone ? "Sign in with your phone" : "Enter verification code")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var connectionBanner: some View {
        switch connectionStatus {
        case .checking:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8).tint(VitisTheme.secondaryText)
                Text("Checking connection…")
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        case .ok:
            EmptyView()
        case .failed(let msg):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }
                Button("Retry connection") {
                    Task { await checkConnection() }
                }
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch authState {
            case .enterPhone:
                phoneInputSection
            case .enterOTP(let phone):
                otpInputSection(phone: phone)
            case .verifying:
                EmptyView()
            }

            if let err = errorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }
            }

            submitButton
        }
    }
    
    private var phoneInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phone Number")
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.secondaryText)
            
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                TextField("Phone number", text: $phoneRaw)
                    .font(VitisTheme.uiFont(size: 16))
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: phoneRaw) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits.count > 10 {
                            phoneRaw = String(digits.prefix(10))
                        } else {
                            phoneRaw = digits
                        }
                    }
            }
            
            Text("We'll send you a verification code")
                .font(VitisTheme.uiFont(size: 12))
                .foregroundStyle(VitisTheme.secondaryText)
        }
    }
    
    private func otpInputSection(phone: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("We sent a code to \(PhoneFormatter.displayString(e164: phone))")
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
    
    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            Text(authState == .enterPhone ? "Send Code" : "Verify")
                .font(.system(.body, design: .serif, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSubmit ? VitisTheme.accent : Color(white: 0.9))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isLoading || !canSubmit)
        .buttonStyle(.plain)
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

    private func checkConnection() async {
        connectionStatus = .checking
        if !SupabaseConfig.isValid {
            connectionStatus = .failed("Invalid Supabase URL or anon key. Check SupabaseConfig.")
            return
        }
        let result = await AuthService.checkConnection()
        switch result {
        case .ok:
            connectionStatus = .ok
        case .failure(let e):
            connectionStatus = .failed(AuthService.friendlyMessage(for: e))
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
            onAuthenticated()
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
}
