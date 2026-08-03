//
//  TastingRateView.swift
//  Pari
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
    /// Vintage of the bottle in hand. Stored on the tasting, not the shared catalog row.
    @Binding var vintage: Int?
    /// WSET structural reading. Hidden from novices entirely.
    @Binding var structure: PalateStructure
    var onCheers: () -> Void
    var isEditMode: Bool = false

    @State private var showCamera = false
    @State private var vintageText = ""

    private var wineTypeColor: Color {
        WineColorResolver.resolveWineDisplayColor(wine: wine)
    }

    private var ratingAccentColor: Color {
        PariTheme.ratingColorAdaptive(rating: rating, for: colorScheme)
    }

    private var expertiseTier: ExpertiseTier { ProfileStore.shared.expertiseTier }

    private var availableNotes: [String] {
        TastingNotes.notesForCategory(wine.category, tier: expertiseTier)
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
                // Withheld from novices: someone logging their fourth wine ever does
                // not have the vocabulary yet, and asking anyway teaches them to
                // answer at random, which poisons the signal we are here to collect.
                if expertiseTier != .novice {
                    PalateStructureView(
                        structure: $structure,
                        wineCategory: wine.category,
                        accentColor: wineTypeColor
                    )
                    .padding(.top, 24)
                }
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
        .onAppear {
            // Seed from the tasting being edited, else from the scanned/catalog vintage.
            vintageText = (vintage ?? wine.vintage).map(String.init) ?? ""
            vintage = vintage ?? wine.vintage
        }
    }

    // MARK: - Wine Identity

    private var wineIdentitySection: some View {
        VStack(spacing: 6) {
            Text(wine.producer)
                .font(colorScheme == .dark
                      ? PariTheme.uiFont(size: 13, weight: .regular)
                      : PariTheme.producerSerifFont())
                .foregroundStyle(PariTheme.textTertiary(for: colorScheme))

            Text(wine.name)
                .font(PariTheme.wineNameFont(for: colorScheme))
                .foregroundStyle(colorScheme == .dark
                                 ? PariTheme.wineNameColor(for: colorScheme)
                                 : WineColorResolver.resolveWineDisplayColor(wine: wine))
                .multilineTextAlignment(.center)

            if let r = wine.region {
                Text(r)
                    .font(PariTheme.detailFont())
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
            }

            vintageField
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }

    // MARK: - Vintage

    /// Editable because vintage describes the bottle, not the wine. A catalog row covers
    /// every vintage of a wine, so the year has to come from the person drinking it.
    private var vintageField: some View {
        HStack(spacing: 8) {
            Text("Vintage")
                .font(PariTheme.uiFont(size: 13))
                .foregroundStyle(PariTheme.textTertiary(for: colorScheme))

            TextField("NV", text: $vintageText)
                .font(PariTheme.detailFont())
                .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 68)
                .padding(.vertical, 6)
                .background(PariTheme.backgroundSecondary(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(PariTheme.divider(for: colorScheme), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: vintageText) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(4))
                    if digits != newValue { vintageText = digits }
                    // Partial input (e.g. "20") stays nil rather than committing a bad year.
                    vintage = Int(digits).flatMap { (1800...2100).contains($0) ? $0 : nil }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vintage")
        .accessibilityHint("Enter the year on the bottle, or leave empty for non-vintage")
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

            if expertiseTier == .novice {
                Text("Tap the glasses to set your rating")
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Tasting Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("Tasting Notes")
                    .font(PariTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                Text("— optional")
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
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
                .font(PariTheme.uiFont(size: 14))
                .foregroundStyle(isSelected ? wineTypeColor : PariTheme.secondaryText(for: colorScheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? wineTypeColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? wineTypeColor : PariTheme.divider(for: colorScheme), lineWidth: 1)
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
                    .font(PariTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                Text("— optional · appears in feed")
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
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
                            .font(PariTheme.uiFont(size: 14))
                            .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
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
                            .font(PariTheme.uiFont(size: 14, weight: .medium))
                    }
                    .foregroundStyle(PariTheme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PariTheme.backgroundSecondary(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(PariTheme.divider(for: colorScheme), lineWidth: 1)
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
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $comment)
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    .frame(minHeight: 96, maxHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .onChange(of: comment) { _, newValue in
                        if newValue.count > 500 { comment = String(newValue.prefix(500)) }
                    }
            }
            .background(PariTheme.backgroundSecondary(for: colorScheme))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PariTheme.divider(for: colorScheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Text("\(comment.count)/500")
                    .font(PariTheme.uiFont(size: 11))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
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
                            .font(PariTheme.uiFont(size: 13, weight: .medium))
                    }
                    .foregroundStyle(visibility == option ? wineTypeColor : PariTheme.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(visibility == option ? wineTypeColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(visibility == option ? wineTypeColor : PariTheme.divider(for: colorScheme), lineWidth: 1)
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
                    .font(PariTheme.uiFont(size: 15, weight: .medium))
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
