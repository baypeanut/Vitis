//
//  RootView.swift
//  Vitis
//
//  Auth gate: phone OTP + profile setup. Restores session if available.
//

import SwiftUI

enum Tab {
    case social, cellar, notifications, profile
}

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearance_preference") private var appearanceRaw = AppearanceOption.system.rawValue
    @AppStorage("vitis_age_verified") private var ageVerified = false
    @AppStorage("vitis_drink_responsibly_shown") private var drinkResponsiblyShown = false
    @State private var selectedTab: Tab = .social
    @State private var authStore = AuthStore.shared
    @State private var showAddWineFromCarousel = false
    @State private var showDrinkResponsibly = false
    @ObservedObject private var recovery = AuthRecoveryState.shared

    var body: some View {
        Group {
            if !ageVerified {
                AgeGateView {
                    ageVerified = true
                    if !drinkResponsiblyShown {
                        showDrinkResponsibly = true
                    }
                }
            } else {
                switch authStore.state {
                case .checking:
                    VitisTheme.background(for: colorScheme).overlay {
                        ProgressView().tint(VitisTheme.accent(for: colorScheme))
                    }
                    .ignoresSafeArea()
                case .unauthenticated:
                    PhoneEntryView()
                case .awaitingCode(let phone):
                    CodeEntryView(phoneDisplay: phone)
                case .authenticated(let userId):
                    if authStore.needsProfileSetup {
                        ProfileSetupView(userId: userId)
                    } else {
                        mainTabs
                            .fullScreenCover(isPresented: $showAddWineFromCarousel) {
                                AddWineSheet(
                                    isPresented: $showAddWineFromCarousel,
                                    onWineAdded: { showAddWineFromCarousel = false }
                                )
                            }
                    }
                }
            }
        }
        .sheet(isPresented: $showDrinkResponsibly) {
            DrinkResponsiblyView {
                drinkResponsiblyShown = true
                showDrinkResponsibly = false
            }
            .interactiveDismissDisabled(true)
        }
        .task {
            if !authStore.sessionRestored {
                await authStore.restoreSession()
                if case .authenticated = authStore.state {
                    await ProfileStore.shared.load()
                }
            }
        }
        .onChange(of: authStore.state) { _, newState in
            if case .authenticated = newState {
                Task { await ProfileStore.shared.load() }
                if ageVerified, case .authenticated(let uid) = newState {
                    Task { try? await ProfileService.updateAgeVerified(userId: uid) }
                }
            }
        }
        .onChange(of: ageVerified) { _, newValue in
            if newValue, case .authenticated(let uid) = authStore.state {
                Task { try? await ProfileService.updateAgeVerified(userId: uid) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSwitchToCellarTab)) { _ in
            selectedTab = .cellar
        }
        .fullScreenCover(isPresented: Binding(
            get: { recovery.showNewPasswordView },
            set: { if !$0 { recovery.dismissRecovery() } }
        )) {
            NewPasswordView(onComplete: {
                recovery.dismissRecovery()
            })
        }
        .sheet(item: Binding(
            get: { authStore.authResultEvent },
            set: { authStore.authResultEvent = $0 }
        )) { event in
            ConfirmationSheetView(event: event) {
                authStore.authResultEvent = nil
            }
        }
        .preferredColorScheme(AppearanceStorage.resolvedColorScheme(for: appearanceRaw))
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            // 1. Feed — social activity stream is the heartbeat of the app
            SocialView()
                .tabItem { Image(systemName: "newspaper") }
                .tag(Tab.social)
            // 2. Cellar — personal collection
            NavigationStack {
                CellarView()
            }
            .tabItem { Image(systemName: "wineglass") }
            .tag(Tab.cellar)
            // 3. Notifications
            NotificationsView()
                .tabItem { Image(systemName: "bell") }
                .tag(Tab.notifications)
            // 4. Profile
            ProfileView(onSignOut: didSignOut)
                .tabItem { Image(systemName: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .tint(VitisTheme.accentWine(for: colorScheme))
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(VitisTheme.tabBarBackground(for: colorScheme), for: .tabBar)
        .tabBarTheme()
    }

    private func didSignOut() {
        AnalyticsService.reset()
        Task {
            await AuthStore.shared.signOut()
            ProfileStore.shared.clearForSignOut()
        }
    }
}
