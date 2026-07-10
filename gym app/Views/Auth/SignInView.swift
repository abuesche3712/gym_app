//
//  SignInView.swift
//  gym app
//
//  Sign in view with Apple Sign In
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared

    var body: some View {
        VStack(spacing: AppSpacing.xxl) {
            Spacer()

            // App logo/title
            VStack(spacing: 16) {
                Image(systemName: "dumbbell.fill")
                    .displayLarge(color: AppColors.dominant)

                Text("Gym App")
                    .displayLarge(color: AppColors.textPrimary)
                    .fontWeight(.bold)

                Text("Track your workouts and progress")
                    .subheadline(color: AppColors.textSecondary)
            }

            Spacer()

            // Sign in section
            VStack(spacing: AppSpacing.lg) {
                SignInWithAppleButton(.signIn) { request in
                    authService.prepareAppleSignInRequest(request)
                } onCompletion: { result in
                    Task {
                        await handleSignInResult(result)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(AppCorners.medium)

                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }

                if let error = authService.error {
                    Text(error.localizedDescription)
                        .caption(color: AppColors.error)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, AppSpacing.xxl)

            // Skip button
            Button {
                dismiss()
            } label: {
                Text("Continue without signing in")
                    .subheadline(color: AppColors.textSecondary)
            }

            // Legal links
            Text(.init("By continuing, you agree to our [Terms of Service](\(AppURLs.termsOfService.absoluteString)) and [Privacy Policy](\(AppURLs.privacyPolicy.absoluteString))"))
                .caption(color: AppColors.textTertiary)
                .tint(AppColors.dominant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xxl)

            Spacer()
                .frame(height: AppSpacing.xxl)
        }
        .padding()
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }

    @MainActor
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            do {
                try await authService.handleAppleAuthorization(authorization)
            } catch {
                Logger.error(error, context: "handleAppleAuthorization")
            }
        case .failure(let error):
            Logger.error(error, context: "signInWithApple")
        }
    }
}

#Preview {
    SignInView()
}
