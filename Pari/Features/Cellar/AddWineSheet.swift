//
//  AddWineSheet.swift
//  Pari
//
//  Flow: Search -> Select -> Rate (slider + notes + Cheers in one screen).
//

import SwiftUI

enum TastingFlowStep {
    case search
    case rating(Wine)
}

struct AddWineSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    var initialWine: Wine? = nil
    var wineIdToRemoveFromWishlist: UUID? = nil
    var wishlistOnlyMode: Bool = false
    var addToCellarStatus: CellarItem.CellarStatus? = nil
    var wishlistWineIds: Set<UUID> = []
    var tastedWineIds: Set<UUID> = []
    var onWineAdded: () -> Void

    init(
        isPresented: Binding<Bool>,
        initialWine: Wine? = nil,
        wineIdToRemoveFromWishlist: UUID? = nil,
        wishlistOnlyMode: Bool = false,
        addToCellarStatus: CellarItem.CellarStatus? = nil,
        wishlistWineIds: Set<UUID> = [],
        tastedWineIds: Set<UUID> = [],
        onWineAdded: @escaping () -> Void
    ) {
        _isPresented = isPresented
        self.initialWine = initialWine
        self.wineIdToRemoveFromWishlist = wineIdToRemoveFromWishlist
        self.wishlistOnlyMode = wishlistOnlyMode
        self.addToCellarStatus = addToCellarStatus
        self.wishlistWineIds = wishlistWineIds
        self.tastedWineIds = tastedWineIds
        self.onWineAdded = onWineAdded
        _flowStep = State(initialValue: initialWine.map { .rating($0) } ?? .search)
        _selectedWine = State(initialValue: initialWine)
    }

    @State private var viewModel = AddWineViewModel()
    @State private var flowStep: TastingFlowStep
    @State private var selectedWine: Wine?
    @State private var rating: Double = 7.0
    @State private var selectedNotes: Set<String> = []
    @State private var comment: String = ""
    @State private var visibility: TastingVisibility = .everyone
    @State private var momentImageData: Data? = nil
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showLabelScan = false

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background.ignoresSafeArea()
                contentForStep
                if viewModel.isUpserting || isSaving {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView().progressViewStyle(.circular).tint(PariTheme.accent).scaleEffect(1.2)
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
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.accent)
                }
            }
        }
        .fullScreenCover(isPresented: $showLabelScan) {
            WineLabelScanView(isPresented: $showLabelScan) {
                onWineAdded()
                resetFlow()
                isPresented = false
            }
        }
        .onChange(of: viewModel.query) { _, _ in viewModel.search() }
        .onAppear {
            if case .rating = flowStep { AnalyticsService.firstTastingStarted() }
        }
    }

    private var navigationTitle: String {
        if wishlistOnlyMode { return "Add to Reserve List" }
        if addToCellarStatus == .had { return "Add to Had" }
        if addToCellarStatus == .wishlist { return "Add to Wishlist" }
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
            TastingRateView(wine: wine, rating: $rating, selectedNotes: $selectedNotes, comment: $comment, visibility: $visibility, momentImageData: $momentImageData) {
                Task {
                    let notesArray = selectedNotes.isEmpty ? nil : Array(selectedNotes)
                    await saveTasting(wine: wine, rating: rating, notes: notesArray, comment: comment, visibility: visibility)
                }
            }
        }
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            searchBar
            Rectangle().fill(PariTheme.border).frame(height: 1)
            searchResults
        }
    }

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(PariTheme.secondaryText)
                TextField("Search wines…", text: $viewModel.query)
                    .font(PariTheme.uiFont(size: 16))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showLabelScan = true
                } label: {
                    Text("V")
                        .font(.system(size: 18, weight: .light, design: .serif))
                        .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(colorScheme == .dark
                ? PariTheme.surface(for: colorScheme)
                : Color(white: 0.95))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .tint(PariTheme.accent)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let trimmed = viewModel.query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Empty state: invite to search — no list
            VStack(spacing: 12) {
                Text("Search by name, producer, or region")
                    .font(.system(.body, design: .serif, weight: .regular))
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                Text("Find your next bottle")
                    .font(.system(.subheadline, design: .serif, weight: .regular))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
        } else if viewModel.isSearchingOrPending {
            // Still debouncing or request in flight — show searching, never "No wines found"
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
                    .tint(PariTheme.accent(for: colorScheme))
                Text("Searching…")
                    .font(.system(.subheadline, design: .serif, weight: .regular))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.searchCompletedForCurrentQuery && viewModel.dbSearchResults.isEmpty {
            Text("No wines found. Try another search or add the wine from our catalog.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.dbSearchResults) { wine in
                        wineRow(wine)
                        Rectangle().fill(PariTheme.border).frame(height: 1).padding(.leading, 24)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    private func wineRow(_ wine: Wine) -> some View {
        let state = rowState(wineId: wine.id)
        let isTasted = tastedWineIds.contains(wine.id)
        return Button {
            // Don't allow selecting already tasted wines in regular mode
            if !wishlistOnlyMode && addToCellarStatus == nil && isTasted {
                return
            }
            if let status = addToCellarStatus {
                Task { await handleCellarSelect(wine: wine, status: status) }
            } else if wishlistOnlyMode {
                Task { await handleWishlistSelect(wine: wine) }
            } else {
                selectedWine = wine
                rating = 7.0
                selectedNotes = []
                comment = ""
                flowStep = .rating(wine)
                AnalyticsService.firstTastingStarted()
            }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                thumbnail(wine.labelImageURL)
                VStack(alignment: .leading, spacing: 4) {
                    Text(wine.producer)
                        .font(colorScheme == .dark ? PariTheme.uiFont(size: 13, weight: .regular) : PariTheme.producerSerifFont())
                        .foregroundStyle(colorScheme == .dark ? PariTheme.textTertiary(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                    Text(wine.name)
                        .font(PariTheme.wineNameFont(for: colorScheme))
                        .foregroundStyle(colorScheme == .dark ? PariTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(wine: wine))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let state {
                    Text(state)
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .disabled(state != nil)
    }

    private func row(_ p: OFFProduct) -> some View {
        Button {
            Task {
                do {
                    let wine = try await viewModel.upsert(product: p)
                    // Check if wine has been tasted after upserting
                    if !wishlistOnlyMode && addToCellarStatus == nil && tastedWineIds.contains(wine.id) {
                        return
                    }
                    if let status = addToCellarStatus {
                        await handleCellarSelect(wine: wine, status: status)
                    } else if wishlistOnlyMode {
                        await handleWishlistSelect(wine: wine)
                    } else {
                        selectedWine = wine
                        rating = 7.0
                        selectedNotes = []
                        comment = ""
                        flowStep = .rating(wine)
                        AnalyticsService.firstTastingStarted()
                    }
                } catch {
                    viewModel.errorMessage = ErrorMessage.userFacing(for: error)
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                thumbnail(p.imageUrl)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.brands ?? "Unknown")
                        .font(colorScheme == .dark ? PariTheme.uiFont(size: 13, weight: .regular) : PariTheme.producerSerifFont())
                        .foregroundStyle(colorScheme == .dark ? PariTheme.textTertiary(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                    Text(p.productName ?? "Unknown")
                        .font(PariTheme.wineNameFont(for: colorScheme))
                        .foregroundStyle(colorScheme == .dark ? PariTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(wineName: p.productName))
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
            .overlay(Image(systemName: "wineglass.fill").font(.system(size: 20)).foregroundStyle(PariTheme.secondaryText.opacity(0.6)))
    }

    @MainActor
    private func saveTasting(wine: Wine, rating: Double, notes: [String]?, comment: String, visibility: TastingVisibility = .everyone) async {
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
                source: "search",
                visibility: visibility,
                momentImageURL: momentURL
            )
            if let wid = wineIdToRemoveFromWishlist, wid == wine.id {
                _ = try? await CellarService.removeFromWishlist(wineId: wid)
                NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
            }
            AnalyticsService.tastingCreate(wineId: wine.id, rating: rating)
            if countBefore == 0 {
                AnalyticsService.firstTastingSaved(wineId: wine.id, rating: rating)
            }
            onWineAdded()
            resetFlow()
            isPresented = false
        } catch {
            saveError = ErrorMessage.userFacing(for: error)
        }
        isSaving = false
    }

    private func rowState(wineId: UUID) -> String? {
        if tastedWineIds.contains(wineId) { return "Tasted" }
        if wishlistOnlyMode && wishlistWineIds.contains(wineId) { return "Saved" }
        return nil
    }

    @MainActor
    private func handleCellarSelect(wine: Wine, status: CellarItem.CellarStatus) async {
        guard let uid = await AuthService.currentUserId() else {
            saveError = ErrorMessage.unauthorized
            return
        }
        isSaving = true
        saveError = nil
        do {
            try await CellarService.addToCellar(userId: uid, wineId: wine.id, status: status)
            NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
            onWineAdded()
            resetFlow()
            isPresented = false
        } catch {
            saveError = ErrorMessage.userFacing(for: error)
        }
        isSaving = false
    }

    @MainActor
    private func handleWishlistSelect(wine: Wine) async {
        if tastedWineIds.contains(wine.id) { return }
        if wishlistWineIds.contains(wine.id) { return }
        guard await AuthService.currentUserId() != nil else {
            saveError = ErrorMessage.unauthorized
            return
        }
        isSaving = true
        saveError = nil
        do {
            try await CellarService.addToWishlist(wineId: wine.id, sourceUserId: nil, sourceContext: "profile")
            AnalyticsService.wishlistAdd(wineId: wine.id)
            NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
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
        visibility = .everyone
        momentImageData = nil
        viewModel.query = ""
        viewModel.results = []
        saveError = nil
    }
}
