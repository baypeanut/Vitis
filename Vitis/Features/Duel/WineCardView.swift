//
//  WineCardView.swift
//  Vitis
//
//  Elegant wine card for duel comparison: producer (small caps), name (serif), minimal layout.
//

import SwiftUI

struct WineCardView: View {
    let wine: Wine
    var isSelected: Bool = false
    var showNewEntryLabel: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if showNewEntryLabel {
                    Text("First Ranking")
                        .font(VitisTheme.uiFont(size: 10, weight: .medium))
                        .foregroundStyle(VitisTheme.accent)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                labelArea

                VStack(alignment: .leading, spacing: 4) {
                    Text(wine.producer)
                        .font(VitisTheme.producerFont())
                        .foregroundStyle(VitisTheme.secondaryText)

                    Text(wine.name)
                        .font(VitisTheme.wineNameFont())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if let vintage = wine.vintage {
                        Text(String(vintage))
                            .font(VitisTheme.detailFont())
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(VitisTheme.background)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? VitisTheme.accent : VitisTheme.border, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var labelArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.97))
                .aspectRatio(0.65, contentMode: .fit)

            if let urlString = wine.labelImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        labelPlaceholder
                    case .empty:
                        labelPlaceholder
                    @unknown default:
                        labelPlaceholder
                    }
                }
                .aspectRatio(0.65, contentMode: .fit)
            } else {
                labelPlaceholder
            }
        }
        .padding(12)
    }

    private var labelPlaceholder: some View {
        Image(systemName: "wineglass.fill")
            .font(.system(size: 32, weight: .light))
            .foregroundStyle(VitisTheme.secondaryText.opacity(0.6))
    }
}

#Preview {
    VStack(spacing: 24) {
        WineCardView(wine: .preview, isSelected: false)
        WineCardView(wine: .previewB, isSelected: true)
    }
    .padding()
    .background(VitisTheme.background)
}
