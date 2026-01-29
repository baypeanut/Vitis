//
//  AvatarCropSheet.swift
//  Vitis
//
//  Zoom/pan crop. User picks region; circular overlay. Output: JPEG for avatar.
//

import SwiftUI
import UIKit

struct AvatarCropSheet: View {
    let image: UIImage
    var onUse: (Data) -> Void
    var onCancel: () -> Void

    @State private var triggerCrop = false
    private let size: CGFloat = 280

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                ZoomableImageCropView(image: image, triggerCrop: $triggerCrop) { data in
                    onUse(data)
                }
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(VitisTheme.border, lineWidth: 1)
                        .allowsHitTesting(false)
                )
            }
            .frame(width: size, height: size)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)

                Button("Use Photo") {
                    triggerCrop = true
                }
                .font(VitisTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(VitisTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.bottom, 32)
        }
        .padding(.top, 32)
        .frame(maxWidth: .infinity)
        .background(VitisTheme.background)
    }
}
