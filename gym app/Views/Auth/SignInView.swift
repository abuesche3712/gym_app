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
        VStack(spacing: 40) {
            Spacer()

            // App logo/title
            VStack(spacing: 16) {
                Image(systemName: "dumbbell.fill")
                    .displayLarge(color: AppColors.dominant)

                Text("Gym App")
                    .font(.largeTitle.bold())

                Text("Track your workouts and progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sign in section
            VStack(spacing: 20) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task {
                        await handleSignInResult(result)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(10)

                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }

                if let error = authService.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)

            // Skip button
            Button {
                dismiss()
            } label: {
                Text("Continue without signing in")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
                .frame(height: 40)
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
