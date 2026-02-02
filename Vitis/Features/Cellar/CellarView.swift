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
    @State private var showFilters = false

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
            AddWineSheet(isPresented: $showAddWine) {
                Task { await viewModel.load() }
            }
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
                .foregroundStyle(.primary)
            Spacer()
            if !viewModel.needsAuth, let _ = viewModel.currentUserId {
                HStack(spacing: 12) {
                    if !viewModel.tastings.isEmpty {
                        Button {
                            showFilters = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 22))
                                .foregroundStyle(VitisTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
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
                            .foregroundStyle(.primary)
                        
                        ForEach(CellarViewModel.SortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                        .font(VitisTheme.uiFont(size: 15))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(VitisTheme.accent)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(sortOption == option ? VitisTheme.accent.opacity(0.1) : Color.clear)
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
                            .foregroundStyle(.primary)
                        
                        ForEach(CellarViewModel.RatingFilter.allCases, id: \.self) { filter in
                            Button {
                                ratingFilter = filter
                            } label: {
                                HStack {
                                    Text(filter.rawValue)
                                        .font(VitisTheme.uiFont(size: 15))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if ratingFilter == filter {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(VitisTheme.accent)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(ratingFilter == filter ? VitisTheme.accent.opacity(0.1) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .background(VitisTheme.background)
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundStyle(VitisTheme.accent)
                }
            }
        }
    }
}

#Preview {
    CellarView()
}
