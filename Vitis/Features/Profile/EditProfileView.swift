//
//  EditProfileView.swift
//  Pari
//
//  Edit profile: photo, bio (0/140), Loves/Avoids/Mood, Weekly goal, Instagram handle.
//

import SwiftUI
import PhotosUI
import os

struct EditProfileView: View {
    @Bindable var viewModel: EditProfileViewModel
    var profile: Profile
    var userId: UUID
    var onSaved: () -> Void
    var onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var showCropSheet = false
    @State private var pickedImage: UIImage?

    var body: some View {
            ZStack {
                PariTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let e = viewModel.saveError {
                            Text(e)
                                .font(PariTheme.uiFont(size: 13))
                                .foregroundStyle(.red)
                        }
                        avatarSection
                        usernameSection
                        fullNameSection
                        bioSection
                        tasteSection
                        socialSection
                        PrimaryButton("Save", enabled: canSave && !viewModel.isSaving) {
                            Task { await save() }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                if viewModel.isSaving {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.2)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.apply(profile: profile) }
            .onChange(of: selectedItem) { _, new in
                Task { await loadPickedImage(new) }
            }
            .sheet(isPresented: $showCropSheet) {
                if let img = pickedImage {
                    AvatarCropSheet(
                        image: img,
                        onUse: { data in
                            viewModel.avatarJpegData = data
                            showCropSheet = false
                            pickedImage = nil
                        },
                        onCancel: {
                            showCropSheet = false
                            pickedImage = nil
                            selectedItem = nil
                        }
                    )
                }
            }
    }

    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile photo")
                .font(PariTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(PariTheme.secondaryText)
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    avatarImage
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                    Circle()
                        .fill(PariTheme.accent)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        )
                        .offset(x: -4, y: -4)
                }
                .frame(width: 88, height: 88)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let data = viewModel.avatarJpegData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let u = profile.avatarURL, let url = URL(string: u) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                default: avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(PariTheme.secondaryText)
            )
            .frame(width: 88, height: 88)
    }

    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await MainActor.run {
                    pickedImage = img
                    showCropSheet = true
                }
            }
        } catch {
            Logger(subsystem: "com.ahmet.vitis", category: "EditProfile").error("loadPickedImage failed: \(error.localizedDescription)")
        }
        await MainActor.run { selectedItem = nil }
    }

    private var canSave: Bool {
        !viewModel.bioOverLimit && !viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Username")
                .font(PariTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(PariTheme.secondaryText)
            UnderlineTextField(
                placeholder: "username",
                text: $viewModel.username,
                keyboardType: .default,
                textContentType: .username,
                autocapitalization: .never
            )
        }
    }

    private var fullNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Name")
                .font(PariTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(PariTheme.secondaryText)
            UnderlineTextField(
                placeholder: "Full name (optional)",
                text: $viewModel.fullName,
                keyboardType: .default,
                textContentType: .name,
                autocapitalization: .words
            )
        }
    }

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bio")
                .font(PariTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(PariTheme.secondaryText)
            TextEditor(text: $viewModel.bio)
                .font(PariTheme.uiFont(size: 16))
                .frame(minHeight: 80)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PariTheme.border, lineWidth: 1))
                .onChange(of: viewModel.bio) { _, _ in
                    if viewModel.bio.count > viewModel.bioLimit {
                        viewModel.bio = String(viewModel.bio.prefix(viewModel.bioLimit))
                    }
                }
            HStack {
                Spacer()
                Text("\(viewModel.bioCount)/\(viewModel.bioLimit)")
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(viewModel.bioOverLimit ? .red : PariTheme.secondaryText)
            }
        }
    }

    private var tasteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Taste Snapshot")
                .font(PariTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(PariTheme.secondaryText)
            VStack(alignment: .leading, spacing: 8) {
                pickerRow("Loves", selection: $viewModel.lovesId, options: TasteSnapshotOptions.loves)
                pickerRow("Avoids", selection: $viewModel.avoidsId, options: TasteSnapshotOptions.avoids)
                pickerRow("Current mood", selection: $viewModel.moodId, options: TasteSnapshotOptions.mood)
            }
        }
    }

    private func pickerRow(_ label: String, selection: Binding<String>, options: [(id: String, label: String)]) -> some View {
        HStack {
            Text(label)
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(.primary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.id) { o in
                    Text(o.label).tag(o.id)
                }
            }
            .pickerStyle(.menu)
            .tint(PariTheme.accent)
        }
        .padding(.vertical, 8)
    }

    private var socialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instagram")
                .font(PariTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(PariTheme.secondaryText)
            UnderlineTextField(
                placeholder: "@username",
                text: $viewModel.instagramHandleInput,
                keyboardType: .default,
                textContentType: .username,
                autocapitalization: .never
            )
        }
    }

    private func save() async {
        await viewModel.save(userId: userId)
        if viewModel.saveError == nil {
            dismiss()
            onSaved()
        }
    }
}
