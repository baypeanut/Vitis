//
//  WantToTryView.swift
//  Vitis
//
//  Wishlist screen: wines user wants to try. Mark as Tasted or Remove.
//

import SwiftUI

struct WantToTryView: View {
    let userId: UUID
    var onDismiss: () -> Void

    @State private var items: [CellarItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddTasting: CellarItem?
    @State private var currentUserId: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Want to Try")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.accent)
                }
            }
        }
        .task {
                AnalyticsService.wishlistView()
                await load()
            }
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
    }

    @ViewBuilder
    private var content: some View {
        if let err = errorMessage {
            Text(err)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoading && items.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(VitisTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if items.isEmpty {
            emptyState
        } else {
            listContent
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No wines saved yet. Tap the bookmark on any feed post to add.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
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
                    .listRowSeparatorTint(VitisTheme.border)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await remove(item) }
                        } label: {
                            Label("Remove", systemImage: "trash")
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
                    .font(VitisTheme.producerSerifFont())
                    .foregroundStyle(VitisTheme.secondaryText)
                Text(item.wine.name)
                    .font(VitisTheme.wineNameFont())
                    .foregroundStyle(WineColorResolver.resolveWineDisplayColor(wine: item.wine))
                if let r = item.wine.region, !r.isEmpty {
                    Text(r)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                Text(VitisTheme.compactTimestamp(item.createdAt))
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if currentUserId == userId {
                Button("Mark as Tasted") {
                    showAddTasting = item
                }
                .font(VitisTheme.uiFont(size: 14, weight: .medium))
                .foregroundStyle(VitisTheme.accent)
            }
        }
    }

    private func load() async {
        currentUserId = await AuthService.currentUserId()
        isLoading = true
        errorMessage = nil
        do {
            items = try await CellarService.fetchWishlist(userId: userId)
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
            try await CellarService.removeFromWishlist(userId: userId, wineId: item.wineId)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
