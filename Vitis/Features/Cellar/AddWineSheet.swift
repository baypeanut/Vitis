//
//  AddWineSheet.swift
//  Vitis
//
//  Debounced OFF search, select → upsert. Quiet Luxury.
//

import SwiftUI

struct AddWineSheet: View {
    @Binding var isPresented: Bool
    var onWineAdded: () -> Void
    /// When adding from Cellar: (userId, status). Sheet upserts wine then adds to cellar.
    var cellarContext: (userId: UUID, status: CellarItem.CellarStatus)?

    @State private var viewModel = AddWineViewModel()

    init(isPresented: Binding<Bool>, cellarContext: (userId: UUID, status: CellarItem.CellarStatus)? = nil, onWineAdded: @escaping () -> Void) {
        _isPresented = isPresented
        self.cellarContext = cellarContext
        self.onWineAdded = onWineAdded
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    Rectangle().fill(VitisTheme.border).frame(height: 1)
                    content
                }
                if viewModel.isUpserting {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView().progressViewStyle(.circular).tint(VitisTheme.accent).scaleEffect(1.2)
                }
            }
            .navigationTitle("Add Wine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accent)
                }
            }
        }
        .onChange(of: viewModel.query) { _, _ in viewModel.search() }
        .onAppear { viewModel.prefetchPopular() }
    }

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(VitisTheme.secondaryText)
                TextField("Search wines…", text: $viewModel.query)
                    .font(VitisTheme.uiFont(size: 16))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(white: 0.97))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .tint(VitisTheme.accent)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let err = viewModel.errorMessage {
            Text(err)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.results.isEmpty {
            if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isLoading {
                Text("Aranıyor…")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No wines found.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.results) { p in
                        row(p)
                        Rectangle().fill(VitisTheme.border).frame(height: 1).padding(.leading, 24)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    private func row(_ p: OFFProduct) -> some View {
        Button {
            Task {
                do {
                    let wine = try await viewModel.upsert(product: p)
                    if let ctx = cellarContext {
                        try await CellarService.addToCellar(userId: ctx.userId, wineId: wine.id, status: ctx.status)
                    }
                    onWineAdded()
                    isPresented = false
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                thumbnail(p.imageUrl)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.brands ?? "Unknown")
                        .font(VitisTheme.producerSerifFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                    Text(p.productName ?? "Unknown")
                        .font(VitisTheme.wineNameFont())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUpserting)
    }

    private func thumbnail(_ urlString: String?) -> some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: placeholder
                    }
                }
            } else { placeholder }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(white: 0.94))
            .overlay(Image(systemName: "wineglass.fill").font(.system(size: 20)).foregroundStyle(VitisTheme.secondaryText.opacity(0.6)))
    }
}
