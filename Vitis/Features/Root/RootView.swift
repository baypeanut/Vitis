//
//  RootView.swift
//  Vitis
//
//  Auth gate: when authRequired, show OnboardingFlowView when not signed in; else TabView.
//  Dev (authRequired = false): main tabs + guest/mock. Sign out → onboarding (test sign-up).
//

import SwiftUI

enum Tab {
    case cellar, social, notifications, profile
}

struct RootView: View {
    @State private var showOnboarding = true
    @State private var checked = false
    /// Dev mode: sign out → true → show onboarding to test sign-up.
    @State private var devSignedOut = false
    @State private var selectedTab: Tab = .cellar
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
        TabView(selection: $selectedTab) {
            CellarView()
                .tabItem { Label("Cellar", systemImage: "square.stack") }
                .tag(Tab.cellar)
            SocialView()
                .tabItem { Label("Social", systemImage: "person.2") }
                .tag(Tab.social)
            NotificationsView()
                .tabItem { Label("Notifications", systemImage: "bell") }
                .tag(Tab.notifications)
            ProfileView(onSignOut: didSignOut)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .tint(VitisTheme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .vitisSwitchToCellarTab)) { _ in
            selectedTab = .cellar
        }
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
