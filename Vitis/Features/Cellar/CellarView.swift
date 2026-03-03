//
//  CellarView.swift
//  Vitis
//
//  My Cellar: tasting history with rating and notes. Add wines via +.
//

import SwiftUI

struct CellarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = CellarViewModel()
    @State private var showAddWine = false
    @State private var showFilters = false

    var body: some View {
        ZStack {
            VitisTheme.background(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSessionReady)) { _ in
            Task { await viewModel.load() }
        }
        .onChange(of: viewModel.sortOption) { _, _ in
            viewModel.groupTastingsByCategory()
        }
        .onChange(of: viewModel.ratingFilter) { _, _ in
            viewModel.groupTastingsByCategory()
        }
        .sheet(isPresented: $showAddWine) {
            AddWineSheet(
                isPresented: $showAddWine,
                tastedWineIds: Set(viewModel.tastings.map(\.wineId)),
                onWineAdded: {
                    Task { await viewModel.load() }
                }
            )
        }
        .sheet(isPresented: $showFilters) {
            CellarFilterSheet(
                sortOption: $viewModel.sortOption,
                ratingFilter: $viewModel.ratingFilter,
                isPresented: $showFilters
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("My Cellar")
                .font(VitisTheme.titleFont())
                .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
            Spacer()
            if !viewModel.needsAuth, let _ = viewModel.currentUserId {
                HStack(spacing: 12) {
                    if !viewModel.tastings.isEmpty {
                        Button {
                            showFilters = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 22))
                                .foregroundStyle(VitisTheme.accent(for: colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showAddWine = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(VitisTheme.accent(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
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
                .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
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
                .tint(VitisTheme.accent(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.tastings.isEmpty {
            emptyState
        } else {
            listContent
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wineglass")
                .font(.system(size: 48))
                .foregroundStyle(VitisTheme.secondaryText(for: colorScheme).opacity(0.35))
                .padding(.top, 40)
            VStack(spacing: 8) {
                Text("Your cellar is empty")
                    .font(VitisTheme.uiFont(size: 18, weight: .medium))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                Text("Log wines you've tasted to build your collection.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                showAddWine = true
            } label: {
                Text("Log a wine")
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(VitisTheme.accent(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listContent: some View {
        CellarListView(
            groupedTastings: viewModel.groupedTastings,
            currentUserId: viewModel.currentUserId,
            allowSwipeToDelete: true,
            onDelete: { tasting in
                await viewModel.removeTasting(tasting)
            }
        )
    }
}

struct CellarFilterSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var sortOption: CellarViewModel.SortOption
    @Binding var ratingFilter: CellarViewModel.RatingFilter
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    // Sort Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sort By")
                            .font(VitisTheme.uiFont(size: 15, weight: .semibold))
                            .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                        
                        ForEach(CellarViewModel.SortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                        .font(VitisTheme.uiFont(size: 15))
                                        .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                                    Spacer()
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(VitisTheme.accent(for: colorScheme))
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(sortOption == option ? VitisTheme.surfaceSelected(for: colorScheme) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Rating Filter Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rating Filter")
                            .font(VitisTheme.uiFont(size: 15, weight: .semibold))
                            .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                        
                        ForEach(CellarViewModel.RatingFilter.allCases, id: \.self) { filter in
                            Button {
                                ratingFilter = filter
                            } label: {
                                HStack {
                                    Text(filter.rawValue)
                                        .font(VitisTheme.uiFont(size: 15))
                                        .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                                    Spacer()
                                    if ratingFilter == filter {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(VitisTheme.accent(for: colorScheme))
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(ratingFilter == filter ? VitisTheme.surfaceSelected(for: colorScheme) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .background(VitisTheme.backgroundPrimary(for: colorScheme))
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundStyle(VitisTheme.accent(for: colorScheme))
                }
            }
        }
    }
}

#Preview {
    CellarView()
}
