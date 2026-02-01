//
//  TastingRateView.swift
//  Vitis
//
//  Single screen: Rating slider + optional notes + Cheers. One decision moment.
//

import SwiftUI
import UIKit

struct TastingRateView: View {
    let wine: Wine
    @Binding var rating: Double
    @Binding var selectedNotes: Set<String>
    var onCheers: () -> Void

    private var wineTypeColor: Color {
        WineColorResolver.resolveWineDisplayColor(wine: wine)
    }

    private var availableNotes: [String] {
        TastingNotes.notesForCategory(wine.category)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                wineInfo
                ratingSlider
                ratingValue
                notesSection
                cheersButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    private var wineInfo: some View {
        VStack(spacing: 8) {
            Text(wine.producer)
                .font(VitisTheme.producerSerifFont())
                .foregroundStyle(VitisTheme.secondaryText)
            Text(wine.name)
                .font(VitisTheme.wineNameFont())
                .foregroundStyle(WineColorResolver.resolveWineDisplayColor(wine: wine))
            if let v = wine.vintage {
                Text(String(v))
                    .font(VitisTheme.detailFont())
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            if let r = wine.region {
                Text(r)
                    .font(VitisTheme.detailFont())
                    .foregroundStyle(VitisTheme.secondaryText)
            }
        }
        .multilineTextAlignment(.center)
    }

    private var ratingSlider: some View {
        VStack(spacing: 16) {
            HStack {
                Text("1.0")
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
                Spacer()
                Text("10.0")
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(VitisTheme.border)
                        .frame(height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    Rectangle()
                        .fill(wineTypeColor)
                        .frame(width: (CGFloat(rating - 1.0) / 9.0) * geo.size.width, height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    let position = max(0, min(geo.size.width - 20, (CGFloat(rating - 1.0) / 9.0) * geo.size.width))
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(wineTypeColor)
                        .offset(x: position)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let clampedX = max(0, min(geo.size.width, value.location.x))
                                    let newValue = max(1.0, min(10.0, 1.0 + (clampedX / geo.size.width) * 9.0))
                                    let prev = rating
                                    rating = round(newValue * 10) / 10.0
                                    if rating != prev {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                        )
                }
            }
            .frame(height: 44)
        }
    }

    private var ratingValue: some View {
        Text(String(format: "%.1f", rating))
            .font(VitisTheme.titleFont())
            .foregroundStyle(wineTypeColor)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aroma and palate")
                .font(VitisTheme.uiFont(size: 16, weight: .medium))
                .foregroundStyle(.primary)
            Text("Optional")
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(VitisTheme.secondaryText)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                ForEach(availableNotes, id: \.self) { note in
                    noteChip(note)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteChip(_ note: String) -> some View {
        let isSelected = selectedNotes.contains(note)
        return Button {
            var next = selectedNotes
            if next.contains(note) {
                next.remove(note)
            } else {
                next.insert(note)
            }
            selectedNotes = next
        } label: {
            Text(note)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(isSelected ? wineTypeColor : VitisTheme.secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? wineTypeColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? wineTypeColor : VitisTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var cheersButton: some View {
        Button {
            onCheers()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 14))
                Text("Cheers")
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(CheersButtonStyle(accentColor: wineTypeColor))
    }
}

// MARK: - Cheers button pressed state (slightly darker when pressed)

private struct CheersButtonStyle: ButtonStyle {
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(accentColor)
            .overlay(configuration.isPressed ? Color.black.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
