//
//  CellarView.swift
//  Vitis
//
//  Had | Wishlist cellar. Add wines via +; timestamps per row. Beli-style.
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
                tabBar
                content
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSessionReady)) { _ in
            Task { await viewModel.load() }
        }
        .sheet(isPresented: $showAddWine) {
            addWineSheet
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Cellar")
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([CellarViewModel.Tab.had, .wishlist], id: \.self) { t in
                tabButton(t)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func tabButton(_ t: CellarViewModel.Tab) -> some View {
        let label = t == .had ? "Had" : "Wishlist"
        return Button {
            viewModel.switchTab(to: t)
        } label: {
            Text(label)
                .font(VitisTheme.uiFont(size: 15, weight: viewModel.tab == t ? .semibold : .regular))
                .foregroundStyle(viewModel.tab == t ? VitisTheme.accent : VitisTheme.secondaryText)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var addWineSheet: some View {
        if let uid = viewModel.currentUserId, let status = CellarItem.CellarStatus(rawValue: viewModel.tab.rawValue) {
            AddWineSheet(isPresented: $showAddWine, cellarContext: (userId: uid, status: status)) {
                Task { await viewModel.load() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.needsAuth {
            Text("Sign in to see your cellar.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = viewModel.errorMessage, viewModel.items.isEmpty {
            Text(err)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(VitisTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.items.isEmpty {
            emptyState
        } else {
            listContent
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(viewModel.tab == .had
                ? "Your cellar is empty. Add wines you had."
                : "Save wines to try later.")
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
            ForEach(viewModel.items) { item in
                cellarRow(item)
                    .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24))
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(VitisTheme.border)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await viewModel.removeItem(item) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func cellarRow(_ item: CellarItem) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.wine.producer)
                    .font(VitisTheme.producerSerifFont())
                    .foregroundStyle(VitisTheme.secondaryText)
                Text(item.wine.name)
                    .font(VitisTheme.wineNameFont())
                    .foregroundStyle(.primary)
                if let v = item.wine.vintage {
                    Text(String(v))
                        .font(VitisTheme.detailFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                Text(VitisTheme.compactTimestamp(item.displayDate))
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
