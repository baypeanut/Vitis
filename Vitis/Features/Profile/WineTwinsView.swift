//
//  WineTwinsView.swift
//  Vitis
//
//  Taste Twin list: shows users with similar palates, sorted by similarity score.
//  Displayed on the profile via a "Taste Twins" section.
//

import SwiftUI

struct WineTwinsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let userId: UUID
    let twins: [TasteTwin]
    var onTwinTap: ((UUID) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(VitisTheme.accent(for: colorScheme))
                Text("Taste Twins")
                    .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
            }

            if twins.isEmpty {
                Text("Rate more wines to discover your taste twins.")
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(twins) { twin in
                        twinRow(twin)
                        if twin.id != twins.last?.id {
                            Rectangle()
                                .fill(VitisTheme.border(for: colorScheme))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func twinRow(_ twin: TasteTwin) -> some View {
        Button {
            onTwinTap?(twin.id)
        } label: {
            HStack(spacing: 12) {
                twinAvatar(twin)
                VStack(alignment: .leading, spacing: 2) {
                    Text(twin.displayName)
                        .font(VitisTheme.uiFont(size: 15, weight: .medium))
                        .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                    Text("@\(twin.username)")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                }
                Spacer()
                similarityBadge(twin.similarity)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func twinAvatar(_ twin: TasteTwin) -> some View {
        Group {
            if let urlStr = twin.avatarURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: avatarPlaceholder(twin.displayName)
                    }
                }
            } else {
                avatarPlaceholder(twin.displayName)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func avatarPlaceholder(_ name: String) -> some View {
        Circle()
            .fill(VitisTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            )
    }

    private func similarityBadge(_ sim: TasteSimilarity) -> some View {
        HStack(spacing: 4) {
            Image(systemName: sim.icon)
                .font(.system(size: 11))
            Text(sim.displayText)
                .font(VitisTheme.uiFont(size: 12, weight: .medium))
        }
        .foregroundStyle(badgeColor(sim))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(badgeColor(sim).opacity(0.12))
        .clipShape(Capsule())
    }

    private func badgeColor(_ sim: TasteSimilarity) -> Color {
        switch sim.percentage {
        case 80...100: return VitisTheme.accent(for: colorScheme)
        case 60..<80:  return VitisTheme.accentWine(for: colorScheme)
        default:       return VitisTheme.secondaryText(for: colorScheme)
        }
    }
}

// MARK: - Compact badge for profile header / feed items

struct TasteTwinBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let similarity: TasteSimilarity

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: similarity.icon)
                .font(.system(size: 10))
            Text(similarity.displayText)
                .font(VitisTheme.uiFont(size: 11, weight: .medium))
        }
        .foregroundStyle(VitisTheme.accent(for: colorScheme))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(VitisTheme.accent(for: colorScheme).opacity(0.12))
        .clipShape(Capsule())
    }
}
