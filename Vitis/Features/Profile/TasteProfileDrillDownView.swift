//
//  TasteProfileDrillDownView.swift
//  Vitis
//
//  Drill-down list of tastings for a grape or region. Cellar-style rows.
//

import SwiftUI

struct TasteProfileDrillDownView: View {
    let title: String
    let filterType: FilterType
    let tastings: [Tasting]

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
                    .listRowSeparatorTint(VitisTheme.border)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(VitisTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func drillDownRow(_ tasting: Tasting) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tasting.wine.producer)
                    .font(VitisTheme.producerSerifFont())
                    .foregroundStyle(VitisTheme.secondaryText)
                HStack(alignment: .center) {
                    Text(tasting.wine.name)
                        .font(VitisTheme.wineNameFont())
                        .foregroundStyle(WineColorResolver.resolveWineDisplayColor(wine: tasting.wine))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f", tasting.rating))
                        .font(VitisTheme.uiFont(size: 24, weight: .semibold))
                        .foregroundStyle(VitisTheme.accent)
                }
                if let v = tasting.wine.vintage {
                    Text(String(v))
                        .font(VitisTheme.detailFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                HStack(spacing: 8) {
                    if let notes = tasting.notesDisplay {
                        Text(notes)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
                Text(VitisTheme.compactTimestamp(tasting.createdAt))
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
        }
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
