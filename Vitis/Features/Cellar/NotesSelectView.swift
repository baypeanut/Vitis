//
//  NotesSelectView.swift
//  Vitis
//
//  Optional notes selection: chips for category-based tasting notes.
//

import SwiftUI

struct NotesSelectView: View {
    let wine: Wine
    @Binding var selectedNotes: Set<String>
    var onSave: (Set<String>) -> Void
    var onSkip: () -> Void

    private var availableNotes: [String] {
        TastingNotes.notesForCategory(wine.category)
    }

    var body: some View {
        VStack(spacing: 32) {
            header
            notesChips
            actionButtons
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Aroma and palate")
                .font(VitisTheme.titleFont())
                .foregroundStyle(.primary)
            Text("Select notes (optional)")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
        }
    }

    private var notesChips: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                ForEach(availableNotes, id: \.self) { note in
                    chip(note)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxHeight: 300)
    }

    private func chip(_ note: String) -> some View {
        Button {
            if selectedNotes.contains(note) {
                selectedNotes.remove(note)
            } else {
                selectedNotes.insert(note)
            }
        } label: {
            Text(note)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(selectedNotes.contains(note) ? .white : VitisTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(selectedNotes.contains(note) ? VitisTheme.accent : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(VitisTheme.accent, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                onSave(selectedNotes)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 14))
                    Text("Cheers")
                        .font(VitisTheme.uiFont(size: 15, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(VitisTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button {
                onSkip()
            } label: {
                Text("Skip")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }
}
