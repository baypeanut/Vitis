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
    @Binding var comment: String
    var onCheers: () -> Void
    var isEditMode: Bool = false

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
                commentSection
                cheersButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
    
    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your thoughts")
                .font(VitisTheme.uiFont(size: 16, weight: .medium))
                .foregroundStyle(.primary)
            Text("Optional")
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(VitisTheme.secondaryText)
            ZStack(alignment: .topLeading) {
                if comment.isEmpty {
                    Text("What did you think? (optional)")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $comment)
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(.primary)
                    .frame(minHeight: 100, maxHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .onChange(of: comment) { _, newValue in
                        if newValue.count > 500 {
                            comment = String(newValue.prefix(500))
                        }
                    }
            }
            .background(Color(white: 0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(VitisTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Text("\(comment.count)/500")
                    .font(VitisTheme.uiFont(size: 12))
                    .foregroundStyle(VitisTheme.secondaryText)
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
                Image(systemName: isEditMode ? "checkmark" : "wineglass.fill")
                    .font(.system(size: 14))
                Text(isEditMode ? "Save" : "Cheers")
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
