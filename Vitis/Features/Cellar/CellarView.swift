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
    @State private var selectedCategory: String = ""

    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }
        }
        .task {
            await viewModel.load()
            updateSelectedCategory()
        }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSessionReady)) { _ in
            Task { await viewModel.load() }
        }
        .onChange(of: viewModel.groupedTastings.count) { _, _ in
            updateSelectedCategory()
        }
        .onChange(of: viewModel.sortOption) { _, _ in
            viewModel.groupTastingsByCategory()
        }
        .onChange(of: viewModel.ratingFilter) { _, _ in
            viewModel.groupTastingsByCategory()
        }
        .sheet(isPresented: $showAddWine) {
            AddWineSheet(isPresented: $showAddWine) {
                Task { await viewModel.load() }
            }
        }
    }

    private func updateSelectedCategory() {
        if selectedCategory.isEmpty || !viewModel.groupedTastings.contains(where: { $0.category == selectedCategory }) {
            selectedCategory = viewModel.groupedTastings.first?.category ?? ""
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
        VStack(spacing: 0) {
            quickFilters
            if viewModel.groupedTastings.count > 1 {
                categoryTabs
                Rectangle().fill(VitisTheme.border).frame(height: 1)
            }
            categoryContent
        }
    }

    private var quickFilters: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(CellarViewModel.SortOption.allCases, id: \.self) { opt in
                    Button {
                        viewModel.sortOption = opt
                    } label: {
                        Text(opt.rawValue)
                            .font(VitisTheme.uiFont(size: 13, weight: viewModel.sortOption == opt ? .semibold : .regular))
                    }
                    .foregroundStyle(viewModel.sortOption == opt ? VitisTheme.accent : VitisTheme.secondaryText)
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CellarViewModel.RatingFilter.allCases, id: \.self) { f in
                        Button {
                            viewModel.ratingFilter = f
                        } label: {
                            Text(f.rawValue)
                                .font(VitisTheme.uiFont(size: 13))
                        }
                        .foregroundStyle(viewModel.ratingFilter == f ? .white : VitisTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.ratingFilter == f ? VitisTheme.accent : Color(white: 0.96))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(viewModel.groupedTastings, id: \.category) { group in
                    Button {
                        selectedCategory = group.category
                    } label: {
                        Text(group.category)
                            .font(VitisTheme.uiFont(size: 15, weight: selectedCategory == group.category ? .semibold : .regular))
                            .foregroundStyle(selectedCategory == group.category ? VitisTheme.accent : VitisTheme.secondaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    @ViewBuilder
    private var categoryContent: some View {
        if let currentGroup = viewModel.groupedTastings.first(where: { $0.category == selectedCategory }) {
            List {
                ForEach(currentGroup.tastings) { tasting in
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
        } else {
            Text("No wines in this category.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func tastingRow(_ tasting: Tasting) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tasting.wine.producer)
                    .font(VitisTheme.producerSerifFont())
                    .foregroundStyle(VitisTheme.secondaryText)
                HStack(alignment: .center) {
                    Text(tasting.wine.name)
                        .font(VitisTheme.wineNameFont())
                        .foregroundStyle(WineColorResolver.resolveWineDisplayColor(wine: tasting.wine))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f", tasting.rating))
                        .font(VitisTheme.uiFont(size: 24, weight: .semibold))
                        .foregroundStyle(VitisTheme.accent)
                }
                if let v = tasting.wine.vintage {
                    Text(String(v))
                        .font(VitisTheme.detailFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                HStack(spacing: 8) {
                    if let notes = tasting.notesDisplay {
                        Text(notes)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
                Text(VitisTheme.compactTimestamp(tasting.createdAt))
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
        }
    }
}

#Preview {
    CellarView()
}
