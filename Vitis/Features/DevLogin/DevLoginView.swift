//
//  DevLoginView.swift
//  Vitis
//
//  Dev-only login: username or email → find dev account → set dev user id, enter app.
//

import SwiftUI

struct DevLoginView: View {
    @Binding var isPresented: Bool
    @State private var viewModel = DevLoginViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    SerifTitleText(title: "Log in")
                    Text("Enter your username or email.")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText)

                    UnderlineTextField(
                        placeholder: "Username or email",
                        text: $viewModel.identifier,
                        textContentType: .username,
                        autocapitalization: .never
                    )
                    .onChange(of: viewModel.identifier) { _, _ in viewModel.errorMessage = nil }

                    if let err = viewModel.errorMessage {
                        Text(err)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(.red)
                    }

                    PrimaryButton("Log in", enabled: !viewModel.identifier.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isLoading) {
                        Task { await viewModel.submit() }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                if viewModel.isLoading {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.2)
                }
            }
            .navigationTitle("Log in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accent)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vitisSessionReady)) { _ in
            isPresented = false
        }
    }
}
