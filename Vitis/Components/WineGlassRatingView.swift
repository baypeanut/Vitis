//
//  WineGlassRatingView.swift
//  Pari
//
//  5-glass rating system. Each glass = 2 points. Half-fill = 1 point.
//  Rating range: 1.0 – 10.0 (integer steps only).
//
//  Glass 1 → 1 (half) / 2 (full)
//  Glass 2 → 3 (half) / 4 (full)
//  Glass 3 → 5 (half) / 6 (full)
//  Glass 4 → 7 (half) / 8 (full)
//  Glass 5 → 9 (half) / 10 (full)
//

import SwiftUI
import UIKit

struct WineGlassRatingView: View {
    @Binding var rating: Double   // 1.0 – 10.0 integer steps
    var accentColor: Color = PariTheme.accentWine(for: .light)
    var size: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: glassSpacing(in: geo.size.width)) {
                ForEach(1...5, id: \.self) { index in
                    glassIcon(index: index)
                }
            }
            .frame(maxWidth: .infinity)
            // Drag gesture: slide finger to set rating
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newRating = ratingFor(x: value.location.x, width: geo.size.width)
                        if rating != newRating {
                            rating = newRating
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
            )
        }
        .frame(height: size + 8)
    }

    // MARK: - Single glass icon

    private func glassIcon(index: Int) -> some View {
        let halfRating = Double(index * 2 - 1)  // 1,3,5,7,9
        let fullRating = Double(index * 2)       // 2,4,6,8,10
        let isFull = rating >= fullRating
        let isHalf = !isFull && rating >= halfRating

        return ZStack {
            // Base: empty glass outline
            Image(systemName: "wineglass")
                .font(.system(size: size, weight: .ultraLight))
                .foregroundStyle(accentColor.opacity(0.18))

            // Fill overlay
            if isFull {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: size))
                    .foregroundStyle(accentColor)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if isHalf {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: size))
                    .foregroundStyle(accentColor.opacity(0.45))
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size + 8)
        .contentShape(Rectangle())
        // Tap to toggle: tap once → full, tap again (already full) → half, again → empty
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                if rating == fullRating {
                    rating = halfRating
                } else if rating == halfRating {
                    rating = max(1.0, fullRating - 2.0)
                } else {
                    rating = fullRating
                }
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .accessibilityLabel("Glass \(index): \(isFull ? "full" : isHalf ? "half" : "empty")")
        .accessibilityHint("Tap to set rating to \(Int(fullRating)) or \(Int(halfRating))")
    }

    // MARK: - Drag calculation

    private func ratingFor(x: CGFloat, width: CGFloat) -> Double {
        let clamped = max(0, min(width, x))
        let glassWidth = width / 5.0
        let glassIndex = min(4, Int(clamped / glassWidth))         // 0–4
        let posWithin  = clamped - CGFloat(glassIndex) * glassWidth
        let isRightHalf = posWithin >= glassWidth / 2

        let raw = isRightHalf
            ? Double((glassIndex + 1) * 2)       // full  2,4,6,8,10
            : Double(glassIndex * 2 + 1)          // half  1,3,5,7,9
        return max(1.0, min(10.0, raw))
    }

    private func glassSpacing(in width: CGFloat) -> CGFloat {
        let totalGlass = size * 5
        let remaining  = width - totalGlass
        return max(8, remaining / 4)
    }
}

// MARK: - Rating label helper

extension WineGlassRatingView {
    /// E.g. "8 / 10" or "9 / 10" (gold-eligible)
    static func ratingLabel(_ rating: Double) -> String {
        "\(Int(rating)) / 10"
    }
}

#Preview {
    @Previewable @State var r = 7.0
    VStack(spacing: 24) {
        WineGlassRatingView(rating: $r, accentColor: Color(red: 0x4A/255, green: 0x0E/255, blue: 0x0E/255))
        Text(WineGlassRatingView.ratingLabel(r))
            .font(.system(.title2, design: .serif))
    }
    .padding(32)
}
