//
//  ForYouView.swift
//  Pari
//
//  Personalised discovery: wines to try next, ranked by taste affinity and what the
//  user's taste twins scored. Backed by the recommend_wines RPC.
//

import SwiftUI

@MainActor
@Observable
final class ForYouViewModel {
    var recommendations: [WineRecommendation] = []
    var isLoading = false
    /// True once a load has finished, so an empty list can be distinguished from "not loaded yet".
    var hasLoaded = false

    func load() async {
        isLoading = true
        recommendations = await RecommendationService.fetchRecommendations()
        isLoading = false
        hasLoaded = true
    }
}

struct ForYouView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ForYouViewModel()
    @State private var showListScan = false
    let currentUserId: UUID?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.recommendations.isEmpty {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(PariTheme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasLoaded && viewModel.recommendations.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .task {
            if !viewModel.hasLoaded { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pariTastingCreated)) { _ in
            // A new tasting moves the taste vector, so the ranking is now stale.
            Task { await viewModel.load() }
        }
        .fullScreenCover(isPresented: $showListScan) {
            WineListScanView(isPresented: $showListScan, currentUserId: currentUserId)
        }
    }

    /// Discovery is where someone goes when they have to choose, and the hardest
    /// place to choose is in front of a restaurant list.
    private var listScanButton: some View {
        Button {
            showListScan = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 15))
                Text("Scan a wine list")
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
        .padding(.horizontal, 24)
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                header
                listScanButton
                    .padding(.bottom, 16)
                ForEach(viewModel.recommendations) { rec in
                    NavigationLink {
                        WineCardView(wine: rec.wine, activityId: nil, currentUserId: currentUserId)
                    } label: {
                        row(rec)
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .padding(.leading, 24)
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Picked for you")
                .font(.system(.title3, design: .serif, weight: .regular))
                .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
            Text("From what you've rated and who drinks like you.")
                .font(PariTheme.uiFont(size: 13))
                .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func row(_ rec: WineRecommendation) -> some View {
        HStack(spacing: 14) {
            wineThumbnail(rec.wine)

            VStack(alignment: .leading, spacing: 3) {
                Text(rec.wine.producer)
                    .font(PariTheme.uiFont(size: 12))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    .lineLimit(1)

                Text(rec.wine.name)
                    .font(PariTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let region = rec.wine.region {
                    Text(region)
                        .font(PariTheme.uiFont(size: 12))
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }

                if let explanation = rec.explanation {
                    Text(explanation)
                        .font(PariTheme.uiFont(size: 12))
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            if let rating = rec.headlineRating {
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", rating))
                        .font(.system(.body, design: .serif, weight: .medium))
                        .foregroundStyle(PariTheme.ratingColorAdaptive(rating: rating, for: colorScheme))
                    Text(rec.reason == .twins ? "twins" : "avg")
                        .font(PariTheme.uiFont(size: 10))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func wineThumbnail(_ wine: Wine) -> some View {
        let tint = WineColorResolver.resolveWineDisplayColor(wine: wine)
        return Group {
            if let urlString = wine.labelImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    glassPlaceholder(tint)
                }
            } else {
                glassPlaceholder(tint)
            }
        }
        .frame(width: 48, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func glassPlaceholder(_ tint: Color) -> some View {
        ZStack {
            PariTheme.backgroundSecondary(for: colorScheme)
            Image(systemName: "wineglass.fill")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(tint.opacity(0.55))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(PariTheme.accentWine(for: colorScheme).opacity(0.25))
            Text("Nothing to suggest yet.")
                .font(.system(.title3, design: .serif, weight: .regular))
                .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
            Text("Rate a few wines and this fills up.")
                .font(PariTheme.uiFont(size: 14))
                .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                .multilineTextAlignment(.center)
            listScanButton
                .padding(.top, 12)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
