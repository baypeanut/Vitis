//
//  OnboardingFlowView.swift
//  Vitis
//
//  Container: back arrow, optional progress, step content, primary CTA. Quiet Luxury.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var viewModel = OnboardingViewModel()
    @State private var showDevLogin = false

    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                stepContent
                Spacer(minLength: 24)
                ctaSection
            }

            if viewModel.isLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.2)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showDevLogin) {
            AuthLoginView(isPresented: $showDevLogin)
        }
        .onReceive(NotificationCenter.default.publisher(for: .vitisDeepLinkResetPassword)) { _ in
            showDevLogin = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .vitisShowLogIn)) { _ in
            showDevLogin = true
        }
    }

    private var toolbar: some View {
        HStack {
            if viewModel.currentStep != .phone {
                Button {
                    viewModel.back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if let label = viewModel.currentStep.progressLabel {
                Text(label)
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch viewModel.currentStep {
                case .phone:
                    PhoneStepView(vm: viewModel)
                case .email:
                    EmailStepView(vm: viewModel)
                case .password:
                    PasswordStepView(vm: viewModel)
                case .name:
                    NameStepView(vm: viewModel)
                case .username:
                    UsernameStepView(vm: viewModel)
                case .photo:
                    PhotoStepView(vm: viewModel)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            if let err = viewModel.completionError {
                Text(err)
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
            }

            switch viewModel.currentStep {
            case .photo:
                PrimaryButton("Continue", enabled: !viewModel.isLoading) {
                    viewModel.submitPhotoAndContinue()
                }
                if !viewModel.isLoading {
                    Button("Not now") {
                        viewModel.skipPhoto()
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                }
            default:
                PrimaryButton("Continue", enabled: viewModel.canContinueForCurrentStep && !viewModel.isLoading) {
                    viewModel.continueToNext()
                }
            }

            if !AppConstants.authRequired, viewModel.currentStep == .phone {
                Button("Already have an account? Log in") {
                    showDevLogin = true
                }
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.accent)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}
