//
//  CellarView.swift
//  Vitis
//
//  My Cellar: tasting history with rating and notes. Add wines via +.
//

import SwiftUI

struct CellarView: View {
    @State private var viewModel = CellarViewModel()
    @State private var showAddWine = false

    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSessionReady)) { _ in
            Task { await viewModel.load() }
        }
        .sheet(isPresented: $showAddWine) {
            AddWineSheet(isPresented: $showAddWine) {
                Task { await viewModel.load() }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("My Cellar")
                .font(VitisTheme.titleFont())
                .foregroundStyle(.primary)
            Spacer()
            if !viewModel.needsAuth, let _ = viewModel.currentUserId {
                Button {
                    showAddWine = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(VitisTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.needsAuth {
            Text("Sign in to see your cellar.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = viewModel.errorMessage, viewModel.tastings.isEmpty {
            Text(err)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isLoading && viewModel.tastings.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(VitisTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.tastings.isEmpty {
            emptyState
        } else {
            listContent
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("Your cellar is empty. Add wines you've tasted.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showAddWine = true
            } label: {
                Text("Add")
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(VitisTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.tastings) { tasting in
                tastingRow(tasting)
                    .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24))
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(VitisTheme.border)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await viewModel.removeTasting(tasting) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func tastingRow(_ tasting: Tasting) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tasting.wine.producer)
                    .font(VitisTheme.producerSerifFont())
                    .foregroundStyle(VitisTheme.secondaryText)
                Text(tasting.wine.name)
                    .font(VitisTheme.wineNameFont())
                    .foregroundStyle(.primary)
                if let v = tasting.wine.vintage {
                    Text(String(v))
                        .font(VitisTheme.detailFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                HStack(spacing: 8) {
                    if let r = tasting.wine.region, !r.isEmpty {
                        Text(r)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                        Text("·")
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                    Text(String(format: "%.1f", tasting.rating))
                        .font(VitisTheme.uiFont(size: 13, weight: .medium))
                        .foregroundStyle(VitisTheme.accent)
                    if let notes = tasting.notesDisplay {
                        Text("·")
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                        Text(notes)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
                Text(VitisTheme.compactTimestamp(tasting.createdAt))
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    CellarView()
}
