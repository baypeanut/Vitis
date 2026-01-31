//
//  AddWineSheet.swift
//  Vitis
//
//  Multi-step flow: Search -> Select -> Rate -> Notes -> Save (Cheers).
//

import SwiftUI

enum TastingFlowStep {
    case search
    case rating(Wine)
    case notes(Wine, Double)
}

struct AddWineSheet: View {
    @Binding var isPresented: Bool
    var onWineAdded: () -> Void

    @State private var viewModel = AddWineViewModel()
    @State private var flowStep: TastingFlowStep = .search
    @State private var selectedWine: Wine?
    @State private var rating: Double = 5.0
    @State private var selectedNotes: Set<String> = []
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                contentForStep
                if viewModel.isUpserting || isSaving {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView().progressViewStyle(.circular).tint(VitisTheme.accent).scaleEffect(1.2)
                }
            }
            .alert("Error", isPresented: .constant(saveError != nil)) {
                Button("OK") { saveError = nil }
            } message: {
                if let err = saveError {
                    Text(err)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetFlow()
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accent)
                }
            }
        }
        .onChange(of: viewModel.query) { _, _ in viewModel.search() }
        .onAppear {
            viewModel.prefetchPopular()
            Task { await viewModel.loadDatabaseWines() }
        }
    }

    private var navigationTitle: String {
        switch flowStep {
        case .search: return "Add Wine"
        case .rating: return "Rate"
        case .notes: return "Notes"
        }
    }

    @ViewBuilder
    private var contentForStep: some View {
        switch flowStep {
        case .search:
            searchContent
        case .rating(let wine):
            TastingRateView(wine: wine, rating: $rating) {
                flowStep = .notes(wine, rating)
            }
        case .notes(let wine, let r):
            NotesSelectView(wine: wine, selectedNotes: $selectedNotes) { notes in
                Task {
                    let notesArray = notes.isEmpty ? nil : Array(notes)
                    await saveTasting(wine: wine, rating: r, notes: notesArray)
                }
            } onSkip: {
                Task {
                    await saveTasting(wine: wine, rating: r, notes: nil)
                }
            }
        }
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            searchBar
            Rectangle().fill(VitisTheme.border).frame(height: 1)
            searchResults
        }
    }

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(VitisTheme.secondaryText)
                TextField("Search wines…", text: $viewModel.query)
                    .font(VitisTheme.uiFont(size: 16))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(white: 0.97))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .tint(VitisTheme.accent)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if let err = viewModel.errorMessage {
            Text(err)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            // Show database wines when query is empty
            if viewModel.dbWines.isEmpty {
                Text("No wines in database yet.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.dbWines) { wine in
                            wineRow(wine)
                            Rectangle().fill(VitisTheme.border).frame(height: 1).padding(.leading, 24)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        } else if viewModel.results.isEmpty {
            if viewModel.isLoading {
                Text("Searching…")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No wines found.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.results) { p in
                        row(p)
                        Rectangle().fill(VitisTheme.border).frame(height: 1).padding(.leading, 24)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    private func wineRow(_ wine: Wine) -> some View {
        Button {
            selectedWine = wine
            rating = 5.0
            selectedNotes = []
            flowStep = .rating(wine)
        } label: {
            HStack(alignment: .center, spacing: 16) {
                thumbnail(wine.labelImageURL)
                VStack(alignment: .leading, spacing: 4) {
                    Text(wine.producer)
                        .font(VitisTheme.producerSerifFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                    Text(wine.name)
                        .font(VitisTheme.wineNameFont())
                        .foregroundStyle(WineColorResolver.resolveWineDisplayColor(wine: wine))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    private func row(_ p: OFFProduct) -> some View {
        Button {
            Task {
                do {
                    let wine = try await viewModel.upsert(product: p)
                    selectedWine = wine
                    rating = 5.0
                    selectedNotes = []
                    flowStep = .rating(wine)
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                thumbnail(p.imageUrl)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.brands ?? "Unknown")
                        .font(VitisTheme.producerSerifFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                    Text(p.productName ?? "Unknown")
                        .font(VitisTheme.wineNameFont())
                        .foregroundStyle(WineColorResolver.resolveWineDisplayColor(wineName: p.productName))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUpserting)
    }

    private func thumbnail(_ urlString: String?) -> some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: placeholder
                    }
                }
            } else { placeholder }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(white: 0.94))
            .overlay(Image(systemName: "wineglass.fill").font(.system(size: 20)).foregroundStyle(VitisTheme.secondaryText.opacity(0.6)))
    }

    @MainActor
    private func saveTasting(wine: Wine, rating: Double, notes: [String]?) async {
        guard let userId = await AuthService.currentUserId() else {
            saveError = "Not signed in"
            return
        }
        isSaving = true
        saveError = nil
        do {
            _ = try await TastingService.createTasting(
                userId: userId,
                wineId: wine.id,
                rating: rating,
                noteTags: notes,
                source: "search"
            )
            onWineAdded()
            resetFlow()
            isPresented = false
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    private func resetFlow() {
        flowStep = .search
        selectedWine = nil
        rating = 5.0
        selectedNotes = []
        viewModel.query = ""
        viewModel.results = []
        saveError = nil
    }
}
