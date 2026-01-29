//
//  PhotoStepView.swift
//  Vitis
//

import SwiftUI
import PhotosUI

struct PhotoStepView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCropSheet = false
    @State private var pickedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "Add your profile photo")

            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    if let data = vm.avatarJpegData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle()
                            .fill(Color(white: 0.96))
                            .overlay(
                                Image(systemName: "camera")
                                    .font(.system(size: 32))
                                    .foregroundStyle(VitisTheme.secondaryText)
                            )
                    }
                    Circle()
                        .fill(VitisTheme.accent)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 4, y: 4)
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
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
                        vm.avatarJpegData = data
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
        } catch {}
        await MainActor.run { selectedItem = nil }
    }
}
