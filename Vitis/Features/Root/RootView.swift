//
//  RootView.swift
//  Vitis
//
//  Auth gate: when authRequired, show OnboardingFlowView when not signed in; else TabView.
//  Dev (authRequired = false): main tabs + guest/mock. Sign out → onboarding (test sign-up).
//

import SwiftUI

struct RootView: View {
    @State private var showOnboarding = true
    @State private var checked = false
    /// Dev mode: sign out → true → show onboarding to test sign-up.
    @State private var devSignedOut = false
    @ObservedObject private var recovery = AuthRecoveryState.shared

    var body: some View {
        Group {
            if !AppConstants.authRequired {
                if devSignedOut {
                    OnboardingFlowView()
                } else {
                    mainTabs
                }
            } else if !checked {
                VitisTheme.background.overlay {
                    ProgressView().tint(VitisTheme.accent)
                }
                .ignoresSafeArea()
            } else if showOnboarding {
                OnboardingFlowView()
            } else {
                mainTabs
            }
        }
        .task {
            if AppConstants.authRequired {
                await checkSession()
            } else if !devSignedOut {
                await AuthService.ensureGuestSessionIfNeeded()
            }
            await ProfileStore.shared.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSessionReady)) { _ in
            Task {
                await ProfileStore.shared.load()
                if AppConstants.authRequired {
                    await checkSession()
                } else {
                    devSignedOut = false
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { recovery.showNewPasswordView },
            set: { if !$0 { recovery.dismissRecovery() } }
        )) {
            NewPasswordView(onComplete: {
                recovery.dismissRecovery()
            })
        }
    }

    private var mainTabs: some View {
        TabView {
            CellarView()
                .tabItem { Label("Cellar", systemImage: "square.stack") }
            SocialView()
                .tabItem { Label("Social", systemImage: "person.2") }
            ProfileView(onSignOut: didSignOut)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(VitisTheme.accent)
    }

    private func checkSession() async {
        let uid = await AuthService.currentUserId()
        showOnboarding = (uid == nil)
        checked = true
    }

    private func didSignOut() {
        if !AppConstants.authRequired {
            DevSignupService.clearDevUserId()
            ProfileStore.shared.clearForSignOut()
            devSignedOut = true
        } else {
            showOnboarding = true
        }
    }
}
