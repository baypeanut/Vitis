//
//  ProfileSettingsView.swift
//  Vitis
//
//  Settings page with Edit Profile and Sign Out options.
//

import SwiftUI

struct ProfileSettingsView: View {
    var profile: Profile?
    var userId: UUID?
    var onSignOut: () -> Void
    var onProfileUpdated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showEditProfile = false
    @State private var editVM = EditProfileViewModel()
    @State private var showDeleteAccount = false
    @State private var showChangeEmailSheet = false
    @State private var showChangePhoneSheet = false
    @State private var authStore = AuthStore.shared
    
    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                settingsButton(
                    title: "Edit Profile",
                    icon: "pencil",
                    action: {
                        showEditProfile = true
                    }
                )
                
                Rectangle()
                    .fill(VitisTheme.border)
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                phoneNumberRow

                Rectangle()
                    .fill(VitisTheme.border)
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                emailRow
                
                Rectangle()
                    .fill(VitisTheme.border)
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                
                settingsButton(
                    title: "Sign Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    isDestructive: true,
                    action: {
                        dismiss()
                        onSignOut()
                    }
                )
                
                Rectangle()
                    .fill(VitisTheme.border)
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                
                settingsButton(
                    title: "Delete Account",
                    icon: "trash",
                    isDestructive: true,
                    action: {
                        showDeleteAccount = true
                    }
                )
                
                Spacer()
            }
            .padding(.top, 24)
        }
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
        .sheet(isPresented: $showChangeEmailSheet) {
            ChangeEmailView(isPresented: $showChangeEmailSheet)
        }
        .sheet(isPresented: $showChangePhoneSheet) {
            ChangePhoneNumberView(isPresented: $showChangePhoneSheet)
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView(isPresented: $showDeleteAccount) {
                dismiss()
                onSignOut()
            }
        }
        .task { await AuthStore.shared.refreshCurrentUserSnapshot() }
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
    }

    private var emailRow: some View {
        Button {
            showChangeEmailSheet = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "envelope")
                    .font(.system(size: 18))
                    .foregroundStyle(VitisTheme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Email")
                        .font(VitisTheme.uiFont(size: 16))
                        .foregroundStyle(.primary)
                    Text(authStore.userSnapshot?.email ?? "Not added")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.secondaryText.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer()
                Text("Change email")
                    .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(VitisTheme.accent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var phoneNumberRow: some View {
        Button {
            showChangePhoneSheet = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "phone")
                    .font(.system(size: 18))
                    .foregroundStyle(VitisTheme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phone number")
                        .font(VitisTheme.uiFont(size: 16))
                        .foregroundStyle(.primary)
                    Text(authStore.userSnapshot?.phone ?? "Not set")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.secondaryText.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer()
                Text("Change phone number")
                    .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(VitisTheme.accent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsButton(title: String, detail: String? = nil, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isDestructive ? .red : VitisTheme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VitisTheme.uiFont(size: 16))
                        .foregroundStyle(isDestructive ? .red : .primary)
                    if let detail {
                        Text(detail)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
