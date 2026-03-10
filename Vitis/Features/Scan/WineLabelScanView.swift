//
//  WineLabelScanView.swift
//  Vitis
//
//  Full-screen label scan flow: camera → processing → result → rating → save.
//  Self-contained; embeds TastingRateView for the rating step.
//

import SwiftUI
import UIKit

struct WineLabelScanView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    var onWineAdded: (() -> Void)? = nil

    @State private var viewModel = WineLabelScanViewModel()
    @State private var showImagePicker = false

    // Rating state (used in .rating step)
    @State private var rating: Double = 7.0
    @State private var selectedNotes: Set<String> = []
    @State private var comment: String = ""
    @State private var visibility: TastingVisibility = .everyone
    @State private var momentImageData: Data? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background(for: colorScheme).ignoresSafeArea()
                contentForStep
                if isSaving {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(VitisTheme.accent(for: colorScheme))
                        .scaleEffect(1.2)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.accent(for: colorScheme))
                }
            }
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            CameraPickerView { image in
                showImagePicker = false
                if let image {
                    viewModel.processImage(image)
                } else {
                    isPresented = false
                }
            }
            .ignoresSafeArea()
        }
        .alert("Error", isPresented: .constant(saveError != nil)) {
            Button("OK") { saveError = nil }
        } message: {
            if let err = saveError { Text(err) }
        }
        .onAppear {
            if case .camera = viewModel.step {
                showImagePicker = true
            }
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        switch viewModel.step {
        case .camera, .processing: return "Scan Label"
        case .result:              return "Label Found"
        case .rating:              return "Rate"
        case .notWine:             return "Not a Wine"
        case .error:               return "Scan Failed"
        }
    }

    // MARK: - Step Routing

    @ViewBuilder
    private var contentForStep: some View {
        switch viewModel.step {
        case .camera:
            cameraPlaceholder
        case .processing(let image):
            processingView(image: image)
        case .result(let scan, let wine):
            resultView(scan: scan, wine: wine)
        case .rating(let wine):
            ratingContent(wine: wine)
        case .notWine:
            notWineView
        case .error(let message):
            errorView(message: message)
        }
    }

    // MARK: - Camera Placeholder

    private var cameraPlaceholder: some View {
        VStack(spacing: 28) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(VitisTheme.accentWine(for: colorScheme))
            VStack(spacing: 8) {
                Text("Point at a wine label")
                    .font(.system(.title3, design: .serif, weight: .regular))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                Text("Make sure the label is well-lit and in focus")
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                showImagePicker = true
            } label: {
                Text("Open Camera")
                    .font(VitisTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VitisTheme.accentWine(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Processing View

    private func processingView(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 24)
                .overlay(Color.black.opacity(0.6).ignoresSafeArea())
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Analyzing label…")
                    .font(.system(.body, design: .serif, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(0.5)
            }
        }
    }

    // MARK: - Result View

    private func resultView(scan: LabelScanResult, wine: Wine?) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(VitisTheme.accentWine(for: colorScheme))
                    .padding(.top, 40)

                VStack(alignment: .leading, spacing: 20) {
                    if let name = scan.name {
                        scanField(label: "Wine", value: name, large: true)
                    }
                    if let producer = scan.producer {
                        scanField(label: "Producer", value: producer)
                    }
                    HStack(alignment: .top, spacing: 32) {
                        if let vintage = scan.vintage {
                            scanField(label: "Vintage", value: String(vintage))
                        }
                        if let category = scan.category {
                            scanField(label: "Type", value: category)
                        }
                        if let variety = scan.variety {
                            scanField(label: "Variety", value: variety)
                        }
                    }
                    if let region = scan.region {
                        scanField(label: "Region", value: region)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VitisTheme.surface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    if let wine {
                        Button {
                            viewModel.proceedToRating(wine)
                        } label: {
                            Text("Rate This Wine")
                                .font(VitisTheme.uiFont(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(VitisTheme.accentWine(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 24)
                    } else {
                        // Upsert failed — encourage manual search
                        Text("We couldn't match this label to our catalog. Try searching manually.")
                            .font(VitisTheme.uiFont(size: 14))
                            .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Button {
                        viewModel.reset()
                        showImagePicker = true
                    } label: {
                        Text("Scan Again")
                            .font(VitisTheme.uiFont(size: 15))
                            .foregroundStyle(VitisTheme.accent(for: colorScheme))
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }

    private func scanField(label: String, value: String, large: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(VitisTheme.uiFont(size: 11, weight: .medium))
                .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                .textCase(.uppercase)
                .tracking(1.2)
            if large {
                Text(value)
                    .font(VitisTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(VitisTheme.wineNameColor(for: colorScheme))
            } else {
                Text(value)
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
            }
        }
    }

    // MARK: - Rating Content

    private func ratingContent(wine: Wine) -> some View {
        TastingRateView(
            wine: wine,
            rating: $rating,
            selectedNotes: $selectedNotes,
            comment: $comment,
            visibility: $visibility,
            momentImageData: $momentImageData
        ) {
            Task {
                let notesArray = selectedNotes.isEmpty ? nil : Array(selectedNotes)
                await saveTasting(wine: wine, rating: rating, notes: notesArray, comment: comment, visibility: visibility)
            }
        }
    }

    // MARK: - Not Wine View

    private var notWineView: some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                .padding(.top, 48)
            VStack(spacing: 10) {
                Text("Not a Wine Label")
                    .font(.system(.title3, design: .serif, weight: .regular))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                Text("This doesn't appear to be a wine bottle. Try scanning a wine label.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Button {
                viewModel.reset()
                showImagePicker = true
            } label: {
                Text("Try Another Label")
                    .font(VitisTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VitisTheme.accent(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 40)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(VitisTheme.accentWine(for: colorScheme))
                .padding(.top, 48)
            VStack(spacing: 10) {
                Text("Scan Failed")
                    .font(.system(.title3, design: .serif, weight: .regular))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                Text(message)
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Button {
                viewModel.reset()
                showImagePicker = true
            } label: {
                Text("Try Again")
                    .font(VitisTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VitisTheme.accent(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 40)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Save Tasting

    @MainActor
    private func saveTasting(
        wine: Wine,
        rating: Double,
        notes: [String]?,
        comment: String,
        visibility: TastingVisibility
    ) async {
        guard let userId = await AuthService.currentUserId() else {
            saveError = ErrorMessage.unauthorized
            return
        }
        if !comment.isEmpty, ContentModeration.containsObjectionableContent(comment) {
            saveError = ContentModeration.blockedMessage
            return
        }
        isSaving = true
        saveError = nil
        var momentURL: String?
        if let data = momentImageData {
            momentURL = try? await MomentStorageService.uploadMoment(userId: userId, jpegData: data)
        }
        let countBefore = await TastingService.fetchTastingsCount(userId: userId)
        do {
            _ = try await TastingService.createTasting(
                userId: userId,
                wineId: wine.id,
                rating: rating,
                noteTags: notes,
                comment: comment.isEmpty ? nil : comment,
                source: "scan",
                visibility: visibility,
                momentImageURL: momentURL
            )
            AnalyticsService.tastingCreate(wineId: wine.id, rating: rating)
            if countBefore == 0 {
                AnalyticsService.firstTastingSaved(wineId: wine.id, rating: rating)
            }
            onWineAdded?()
            isPresented = false
        } catch {
            saveError = ErrorMessage.userFacing(for: error)
        }
        isSaving = false
    }
}

// MARK: - Camera Picker

private struct CameraPickerView: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onImagePicked(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
        }
    }
}
