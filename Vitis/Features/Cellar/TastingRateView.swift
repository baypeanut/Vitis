//
//  TastingRateView.swift
//  Vitis
//
//  Rating step: 1.0-10.0 slider with wine glass icon thumb, category-tinted.
//

import SwiftUI

struct TastingRateView: View {
    let wine: Wine
    @Binding var rating: Double
    var onNext: () -> Void

    private var categoryColor: Color {
        guard let cat = wine.category?.lowercased() else { return VitisTheme.accent }
        if cat.contains("red") || cat.contains("rouge") {
            return Color(red: 0.7, green: 0.1, blue: 0.1)
        } else if cat.contains("white") || cat.contains("blanc") {
            return Color(red: 0.95, green: 0.9, blue: 0.7)
        } else if cat.contains("rose") || cat.contains("rosé") {
            return Color(red: 0.95, green: 0.7, blue: 0.7)
        } else if cat.contains("sparkling") {
            return Color(white: 0.95)
        }
        return VitisTheme.accent
    }

    var body: some View {
        VStack(spacing: 32) {
            wineInfo
            ratingSlider
            ratingValue
            nextButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
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
                        .fill(categoryColor)
                        .frame(width: (CGFloat(rating - 1.0) / 9.0) * geo.size.width, height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    let position = max(0, min(geo.size.width - 20, (CGFloat(rating - 1.0) / 9.0) * geo.size.width))
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(categoryColor)
                        .offset(x: position)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let clampedX = max(0, min(geo.size.width, value.location.x))
                                    let newValue = max(1.0, min(10.0, 1.0 + (clampedX / geo.size.width) * 9.0))
                                    rating = round(newValue * 10) / 10.0
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
            .foregroundStyle(VitisTheme.accent)
    }

    private var nextButton: some View {
        Button {
            onNext()
        } label: {
            Text("Next")
                .font(VitisTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(VitisTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
