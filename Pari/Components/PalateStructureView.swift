//
//  PalateStructureView.swift
//  Pari
//
//  Five-point structural scales, one row per dimension.
//
//  Three constraints shaped this, and they came from different directions:
//  a novice must never be shown it, a taster must be able to answer the whole
//  grid in a few taps, and nothing here may read as a quality judgement. That
//  last one is why the endpoints are descriptive words with no colour ramp:
//  high tannin is not a better score than low tannin, it is a different wine.
//

import SwiftUI
import UIKit

struct PalateStructureView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var structure: PalateStructure
    /// Tannin is hidden on whites and sparkling; the category decides.
    let wineCategory: String?
    let accentColor: Color

    @State private var isExpanded = false

    private var dimensions: [PalateDimension] {
        PalateDimension.allCases.filter { $0.applies(toCategory: wineCategory) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isExpanded {
                VStack(spacing: 14) {
                    ForEach(dimensions, id: \.self) { dimension in
                        row(dimension)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Header

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text("Structure")
                    .font(PariTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                Text(subtitle)
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Structure, \(structure.answeredCount) of \(dimensions.count) recorded")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to record structure")
    }

    private var subtitle: String {
        let n = structure.answeredCount
        return n == 0 ? "— optional" : "— \(n) of \(dimensions.count)"
    }

    // MARK: - One dimension

    private func row(_ dimension: PalateDimension) -> some View {
        let value = structure[dimension]
        let ends = dimension.endpoints
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(dimension.label)
                    .font(PariTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                Spacer()
                if value != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) { structure[dimension] = nil }
                    } label: {
                        Text("Clear")
                            .font(PariTheme.uiFont(size: 11))
                            .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                Text(ends.low)
                    .font(PariTheme.uiFont(size: 11))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    .frame(width: 46, alignment: .leading)

                HStack(spacing: 5) {
                    ForEach(1...5, id: \.self) { step in
                        stepDot(dimension: dimension, step: step, selected: value == step)
                    }
                }

                Text(ends.high)
                    .font(PariTheme.uiFont(size: 11))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    .frame(width: 66, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dimension.label)
        .accessibilityValue(value.map { "\($0) of 5" } ?? "not recorded")
    }

    private func stepDot(dimension: PalateDimension, step: Int, selected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                structure[dimension] = selected ? nil : step
            }
            if !selected { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        } label: {
            Circle()
                .fill(selected ? accentColor : Color.clear)
                .overlay(
                    Circle().stroke(
                        selected ? accentColor : PariTheme.divider(for: colorScheme),
                        lineWidth: 1
                    )
                )
                .frame(height: 22)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dimension.label) \(step) of 5")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
