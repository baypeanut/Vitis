//
//  ProfileSettingsView.swift
//  Vitis
//
//  Settings: Profile, Account, Privacy, Preferences, Danger zone.
//

import SwiftUI

struct ProfileSettingsView: View {
    var profile: Profile?
    var userId: UUID?
    var onSignOut: () -> Void
    var onProfileUpdated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEditProfile = false
    @State private var editVM = EditProfileViewModel()
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccount = false
    @State private var showChangeEmailSheet = false
    @State private var showChangePhoneSheet = false
    @State private var showPrivacySettings = false
    @State private var showNotificationsSettings = false
    @State private var showAppearanceSettings = false
    @State private var showDrinkResponsibly = false
    @State private var showContactSupport = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var authStore = AuthStore.shared
    @Environment(\.openURL) private var openURL
    @State private var notificationsStatusText = "-"
    @State private var privacySettings: PrivacySettings = .default

    private let subtitleOpacity: Double = 0.6

    var body: some View {
        List {
            Section {
                settingsRow(
                    title: "Edit Profile",
                    icon: "pencil",
                    action: { showEditProfile = true }
                )
            } header: {
                Text("Profile")
                    .font(VitisTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            }

            Section {
                settingsRow(
                    title: "Phone number",
                    subtitle: authStore.userSnapshot?.phone ?? "Not set",
                    icon: "phone",
                    trailingAction: "Change",
                    action: { showChangePhoneSheet = true }
                )
                settingsRow(
                    title: "Email",
                    subtitle: authStore.userSnapshot?.email ?? "Not linked",
                    icon: "envelope",
                    trailingAction: authStore.userSnapshot?.email != nil ? "Change" : "Add",
                    action: { showChangeEmailSheet = true }
                )
            } header: {
                Text("Account")
                    .font(VitisTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            }

            Section {
                settingsRow(
                    title: "Privacy settings",
                    subtitle: privacySubtitle,
                    icon: "lock.shield",
                    action: { showPrivacySettings = true }
                )
            } header: {
                Text("Privacy")
                    .font(VitisTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            }

            Section {
                settingsRow(
                    title: "Notifications",
                    subtitle: notificationsSubtitle,
                    icon: "bell",
                    action: { showNotificationsSettings = true }
                )
                settingsRow(
                    title: "Appearance",
                    subtitle: appearanceSubtitle,
                    icon: "paintbrush",
                    action: { showAppearanceSettings = true }
                )
            } header: {
                Text("Preferences")
                    .font(VitisTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            }

            Section {
                settingsRow(
                    title: "Contact Concierge",
                    icon: "envelope.badge",
                    action: { showContactSupport = true }
                )
                settingsRow(
                    title: "Privacy Policy",
                    icon: "hand.raised.fill",
                    action: { showPrivacyPolicy = true }
                )
                settingsRow(
                    title: "Terms of Service",
                    icon: "doc.text",
                    action: { showTermsOfService = true }
                )
                settingsRow(
                    title: "Drink Responsibly",
                    icon: "heart",
                    action: { showDrinkResponsibly = true }
                )
            } header: {
                Text("Legal")
                    .font(VitisTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            }

            Section {
                settingsRow(
                    title: "Sign Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    isDestructive: true,
                    action: {
                        dismiss()
                        onSignOut()
                    }
                )
            }

            Section {
                settingsRow(
                    title: "Delete Account",
                    icon: "trash",
                    isDestructive: true,
                    action: { showDeleteAccountConfirmation = true }
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VitisTheme.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showEditProfile) {
            if let p = profile, let uid = userId {
                EditProfileView(
                    viewModel: editVM,
                    profile: p,
                    userId: uid,
                    onSaved: {
                        showEditProfile = false
                        onProfileUpdated()
                    },
                    onCancel: { showEditProfile = false }
                )
            }
        }
        .navigationDestination(isPresented: $showPrivacySettings) {
            PrivacySettingsView()
        }
        .navigationDestination(isPresented: $showNotificationsSettings) {
            NotificationsSettingsView()
        }
        .navigationDestination(isPresented: $showAppearanceSettings) {
            AppearanceSettingsView()
        }
        .navigationDestination(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .navigationDestination(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showChangeEmailSheet) {
            ChangeEmailView(isPresented: $showChangeEmailSheet)
        }
        .sheet(isPresented: $showChangePhoneSheet) {
            ChangePhoneNumberView(isPresented: $showChangePhoneSheet)
        }
        .confirmationDialog("Delete Account", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                showDeleteAccount = true
            }
            Button("Cancel", role: .cancel) {
                showDeleteAccountConfirmation = false
            }
        } message: {
            Text("This will permanently delete your account and all data. This cannot be undone.")
        }
        .sheet(isPresented: $showDrinkResponsibly) {
            DrinkResponsiblyView { showDrinkResponsibly = false }
        }
        .sheet(isPresented: $showContactSupport) {
            ContactSupportView()
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView(isPresented: $showDeleteAccount) {
                dismiss()
                onSignOut()
            }
        }
        .task {
            await AuthStore.shared.refreshCurrentUserSnapshot()
            notificationsStatusText = await NotificationStatusHelper.fetchStatusText()
            if let uid = userId {
                privacySettings = (try? await ProfileService.fetchPrivacySettings(userId: uid)) ?? .default
            }
        }
        .onChange(of: showChangeEmailSheet) { _, isShown in
            if !isShown {
                Task { await AuthStore.shared.refreshCurrentUserSnapshot() }
            }
        }
        .onChange(of: showChangePhoneSheet) { _, isShown in
            if !isShown {
                Task { await AuthStore.shared.refreshCurrentUserSnapshot() }
            }
        }
        .onChange(of: showPrivacySettings) { _, isShown in
            if !isShown, let uid = userId {
                Task {
                    privacySettings = (try? await ProfileService.fetchPrivacySettings(userId: uid)) ?? .default
                }
            }
        }
    }

    private var privacySubtitle: String {
        "Cellar: \(privacySettings.cellarVisibility.displayName), Wishlist: \(privacySettings.wishlistVisibility.displayName), Activity: \(privacySettings.activityVisibility.displayName)"
    }

    private var notificationsSubtitle: String {
        notificationsStatusText
    }

    private var appearanceSubtitle: String {
        AppearanceStorage.currentDisplayName
    }

    private func settingsRow(
        title: String,
        subtitle: String? = nil,
        icon: String,
        trailingAction: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isDestructive ? VitisTheme.dangerMuted(for: colorScheme) : VitisTheme.accent(for: colorScheme))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VitisTheme.uiFont(size: 16))
                        .foregroundStyle(isDestructive ? VitisTheme.dangerMuted(for: colorScheme) : (colorScheme == .dark ? VitisTheme.textPrimary(for: colorScheme) : Color.primary))
                    if let subtitle {
                        Text(subtitle)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText(for: colorScheme).opacity(subtitleOpacity))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Spacer()
                if let actionText = trailingAction, !isDestructive {
                    Text(actionText)
                        .font(VitisTheme.uiFont(size: 14, weight: .medium))
                        .foregroundStyle(VitisTheme.accent(for: colorScheme))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(colorScheme == .dark ? VitisTheme.textTertiary(for: colorScheme) : VitisTheme.secondaryText(for: colorScheme).opacity(subtitleOpacity))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
