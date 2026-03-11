//
//  PhotoStepView.swift
//  Pari
//

import SwiftUI
import PhotosUI
import os

struct PhotoStepView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCropSheet = false
    @State private var pickedImage: UIImage?
    @State private var displayAvatarData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "Add your profile photo")

            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    if let data = displayAvatarData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(white: 0.96))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "camera")
                                    .font(.system(size: 32))
                                    .foregroundStyle(PariTheme.secondaryText)
                            )
                    }
                    Circle()
                        .fill(PariTheme.accent)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                        )
                        .offset(x: -4, y: -4)
                }
                .frame(width: 120, height: 120)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .onChange(of: vm.avatarJpegData) { _, new in
                displayAvatarData = new
            }
            .onAppear {
                displayAvatarData = vm.avatarJpegData
            }
            .onChange(of: selectedItem) { _, new in
                Task { await loadPickedImage(new) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showCropSheet) {
            if let img = pickedImage {
                AvatarCropSheet(
                    image: img,
                    onUse: { data in
                        Task { @MainActor in
                            vm.avatarJpegData = data
                            displayAvatarData = data
                            showCropSheet = false
                            pickedImage = nil
                        }
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
            Logger(subsystem: "com.ahmet.vitis", category: "PhotoStep").error("loadPickedImage failed: \(error.localizedDescription)")
        }
        await MainActor.run { selectedItem = nil }
    }
}
