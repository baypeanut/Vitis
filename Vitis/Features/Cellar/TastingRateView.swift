//
//  TastingRateView.swift
//  Vitis
//
//  Single-page rating flow: wine identity, rating, notes, moment, comment, visibility.
//

import SwiftUI
import UIKit

struct TastingRateView: View {
    @Environment(\.colorScheme) private var colorScheme
    let wine: Wine
    @Binding var rating: Double
    @Binding var selectedNotes: Set<String>
    @Binding var comment: String
    @Binding var visibility: TastingVisibility
    @Binding var momentImageData: Data?
    var onCheers: () -> Void
    var isEditMode: Bool = false

    @State private var showCamera = false

    private var wineTypeColor: Color {
        WineColorResolver.resolveWineDisplayColor(wine: wine)
    }

    private var ratingAccentColor: Color {
        VitisTheme.ratingColorAdaptive(rating: rating, for: colorScheme)
    }

    private var availableNotes: [String] {
        TastingNotes.notesForCategory(wine.category)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                wineIdentitySection
                ratingSection
                    .padding(.top, 36)
                Divider()
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                notesSection
                    .padding(.top, 24)
                momentPhotoSection
                    .padding(.top, 24)
                commentSection
                    .padding(.top, 24)
                visibilityPicker
                    .padding(.top, 24)
                saveButton
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Wine Identity

    private var wineIdentitySection: some View {
        VStack(spacing: 6) {
            Text(wine.producer)
                .font(colorScheme == .dark
                      ? VitisTheme.uiFont(size: 13, weight: .regular)
                      : VitisTheme.producerSerifFont())
                .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))

            Text(wine.name)
                .font(VitisTheme.wineNameFont(for: colorScheme))
                .foregroundStyle(colorScheme == .dark
                                 ? VitisTheme.wineNameColor(for: colorScheme)
                                 : WineColorResolver.resolveWineDisplayColor(wine: wine))
                .multilineTextAlignment(.center)

            if let v = wine.vintage {
                Text(String(v))
                    .font(VitisTheme.detailFont())
                    .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
            }
            if let r = wine.region {
                Text(r)
                    .font(VitisTheme.detailFont())
                    .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }

    // MARK: - Rating

    private var ratingSection: some View {
        VStack(spacing: 16) {
            WineGlassRatingView(
                rating: $rating,
                accentColor: ratingAccentColor,
                size: 38
            )
            .padding(.horizontal, 8)

            Text(WineGlassRatingView.ratingLabel(rating))
                .font(.system(.title2, design: .serif, weight: colorScheme == .dark ? .medium : .regular))
                .foregroundStyle(ratingAccentColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.12), value: rating)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Tasting Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("Tasting Notes")
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                Text("— optional")
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(availableNotes, id: \.self) { note in
                    noteChip(note)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private func noteChip(_ note: String) -> some View {
        let isSelected = selectedNotes.contains(note)
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                if selectedNotes.contains(note) {
                    selectedNotes.remove(note)
                } else {
                    selectedNotes.insert(note)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        } label: {
            Text(note)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(isSelected ? wineTypeColor : VitisTheme.secondaryText(for: colorScheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? wineTypeColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? wineTypeColor : VitisTheme.divider(for: colorScheme), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(note), selected" : note)
        .accessibilityHint(isSelected ? "Double tap to deselect" : "Double tap to select")
    }

    // MARK: - Capture Now (instant camera only)

    private var momentPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("Capture Now")
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                Text("— optional · appears in feed")
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
            }
            if let data = momentImageData, let ui = UIImage(data: data) {
                HStack(spacing: 12) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        momentImageData = nil
                    } label: {
                        Text("Remove")
                            .font(VitisTheme.uiFont(size: 14))
                            .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showCamera = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16))
                        Text("Capture Now")
                            .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    }
                    .foregroundStyle(VitisTheme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(VitisTheme.backgroundSecondary(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(VitisTheme.divider(for: colorScheme), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(
                onCapture: { data in
                    momentImageData = data
                    showCamera = false
                },
                onCancel: {
                    showCamera = false
                }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Comment

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if comment.isEmpty {
                    Text("What did you think?")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $comment)
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                    .frame(minHeight: 96, maxHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .onChange(of: comment) { _, newValue in
                        if newValue.count > 500 { comment = String(newValue.prefix(500)) }
                    }
            }
            .background(VitisTheme.backgroundSecondary(for: colorScheme))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(VitisTheme.divider(for: colorScheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Text("\(comment.count)/500")
                    .font(VitisTheme.uiFont(size: 11))
                    .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Visibility Picker

    private var visibilityPicker: some View {
        HStack(spacing: 0) {
            ForEach(TastingVisibility.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { visibility = option }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.icon)
                            .font(.system(size: 13))
                        Text(option.displayName)
                            .font(VitisTheme.uiFont(size: 13, weight: .medium))
                    }
                    .foregroundStyle(visibility == option ? wineTypeColor : VitisTheme.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(visibility == option ? wineTypeColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(visibility == option ? wineTypeColor : VitisTheme.divider(for: colorScheme), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Post visibility")
        .padding(.horizontal, 24)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            onCheers()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isEditMode ? "checkmark" : "wineglass.fill")
                    .font(.system(size: 14))
                Text(isEditMode ? "Save" : "Save Tasting")
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(CheersButtonStyle(accentColor: ratingAccentColor))
        .padding(.horizontal, 24)
    }
}

// MARK: - Cheers button pressed state

private struct CheersButtonStyle: ButtonStyle {
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(accentColor)
            .overlay(configuration.isPressed ? Color.black.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - BeReal-style instant camera (no gallery)

private struct CameraCaptureView: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.85) else { return }
            onCapture(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
