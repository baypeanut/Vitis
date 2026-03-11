//
//  WantToTryView.swift
//  Pari
//
//  Wishlist screen: wines user wants to try. Search to add, Mark as Tasted or Remove.
//

import SwiftUI
import UIKit

struct WantToTryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let userId: UUID
    var username: String? = nil
    var onDismiss: () -> Void

    @State private var items: [CellarItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddTasting: CellarItem?
    @State private var currentUserId: UUID?
    @State private var myWishlistWineIds: Set<UUID> = []
    @State private var wishlistToggleError: String?
    @State private var alreadyTastedToast = false
    @State private var searchViewModel = AddWineViewModel()
    @State private var isAddingToWishlist = false

    private var isOwnList: Bool { currentUserId == userId }

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background(for: colorScheme).ignoresSafeArea()
                VStack(spacing: 0) {
                    if isOwnList {
                        searchBar
                        Rectangle().fill(PariTheme.border(for: colorScheme)).frame(height: 1)
                    }
                    content
                }
                if isAddingToWishlist || searchViewModel.isUpserting {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(PariTheme.accent(for: colorScheme))
                        .scaleEffect(1.2)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let sub = navigationSubtitle {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text("Reserve List")
                                .font(PariTheme.uiFont(size: 17, weight: .semibold))
                            Text(sub)
                                .font(PariTheme.uiFont(size: 12))
                                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                }
            }
        }
        .task {
            AnalyticsService.wishlistView()
            AnalyticsService.wantToTryOpened(userId: userId)
            await load()
        }
        .onAppear {
            Task { await searchViewModel.loadDatabaseWines() }
            searchViewModel.prefetchPopular()
        }
        .onChange(of: searchViewModel.query) { _, _ in searchViewModel.search() }
        .refreshable { await load() }
        .sheet(item: $showAddTasting) { cellarItem in
            AddWineSheet(
                isPresented: Binding(get: { showAddTasting != nil }, set: { if !$0 { showAddTasting = nil } }),
                initialWine: cellarItem.wine,
                wineIdToRemoveFromWishlist: cellarItem.wineId,
                onWineAdded: {
                    showAddTasting = nil
                    Task { await load() }
                }
            )
        }
        .overlay(alignment: .center) {
            if alreadyTastedToast {
                Text("You've already tasted this wine")
                    .font(PariTheme.uiFont(size: 14))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(PariTheme.secondaryElevated(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: alreadyTastedToast)
        .onReceive(NotificationCenter.default.publisher(for: .pariAlreadyTastedToast)) { _ in
            alreadyTastedToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                alreadyTastedToast = false
            }
        }
    }

    private var navigationTitle: String {
        "Reserve List"
    }

    private var navigationSubtitle: String? {
        if let u = username, !u.isEmpty, currentUserId != userId {
            return "by @\(u)"
        }
        return nil
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            TextField("Search wines to add…", text: $searchViewModel.query)
                .font(PariTheme.uiFont(size: 16))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if isOwnList && !searchViewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            searchResultsContent
        } else if let err = errorMessage {
            Text(err)
                .font(PariTheme.uiFont(size: 14))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoading && items.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(PariTheme.accent(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if items.isEmpty {
            emptyState
        } else {
            listContent
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        if searchViewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            EmptyView()
        } else if searchViewModel.isLoading {
            Text("Locating...")
                .font(PariTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if searchViewModel.results.isEmpty {
            Text("This vintage is not currently in our archives. Check back as our cellar grows.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(searchViewModel.results) { p in
                        searchResultRow(p)
                        Rectangle().fill(PariTheme.border(for: colorScheme)).frame(height: 1).padding(.leading, 24)
                    }
                    if searchViewModel.hasMorePages {
                        Button {
                            searchViewModel.loadMoreSearchResults()
                        } label: {
                            HStack {
                                if searchViewModel.isLoadingMore {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                        .tint(PariTheme.accent(for: colorScheme))
                                } else {
                                    Text("Show more")
                                        .font(PariTheme.uiFont(size: 15, weight: .medium))
                                }
                            }
                            .foregroundStyle(PariTheme.accent(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                        .disabled(searchViewModel.isLoadingMore)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    private func searchResultRow(_ p: OFFProduct) -> some View {
        Button {
            Task { await addWineToWishlist(from: p) }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                searchThumbnail(p.imageUrl)
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
        .disabled(searchViewModel.isUpserting || isAddingToWishlist)
    }

    private func searchThumbnail(_ urlString: String?) -> some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: searchThumbnailPlaceholder
                    }
                }
            } else { searchThumbnailPlaceholder }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var searchThumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(white: 0.94))
            .overlay(Image(systemName: "wineglass.fill").font(.system(size: 20)).foregroundStyle(PariTheme.secondaryText.opacity(0.6)))
    }

    private func addWineToWishlist(from p: OFFProduct) async {
        guard currentUserId == userId else { return }
        isAddingToWishlist = true
        errorMessage = nil
        do {
            let wine = try await searchViewModel.upsert(product: p)
            try await CellarService.addToWishlist(wineId: wine.id, sourceUserId: nil, sourceContext: "search")
            AnalyticsService.wishlistAdd(wineId: wine.id)
            searchViewModel.query = ""
            NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
            await load()
        } catch {
            if !isCancellation(error) { errorMessage = ErrorMessage.userFacing(for: error) }
        }
        isAddingToWishlist = false
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(isOwnList
                ? "No wines saved yet. Search above or tap the bookmark on any feed post to add."
                : "No wines in their list.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listContent: some View {
        List {
            ForEach(items) { item in
                wishlistRow(item)
                    .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24))
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(PariTheme.border(for: colorScheme))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if isOwnList {
                            Button {
                                showAddTasting = item
                            } label: {
                                Label("Tasted", systemImage: "checkmark.circle")
                            }
                            .tint(PariTheme.accent(for: colorScheme))
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if isOwnList {
                            Button(role: .destructive) {
                                Task { await remove(item) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func wishlistRow(_ item: CellarItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.wine.producer)
                    .font(colorScheme == .dark ? PariTheme.uiFont(size: 13, weight: .regular) : PariTheme.producerSerifFont())
                    .foregroundStyle(colorScheme == .dark ? PariTheme.textTertiary(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                Text(item.wine.name)
                    .font(PariTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(colorScheme == .dark ? PariTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(wine: item.wine))
                if let r = item.wine.region, !r.isEmpty {
                    Text(r)
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                }
                Text(PariTheme.compactTimestamp(item.createdAt))
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.tertiaryText(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isOwnList, currentUserId != nil {
                Button {
                    Task { await toggleWishlist(item, sourceUserId: userId) }
                } label: {
                    Image(systemName: myWishlistWineIds.contains(item.wineId) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundStyle(myWishlistWineIds.contains(item.wineId) ? PariTheme.accent(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleWishlist(_ item: CellarItem, sourceUserId: UUID) async {
        guard currentUserId != nil else { return }
        let wineId = item.wineId
        let wasIn = myWishlistWineIds.contains(wineId)
        wishlistToggleError = nil
        if wasIn {
            myWishlistWineIds.remove(wineId)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            do {
                try await CellarService.removeFromWishlist(wineId: wineId)
                NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
            } catch {
                myWishlistWineIds.insert(wineId)
                wishlistToggleError = "Could not update."
            }
            return
        }
        myWishlistWineIds.insert(wineId)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do {
            let added = try await CellarService.addToWishlist(wineId: wineId, sourceUserId: sourceUserId, sourceContext: "wishlist")
            if added {
                NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
            } else {
                myWishlistWineIds.remove(wineId)
                NotificationCenter.default.post(name: .pariAlreadyTastedToast, object: nil)
            }
        } catch {
            myWishlistWineIds.remove(wineId)
            wishlistToggleError = "Could not update."
        }
    }

    private func load() async {
        let cur = await AuthService.currentUserId()
        currentUserId = cur
        isLoading = true
        errorMessage = nil
        do {
            items = try await CellarService.fetchWishlist(userId: userId)
            if let curUser = cur, curUser != userId {
                myWishlistWineIds = try await CellarService.fetchWishlistWineIds(userId: curUser)
            }
        } catch {
            if !isCancellation(error) { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private func remove(_ item: CellarItem) async {
        do {
            try await CellarService.removeFromWishlist(wineId: item.wineId)
            items.removeAll { $0.id == item.id }
            NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
