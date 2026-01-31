//
//  ProfileView.swift
//  Vitis
//
//  My profile tab. Beli-style layout via ProfileContentView. Edit → EditProfileView sheet.
//

import SwiftUI

private struct DrillDownTarget: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let isGrape: Bool
}

struct ProfileView: View {
    var onSignOut: () -> Void

    @State private var viewModel: ProfileViewModel?
    @State private var currentUserId: UUID?
    @State private var didRunEnsure = false
    @State private var showEditSheet = false
    @State private var editVM = EditProfileViewModel()
    @State private var showFollowersFollowingSheet = false
    @State private var followersFollowingInitialTab: FollowersFollowingView.Tab = .followers
    @State private var drillDownTarget: DrillDownTarget?

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
                        onEdit: { showEditSheet = true },
                        onSignOut: { Task { await signOut() } },
                        onFollowersTap: { followersFollowingInitialTab = .followers; showFollowersFollowingSheet = true },
                        onFollowingTap: { followersFollowingInitialTab = .following; showFollowersFollowingSheet = true },
                        onGrapeTap: { drillDownTarget = DrillDownTarget(title: $0, isGrape: true) },
                        onRegionTap: { drillDownTarget = DrillDownTarget(title: $0, isGrape: false) }
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .navigationDestination(item: $drillDownTarget) { target in
            TasteProfileDrillDownView(
                title: target.title,
                filterType: target.isGrape ? .grape(target.title) : .region(target.title),
                tastings: viewModel?.allTastings ?? []
            )
        }
        .task { await ensureAndLoad() }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSessionReady)) { _ in
            Task { await ensureAndLoad() }
        }
        .refreshable { await ensureAndLoad() }
        .sheet(isPresented: $showFollowersFollowingSheet) {
            if let vm = viewModel, let uid = currentUserId {
                FollowersFollowingView(
                    userId: vm.userId,
                    currentUserId: uid,
                    initialTab: followersFollowingInitialTab,
                    onDismiss: { showFollowersFollowingSheet = false }
                ) {
                    Task { await vm.load() }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let vm = viewModel, let p = vm.profile, let uid = currentUserId {
                EditProfileView(
                    viewModel: editVM,
                    profile: p,
                    userId: uid,
                    onSaved: {
                        showEditSheet = false
                        Task {
                            await vm.load()
                            await ProfileStore.shared.load()
                            NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
                        }
                    },
                    onCancel: { showEditSheet = false }
                )
            }
        }
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
