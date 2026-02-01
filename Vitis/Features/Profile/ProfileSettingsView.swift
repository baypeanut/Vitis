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
                
                settingsButton(
                    title: "Sign Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    isDestructive: true,
                    action: {
                        dismiss()
                        onSignOut()
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
    }
    
    private func settingsButton(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isDestructive ? .red : VitisTheme.accent)
                    .frame(width: 24)
                
                Text(title)
                    .font(VitisTheme.uiFont(size: 16))
                    .foregroundStyle(isDestructive ? .red : .primary)
                
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
