//
//  TasteDNACardView.swift
//  Pari
//
//  Shareable "Taste DNA" card — Spotify Wrapped for wine.
//  Renders user's wine personality as an Instagram-story-sized card.
//

import SwiftUI

// MARK: - Data Model

struct TasteDNA: Sendable {
    let displayName: String
    let username: String
    let totalTastings: Int
    let topGrapes: [TasteProfileItem]   // max 3
    let topRegions: [TasteProfileItem]  // max 3
    let topCategory: String?            // "Red", "White", etc.
    let avgRating: Double?
    let personality: Personality

    enum Personality: String {
        case boldExplorer = "The Bold Explorer"
        case classicConnoisseur = "The Classic Connoisseur"
        case curiousNovice = "The Curious Novice"
        case eclecticPalate = "The Eclectic Palate"
        case regionDevotee = "The Region Devotee"
    }

    static func compute(profile: Profile, tastings: [Tasting], grapes: [TasteProfileItem], regions: [TasteProfileItem], styles: [TasteProfileItem]) -> TasteDNA {
        let avgRating: Double? = tastings.isEmpty ? nil : tastings.map(\.rating).reduce(0, +) / Double(tastings.count)
        let topCategory = styles.first?.name

        // Determine personality
        let personality: Personality
        let uniqueRegions = Set(regions.map(\.name)).count
        let uniqueGrapes = Set(grapes.map(\.name)).count

        if tastings.count < 5 {
            personality = .curiousNovice
        } else if uniqueRegions >= 5 && uniqueGrapes >= 5 {
            personality = .eclecticPalate
        } else if uniqueRegions <= 2 && tastings.count >= 10 {
            personality = .regionDevotee
        } else if let avg = avgRating, avg >= 7.5 {
            personality = .classicConnoisseur
        } else {
            personality = .boldExplorer
        }

        return TasteDNA(
            displayName: profile.displayName,
            username: profile.username,
            totalTastings: tastings.count,
            topGrapes: Array(grapes.prefix(3)),
            topRegions: Array(regions.prefix(3)),
            topCategory: topCategory,
            avgRating: avgRating,
            personality: personality
        )
    }
}

// MARK: - Card View (renders to image for sharing)

struct TasteDNACard: View {
    let dna: TasteDNA

    private let cardWidth: CGFloat = 360
    private let cardHeight: CGFloat = 640

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Text("MY TASTE DNA")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .tracking(2)
                    .foregroundStyle(Color(red: 0.72, green: 0.29, blue: 0.35).opacity(0.7))

                Text(dna.personality.rawValue)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(Color(red: 0.95, green: 0.92, blue: 0.88))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)

            // Stats row
            HStack(spacing: 24) {
                statBox(value: "\(dna.totalTastings)", label: "Tastings")
                if let avg = dna.avgRating {
                    statBox(value: String(format: "%.1f", avg), label: "Avg Rating")
                }
                if let cat = dna.topCategory {
                    statBox(value: cat, label: "Favourite")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            // Top Grapes
            if !dna.topGrapes.isEmpty {
                sectionBlock(title: "TOP GRAPES", items: dna.topGrapes)
                    .padding(.bottom, 20)
            }

            // Top Regions
            if !dna.topRegions.isEmpty {
                sectionBlock(title: "TOP REGIONS", items: dna.topRegions)
                    .padding(.bottom, 20)
            }

            Spacer()

            // Footer
            VStack(spacing: 4) {
                Text("@\(dna.username)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.92, blue: 0.88).opacity(0.6))
                Text("pari.app")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(red: 0.95, green: 0.92, blue: 0.88).opacity(0.35))
            }
            .padding(.bottom, 32)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.06, blue: 0.05),
                    Color(red: 0.15, green: 0.08, blue: 0.08),
                    Color(red: 0.07, green: 0.06, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Color(red: 0.95, green: 0.92, blue: 0.88))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.62, green: 0.57, blue: 0.52))
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionBlock(title: String, items: [TasteProfileItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color(red: 0.72, green: 0.29, blue: 0.35).opacity(0.6))
                .padding(.horizontal, 28)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.name) { index, item in
                    HStack {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(Color(red: 0.72, green: 0.29, blue: 0.35))
                            .frame(width: 20)
                        Text(item.name)
                            .font(.system(size: 15, weight: .regular, design: .serif))
                            .foregroundStyle(Color(red: 0.95, green: 0.92, blue: 0.88))
                        Spacer()
                        Text("\(item.count)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.62, green: 0.57, blue: 0.52))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - Share Sheet (presented from profile)

struct TasteDNAShareSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let dna: TasteDNA

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    TasteDNACard(dna: dna)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                    ShareLink(item: renderedImage, preview: SharePreview("My Taste DNA — \(dna.personality.rawValue)", image: renderedImage)) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                            Text("Share")
                                .font(PariTheme.uiFont(size: 16, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PariTheme.accent(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 24)
            }
            .background(PariTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Your Taste DNA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private var renderedImage: Image {
        let renderer = ImageRenderer(content: TasteDNACard(dna: dna))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
}
