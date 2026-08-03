//
//  WineListScanView.swift
//  Pari
//
//  Photograph a restaurant wine list and get it back ordered for your palate.
//
//  The room this is used in shapes it: dim light, a waiter waiting, a table
//  watching. So the ranked list is the whole screen with nothing above it to scroll
//  past, unmatched lines are kept and labelled rather than hidden, and re-ranking
//  after the fact costs no network.
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class WineListScanViewModel {
    enum Step {
        case camera
        case reading
        case results([MatchedWineListItem])
        case failed(String)
    }

    var step: Step = .camera

    func process(_ image: UIImage) {
        step = .reading
        Task {
            do {
                let ranked = try await WineListScanService.scanAndRank(image: image)
                step = .results(ranked)
            } catch {
                step = .failed(error.localizedDescription)
            }
        }
    }

    func reset() { step = .camera }
}

struct WineListScanView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    let currentUserId: UUID?

    @State private var viewModel = WineListScanViewModel()
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background(for: colorScheme).ignoresSafeArea()
                content
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            WineListCameraPicker { image in
                showCamera = false
                if let image {
                    viewModel.process(image)
                } else if case .camera = viewModel.step {
                    isPresented = false
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if case .camera = viewModel.step { showCamera = true }
        }
    }

    private var title: String {
        switch viewModel.step {
        case .camera, .reading: return "Wine List"
        case .results: return "Ranked for You"
        case .failed: return "Couldn't Read It"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .camera:
            prompt
        case .reading:
            reading
        case .results(let items):
            resultList(items)
        case .failed(let message):
            failure(message)
        }
    }

    // MARK: - Prompt

    private var prompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(PariTheme.accentWine(for: colorScheme))
            VStack(spacing: 8) {
                Text("Photograph the wine list")
                    .font(.system(.title3, design: .serif, weight: .regular))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                Text("One page at a time reads best.")
                    .font(PariTheme.uiFont(size: 14))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            }
            Button {
                showCamera = true
            } label: {
                Text("Open Camera")
                    .font(PariTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PariTheme.accentWine(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 40)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reading: some View {
        VStack(spacing: 18) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.3)
                .tint(PariTheme.accent(for: colorScheme))
            Text("Reading the list…")
                .font(.system(.body, design: .serif))
                .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            Text(message)
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again") {
                viewModel.reset()
                showCamera = true
            }
            .font(PariTheme.uiFont(size: 15, weight: .medium))
            .foregroundStyle(PariTheme.accent(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results

    private func resultList(_ items: [MatchedWineListItem]) -> some View {
        let matched = items.filter(\.isMatched).count
        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                HStack {
                    Text("\(matched) of \(items.count) found in our catalog")
                        .font(PariTheme.uiFont(size: 12))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                ForEach(items) { item in
                    if let wine = item.wine {
                        NavigationLink {
                            WineCardView(wine: wine, activityId: nil, currentUserId: currentUserId)
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        row(item)
                    }
                    Divider().padding(.leading, 24)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func row(_ item: MatchedWineListItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if let producer = item.displayProducer, !producer.isEmpty {
                    Text(producer)
                        .font(PariTheme.uiFont(size: 12))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                        .lineLimit(1)
                }
                Text(item.displayName)
                    .font(PariTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(item.isMatched
                                     ? PariTheme.textPrimary(for: colorScheme)
                                     : PariTheme.textTertiary(for: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    if let vintage = item.listItem.vintage {
                        Text(String(vintage))
                            .font(PariTheme.uiFont(size: 12))
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    }
                    if let price = item.listItem.price {
                        Text(price)
                            .font(PariTheme.uiFont(size: 12))
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    }
                    if item.listItem.byGlass {
                        Text("by the glass")
                            .font(PariTheme.uiFont(size: 11))
                            .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    }
                }

                if !item.isMatched {
                    // Said plainly. A gap the person can see beats a wine we invented.
                    Text("Not in our catalog yet")
                        .font(PariTheme.uiFont(size: 11))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            if let affinity = item.affinity {
                VStack(spacing: 1) {
                    Text("\(Int((affinity * 100).rounded()))")
                        .font(.system(.body, design: .serif, weight: .medium))
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                    Text("match")
                        .font(PariTheme.uiFont(size: 10))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Camera

private struct WineListCameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
