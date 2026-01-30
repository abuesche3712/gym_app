//
//  AuthService.swift
//  gym app
//
//  Authentication service with Sign in with Apple
//

import Foundation
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore

@preconcurrency @MainActor
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAuthStateReady = false  // True after initial auth state is determined

    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var authStateContinuation: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        setupAuthStateListener()
    }

    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }

    // MARK: - Auth State

    private func setupAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                if let user = user {
                    self?.currentUser = User(
                        uid: user.uid,
                        email: user.email,
                        displayName: user.displayName
                    )
                } else {
                    self?.currentUser = nil
                }

                // Mark auth state as ready and resume any waiting tasks
                if self?.isAuthStateReady == false {
                    self?.isAuthStateReady = true
                    self?.authStateContinuation?.resume(returning: self?.isAuthenticated ?? false)
                    self?.authStateContinuation = nil
                }
            }
        }
    }

    /// Wait for Firebase to restore auth state (returns isAuthenticated)
    func waitForAuthState() async -> Bool {
        if isAuthStateReady {
            return isAuthenticated
        }

        return await withCheckedContinuation { continuation in
            self.authStateContinuation = continuation
        }
    }

    var uid: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Sign in with Apple

    /// Handle authorization result from SwiftUI's SignInWithAppleButton
    func handleAppleAuthorization(_ authorization: ASAuthorization) async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            try await processAppleCredential(from: authorization)
        } catch {
            self.error = error
            throw error
        }
    }

    /// Legacy method for programmatic sign in (not recommended)
    func signInWithApple() async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let result = try await performAppleSignIn(request: request)
        try await processAppleCredential(from: result)
    }

    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)

            // Keep delegate alive
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

            controller.delegate = delegate
            controller.performRequests()
        }
    }

    private func processAppleCredential(from authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nil,
            fullName: appleIDCredential.fullName
        )

        let authResult = try await Auth.auth().signIn(with: credential)

        // Save displayName to Firebase Auth user profile (Apple only provides name on first sign-in)
        if let fullName = appleIDCredential.fullName,
           authResult.user.displayName == nil || authResult.user.displayName?.isEmpty == true {
            let formatter = PersonNameComponentsFormatter()
            let displayName = formatter.string(from: fullName)
            if !displayName.isEmpty {
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try? await changeRequest.commitChanges()
                Logger.debug("Saved displayName to Firebase Auth user profile")
            }
        }

        // Create user document on first sign-in
        await createUserDocumentIfNeeded(
            uid: authResult.user.uid,
            email: appleIDCredential.email,
            fullName: appleIDCredential.fullName
        )
    }

    private func createUserDocumentIfNeeded(uid: String, email: String?, fullName: PersonNameComponents?) async {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        do {
            let document = try await userRef.getDocument()

            if !document.exists {
                // First sign-in - create user document
                var userData: [String: Any] = [
                    "uid": uid,
                    "createdAt": FieldValue.serverTimestamp(),
                    "lastSignIn": FieldValue.serverTimestamp()
                ]

                if let email = email {
                    userData["email"] = email
                }

                if let fullName = fullName {
                    let formatter = PersonNameComponentsFormatter()
                    userData["displayName"] = formatter.string(from: fullName)
                }

                try await userRef.setData(userData)
                Logger.debug("Created new user document for \(Logger.redactUserID(uid))")
            } else {
                // Existing user - update last sign in
                try await userRef.updateData([
                    "lastSignIn": FieldValue.serverTimestamp()
                ])
            }
        } catch {
            Logger.error(error, context: "createOrUpdateUserDocument")
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }

        // Delete user data from Firestore
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        // Delete subcollections
        let subcollections = ["modules", "workouts", "sessions", "customExercises", "programs", "scheduledWorkouts"]
        for collection in subcollections {
            let snapshot = try await userRef.collection(collection).getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        }

        // Delete user document
        try await userRef.delete()

        // Delete Firebase Auth account
        try await user.delete()

        currentUser = nil
        isAuthenticated = false
    }
}

// MARK: - Apple Sign In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

// MARK: - User Model

struct User: Identifiable, Codable {
    let uid: String
    let email: String?
    let displayName: String?

    var id: String { uid }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case notAuthenticated
    case signInFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credentials received from Apple Sign In."
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        }
    }
}
