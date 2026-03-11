//
//  RootView.swift
//  Pari
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
    @State private var showLabelScan = false
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
                    PariTheme.background(for: colorScheme).overlay {
                        ProgressView().tint(PariTheme.accent(for: colorScheme))
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
                            .fullScreenCover(isPresented: $showLabelScan) {
                                WineLabelScanView(isPresented: $showLabelScan)
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
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
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
                .tint(PariTheme.accentWine(for: colorScheme))
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(PariTheme.tabBarBackground(for: colorScheme), for: .tabBar)
                .tabBarTheme()

                // Grappe Dorée — button bottom aligns with safe area top (Vivino positioning)
                CentralScanButton(colorScheme: colorScheme) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showLabelScan = true
                }
                .padding(.bottom, geo.safeAreaInsets.bottom)
            }
        }
    }

    private func didSignOut() {
        AnalyticsService.reset()
        Task {
            await AuthStore.shared.signOut()
            ProfileStore.shared.clearForSignOut()
        }
    }
}

// MARK: - Central Action (Grappe Dorée)

private struct CentralScanButton: View {
    let colorScheme: ColorScheme
    let action: () -> Void

    private static let buttonSize: CGFloat = 68
    private static let deepDark    = Color(red: 0x1A / 255, green: 0x11 / 255, blue: 0x08 / 255)
    private static let antiqueGold = Color(red: 0xD4 / 255, green: 0xB8 / 255, blue: 0x96 / 255)

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Self.deepDark)
                    .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
                    .overlay(Circle().stroke(Self.antiqueGold.opacity(0.18), lineWidth: 0.5))

                GrapeClusterIcon(foreground: Self.antiqueGold)
                    .frame(width: Self.buttonSize * 0.52, height: Self.buttonSize * 0.52)
            }
            .frame(width: Self.buttonSize, height: Self.buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(CentralScanButtonStyle())
    }
}

/// Minimalist grape cluster (1-2-3 pyramid) with stem and leaf — antique gold on near-black.
private struct GrapeClusterIcon: View {
    let foreground: Color

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let r: CGFloat  = w * 0.094  // grape radius
            let dy: CGFloat = w * 0.200  // vertical row spacing
            let dx: CGFloat = w * 0.195  // horizontal column spacing

            // Row 3 — 3 grapes (bottom)
            let y3 = h * 0.70
            for x in [cx - dx, cx, cx + dx] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y3 - r, width: r * 2, height: r * 2)),
                         with: .color(foreground))
            }

            // Row 2 — 2 grapes (middle)
            let y2 = y3 - dy
            for x in [cx - dx / 2, cx + dx / 2] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y2 - r, width: r * 2, height: r * 2)),
                         with: .color(foreground))
            }

            // Row 1 — 1 grape (top)
            let y1 = y2 - dy
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: y1 - r, width: r * 2, height: r * 2)),
                     with: .color(foreground))

            // Stem — thin line above top grape
            let stemBottom = y1 - r
            let stemTop    = h * 0.15
            var stem = Path()
            stem.move(to: CGPoint(x: cx, y: stemBottom))
            stem.addLine(to: CGPoint(x: cx, y: stemTop))
            ctx.stroke(stem,
                       with: .color(foreground.opacity(0.62)),
                       style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

            // Leaf — small stroked ellipse branching right from mid-stem
            let leafMidY = (stemBottom + stemTop) / 2 + h * 0.02
            let leafPath = Path(ellipseIn: CGRect(x: cx,
                                                  y: leafMidY - h * 0.044,
                                                  width: w * 0.19,
                                                  height: h * 0.088))
            ctx.stroke(leafPath,
                       with: .color(foreground.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 1.0))
        }
    }
}

private struct CentralScanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
