//
//  ReauthenticationView.swift
//  gym app
//
//  Re-authentication sheet for sensitive operations like account deletion
//

import SwiftUI
import AuthenticationServices

struct ReauthenticationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = AuthService.shared
    @State private var errorMessage: String?
    @State private var isProcessing = false

    let onSuccess: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Spacer()

                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.dominant)

                    Text("Verify Your Identity")
                        .headline(color: AppColors.textPrimary)
                        .fontWeight(.bold)

                    Text("For security, please sign in again to delete your account.")
                        .subheadline(color: AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: AppSpacing.md) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task {
                            await handleReauthResult(result)
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(AppCorners.medium)
                    .disabled(isProcessing)

                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .caption(color: AppColors.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, AppSpacing.xl)

                Spacer()
                    .frame(height: AppSpacing.xl)
            }
            .padding(AppSpacing.screenPadding)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Verify Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    @MainActor
    private func handleReauthResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            isProcessing = true
            errorMessage = nil
            do {
                try await authService.reauthenticate(with: authorization)
                dismiss()
                onSuccess()
            } catch {
                Logger.error(error, context: "ReauthenticationView.reauthenticate")
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        case .failure(let error):
            Logger.error(error, context: "ReauthenticationView.signIn")
            errorMessage = error.localizedDescription
        }
    }
}
