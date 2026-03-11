//
//  TasteProfileDrillDownView.swift
//  Pari
//
//  Drill-down list of tastings for a grape or region. Cellar-style rows.
//

import SwiftUI

struct TasteProfileDrillDownView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let filterType: FilterType
    let tastings: [Tasting]
    var currentUserId: UUID?

    enum FilterType {
        case grape(String)
        case region(String)
        case style(String)
    }

    private var filteredTastings: [Tasting] {
        let filtered: [Tasting]
        switch filterType {
        case .grape(let name):
            filtered = filterByGrape(tastings, grapeName: name)
        case .region(let name):
            filtered = filterByRegion(tastings, regionName: name)
        case .style(let name):
            filtered = filterByStyle(tastings, styleName: name)
        }
        // Sort by rating, highest first
        return filtered.sorted { $0.rating > $1.rating }
    }

    var body: some View {
        List {
            ForEach(filteredTastings) { tasting in
                drillDownRow(tasting)
                    .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24))
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(PariTheme.divider(for: colorScheme))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(PariTheme.background(for: colorScheme))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func drillDownRow(_ tasting: Tasting) -> some View {
        NavigationLink(destination: WineCardView(wine: tasting.wine, activityId: nil, currentUserId: currentUserId)) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tasting.wine.producer)
                        .font(colorScheme == .dark ? PariTheme.uiFont(size: 13, weight: .regular) : PariTheme.producerSerifFont())
                        .foregroundStyle(colorScheme == .dark ? PariTheme.textTertiary(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                    HStack(alignment: .center) {
                        Text(tasting.wine.name)
                            .font(PariTheme.wineNameFont(for: colorScheme))
                            .foregroundStyle(colorScheme == .dark ? PariTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(wine: tasting.wine, colorScheme: colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f", tasting.rating))
                            .font(colorScheme == .dark ? PariTheme.ratingFont() : PariTheme.uiFont(size: 24, weight: .semibold))
                            .foregroundStyle(PariTheme.ratingColor(for: colorScheme))
                    }
                    if let v = tasting.wine.vintage {
                        Text(String(v))
                            .font(PariTheme.detailFont())
                            .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    }
                    Text(PariTheme.compactTimestamp(tasting.createdAt))
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(colorScheme == .dark ? PariTheme.tertiaryText(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func filterByGrape(_ tastings: [Tasting], grapeName: String) -> [Tasting] {
        let norm = grapeName.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "  ", with: " ")
        guard !norm.isEmpty else { return [] }
        return tastings.filter { tasting in
            if let v = tasting.wine.variety?.trimmingCharacters(in: .whitespaces).lowercased()
                .replacingOccurrences(of: "  ", with: " "), !v.isEmpty {
                return v == norm || v.contains(norm)
            }
            let name = tasting.wine.name.trimmingCharacters(in: .whitespaces).lowercased()
            return name.contains(norm)
        }
    }

    private func filterByRegion(_ tastings: [Tasting], regionName: String) -> [Tasting] {
        let norm = regionName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !norm.isEmpty else { return [] }
        let key = ProfileService.regionMatchKey(norm)
        return tastings.filter { tasting in
            guard let r = tasting.wine.region?.trimmingCharacters(in: .whitespaces).lowercased(), !r.isEmpty else { return false }
            return ProfileService.regionMatchKey(r) == key
        }
    }
    
    private func filterByStyle(_ tastings: [Tasting], styleName: String) -> [Tasting] {
        let norm = styleName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !norm.isEmpty else { return [] }
        return tastings.filter { tasting in
            guard let c = tasting.wine.category?.trimmingCharacters(in: .whitespaces).lowercased(), !c.isEmpty else { return false }
            return c == norm
        }
    }
}
