//
//  ProfileView.swift
//  Vitis
//
//  My profile tab. Beli-style layout via ProfileContentView. Edit → EditProfileView page.
//

import SwiftUI

private struct DrillDownTarget: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let filterType: TasteProfileDrillDownView.FilterType
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DrillDownTarget, rhs: DrillDownTarget) -> Bool {
        lhs.id == rhs.id
    }
}

struct ProfileView: View {
    var onSignOut: () -> Void

    @State private var viewModel: ProfileViewModel?
    @State private var currentUserId: UUID?
    @State private var didRunEnsure = false
    @State private var showFollowersFollowing = false
    @State private var followersFollowingInitialTab: FollowersFollowingView.Tab = .followers
    @State private var drillDownTarget: DrillDownTarget?
    @State private var showSettings = false
    @State private var showWantToTry = false
    @State private var markAsTastedItem: CellarItem?

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                if !didRunEnsure {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(VitisTheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let vm = viewModel, vm.profile != nil {
                    ProfileContentView(
                        viewModel: vm,
                        isOwn: true,
                        isFollowing: false,
                        onSignOut: { Task { await signOut() } },
                        onFollowersTap: { followersFollowingInitialTab = .followers; showFollowersFollowing = true },
                        onFollowingTap: { followersFollowingInitialTab = .following; showFollowersFollowing = true },
                        onRegionTap: { drillDownTarget = DrillDownTarget(title: $0, filterType: .region($0)) },
                        onGrapeTap: { drillDownTarget = DrillDownTarget(title: $0, filterType: .grape($0)) },
                        onRatedTap: { NotificationCenter.default.post(name: .vitisSwitchToCellarTab, object: nil) },
                        onWantToTryTap: { showWantToTry = true },
                        onWantToTryToggle: nil,
                        onRemoveWishlistItem: { item in await vm.removeFromWishlist(item) },
                        onMarkAsTasted: { markAsTastedItem = $0 }
                    )
                } else {
                    VStack(spacing: 16) {
                        Text(viewModel?.errorMessage ?? "Could not load profile.")
                            .font(VitisTheme.uiFont(size: 14))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                        Button("Sign out") { Task { await signOut() } }
                            .font(VitisTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(VitisTheme.accent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(viewModel?.profile?.displayName ?? "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18))
                            .foregroundStyle(VitisTheme.accent)
                    }
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                ProfileSettingsView(
                    profile: viewModel?.profile,
                    userId: currentUserId,
                    onSignOut: { Task { await signOut() } },
                    onProfileUpdated: {
                        Task {
                            await viewModel?.load()
                            await ProfileStore.shared.load()
                            NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
                        }
                    }
                )
            }
            .sheet(item: $drillDownTarget) { target in
                NavigationStack {
                    TasteProfileDrillDownView(
                        title: target.title,
                        filterType: target.filterType,
                        tastings: viewModel?.allTastings ?? [],
                        currentUserId: currentUserId
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { drillDownTarget = nil }
                                .font(VitisTheme.uiFont(size: 15))
                                .foregroundStyle(VitisTheme.accent)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showWantToTry) {
                if let uid = viewModel?.userId {
                    WantToTryView(userId: uid, onDismiss: { showWantToTry = false })
                }
            }
            .sheet(item: $markAsTastedItem) { item in
                AddWineSheet(
                    isPresented: Binding(get: { markAsTastedItem != nil }, set: { if !$0 { markAsTastedItem = nil } }),
                    initialWine: item.wine,
                    wineIdToRemoveFromWishlist: item.wineId,
                    onWineAdded: {
                        markAsTastedItem = nil
                        Task { await viewModel?.load() }
                    }
                )
            }
            .navigationDestination(isPresented: $showFollowersFollowing) {
                if let vm = viewModel, let uid = currentUserId {
                    FollowersFollowingViewContent(
                        userId: vm.userId,
                        currentUserId: uid,
                        initialTab: followersFollowingInitialTab
                    ) {
                        Task { await vm.load() }
                    }
                }
            }
        }
        .task { await ensureAndLoad() }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSessionReady)) { _ in
            Task { await ensureAndLoad() }
        }
        .refreshable { await ensureAndLoad() }
    }

    private func ensureAndLoad() async {
        let uid = await AuthService.currentUserId()
        currentUserId = uid
        didRunEnsure = true
        guard let uid else {
            await ProfileStore.shared.load()
            viewModel = nil
            return
        }
        if viewModel?.userId != uid {
            viewModel = ProfileViewModel(userId: uid)
        }
        await viewModel?.load()
    }

    private func signOut() async {
        try? await AuthService.signOut()
        onSignOut()
    }
}
