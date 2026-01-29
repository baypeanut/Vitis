//
//  DuelView.swift
//  Vitis
//
//  Side-by-side comparison screen: two wine cards, minimal UI, Quiet Luxury.
//

import SwiftUI

struct DuelView: View {
    @State private var viewModel = DuelViewModel()
    @State private var showAddWine = false

    var body: some View {
        ZStack {
            VitisTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 32)
                content
                Spacer(minLength: 32)
                footer
            }
            .padding(.horizontal, 24)
        }
        .task {
            await viewModel.loadNextPair()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSessionReady)) { _ in
            Task { await viewModel.loadNextPair() }
        }
        .sheet(isPresented: $showAddWine) {
            AddWineSheet(isPresented: $showAddWine) {
                Task { await viewModel.loadNextPair() }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Which do you prefer?")
                .font(VitisTheme.titleFont())
                .foregroundStyle(.primary)
            Spacer()
            Button {
                showAddWine = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(VitisTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.needsAuth {
            Text("Sign in to rank wines.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .padding(.vertical, 40)
        } else if let err = viewModel.errorMessage, viewModel.wineA == nil && !viewModel.isLoading {
            Text(err)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
        } else if viewModel.isLoading && viewModel.wineA == nil {
            progressView
        } else if let a = viewModel.wineA, let b = viewModel.wineB {
            HStack(spacing: 16) {
                WineCardView(
                    wine: a,
                    isSelected: viewModel.selectedWinnerID == a.id,
                    showNewEntryLabel: viewModel.wineAIsNew,
                    onTap: { viewModel.selectWinner(a.id) }
                )

                Text("vs")
                    .font(VitisTheme.detailFont())
                    .foregroundStyle(VitisTheme.secondaryText)

                WineCardView(
                    wine: b,
                    isSelected: viewModel.selectedWinnerID == b.id,
                    onTap: { viewModel.selectWinner(b.id) }
                )
            }
        } else {
            EmptyView()
        }
    }

    private var progressView: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(VitisTheme.accent)
            .scaleEffect(1.2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
    }

    @ViewBuilder
    private var footer: some View {
        if !viewModel.needsAuth, viewModel.wineA != nil {
            VStack(spacing: 12) {
                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                Button {
                    Task { await viewModel.submitComparison() }
                } label: {
                    Text("Submit")
                        .font(.system(.body, design: .serif, weight: .medium))
                        .foregroundStyle(viewModel.canSubmit ? .white : VitisTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.canSubmit ? VitisTheme.accent : Color(white: 0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!viewModel.canSubmit || viewModel.isLoading)
                .buttonStyle(.plain)
            }
            .padding(.bottom, 32)
        } else {
            Color.clear.frame(height: 1).padding(.bottom, 32)
        }
    }
}

#Preview {
    DuelView()
}
