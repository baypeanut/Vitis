//
//  AddWineSheet.swift
//  Vitis
//
//  Flow: Search -> Select -> Rate (slider + notes + Cheers in one screen).
//

import SwiftUI

enum TastingFlowStep {
    case search
    case rating(Wine)
}

struct AddWineSheet: View {
    @Binding var isPresented: Bool
    var initialWine: Wine? = nil
    var wineIdToRemoveFromWishlist: UUID? = nil
    var onWineAdded: () -> Void

    init(isPresented: Binding<Bool>, initialWine: Wine? = nil, wineIdToRemoveFromWishlist: UUID? = nil, onWineAdded: @escaping () -> Void) {
        _isPresented = isPresented
        self.initialWine = initialWine
        self.wineIdToRemoveFromWishlist = wineIdToRemoveFromWishlist
        self.onWineAdded = onWineAdded
        _flowStep = State(initialValue: initialWine.map { .rating($0) } ?? .search)
        _selectedWine = State(initialValue: initialWine)
    }

    @State private var viewModel = AddWineViewModel()
    @State private var flowStep: TastingFlowStep
    @State private var selectedWine: Wine?
    @State private var rating: Double = 5.0
    @State private var selectedNotes: Set<String> = []
    @State private var comment: String = ""
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
            if initialWine == nil {
                viewModel.prefetchPopular()
                Task { await viewModel.loadDatabaseWines() }
            }
        }
    }

    private var navigationTitle: String {
        switch flowStep {
        case .search: return "Add Wine"
        case .rating: return "Rate"
        }
    }

    @ViewBuilder
    private var contentForStep: some View {
        switch flowStep {
        case .search:
            searchContent
        case .rating(let wine):
            TastingRateView(wine: wine, rating: $rating, selectedNotes: $selectedNotes, comment: $comment) {
                Task {
                    let notesArray = selectedNotes.isEmpty ? nil : Array(selectedNotes)
                    await saveTasting(wine: wine, rating: rating, notes: notesArray, comment: comment)
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
                    if viewModel.hasMorePages {
                        Button {
                            viewModel.loadMoreSearchResults()
                        } label: {
                            HStack {
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                        .tint(VitisTheme.accent)
                                } else {
                                    Text("Show more")
                                        .font(VitisTheme.uiFont(size: 15, weight: .medium))
                                }
                            }
                            .foregroundStyle(VitisTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoadingMore)
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
            comment = ""
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
                    comment = ""
                    flowStep = .rating(wine)
                } catch {
                    viewModel.errorMessage = ErrorMessage.userFacing(for: error)
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
    private func saveTasting(wine: Wine, rating: Double, notes: [String]?, comment: String) async {
        guard let userId = await AuthService.currentUserId() else {
            saveError = ErrorMessage.unauthorized
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
                comment: comment.isEmpty ? nil : comment,
                source: "search"
            )
            if let wid = wineIdToRemoveFromWishlist, wid == wine.id {
                _ = try? await CellarService.removeFromWishlist(wineId: wid)
                NotificationCenter.default.post(name: .vitisWishlistUpdated, object: nil)
            }
            AnalyticsService.tastingCreate(wineId: wine.id, rating: rating)
            onWineAdded()
            resetFlow()
            isPresented = false
        } catch {
            saveError = ErrorMessage.userFacing(for: error)
        }
        isSaving = false
    }

    private func resetFlow() {
        flowStep = .search
        selectedWine = nil
        rating = 5.0
        selectedNotes = []
        comment = ""
        viewModel.query = ""
        viewModel.results = []
        saveError = nil
    }
}
