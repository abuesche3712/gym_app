//
//  AuthService.swift
//  gym app
//
//  Authentication service with Sign in with Apple
//

import Foundation
import CoreData
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Security

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
    private var lastObservedUserId: String?
    private var currentNonce: String?

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
                let newUserId = user?.uid
                if self?.lastObservedUserId != newUserId {
                    ProfileCacheService.shared.clearCache()
                    self?.lastObservedUserId = newUserId
                }

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
        prepareAppleSignInRequest(request)

        let result = try await performAppleSignIn(request: request)
        try await processAppleCredential(from: result)
    }

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
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

        guard let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }
        defer { currentNonce = nil }

        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
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

        // Save FCM token for push notifications
        await PushNotificationService.shared.saveFCMToken()
    }

    private func createUserDocumentIfNeeded(uid: String, email: String?, fullName: PersonNameComponents?) async {
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(uid)

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
        // Clear FCM token before signing out (fire-and-forget)
        Task { await PushNotificationService.shared.clearFCMToken() }

        ProfileCacheService.shared.clearCache()
        try Auth.auth().signOut()
        lastObservedUserId = nil
        currentUser = nil
        isAuthenticated = false

        // Tell any still-mounted ViewModels (chat, friends, conversations, activity)
        // holding Firestore listeners to tear them down now, so they don't keep
        // streaming cloud data into shared CoreData after a different account signs in.
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    }

    // MARK: - Re-authentication

    /// Re-authenticate the current user with Apple credentials (required before sensitive operations like account deletion)
    func reauthenticate(with authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        guard let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }
        defer { currentNonce = nil }

        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        try await Auth.auth().currentUser?.reauthenticate(with: credential)
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }

        let db = Firestore.firestore()
        let uid = user.uid
        let userRef = db.collection(FirestoreCollections.users).document(uid)
        var deletionErrors: [String] = []

        // 1. Clear FCM token
        await PushNotificationService.shared.clearFCMToken()

        // 2. Delete user-scoped subcollections
        let subcollections = [
            FirestoreCollections.modules,
            FirestoreCollections.workouts,
            FirestoreCollections.sessions,
            FirestoreCollections.customExercises,
            FirestoreCollections.programs,
            FirestoreCollections.scheduledWorkouts,
            FirestoreCollections.profile,
            FirestoreCollections.exerciseLibrary,
            FirestoreCollections.deletions,
            FirestoreCollections.activities
        ]
        for collection in subcollections {
            do {
                try await deleteSubcollection(userRef.collection(collection), db: db)
            } catch {
                Logger.error(error, context: "deleteAccount: failed to delete subcollection \(collection)")
                deletionErrors.append(collection)
            }
        }

        // 3. Delete user's posts and their nested likes/comments
        do {
            let postsSnapshot = try await db.collection(FirestoreCollections.posts)
                .whereField("authorId", isEqualTo: uid)
                .getDocuments()
            for doc in postsSnapshot.documents {
                let postRef = doc.reference
                try await deleteSubcollection(postRef.collection(FirestoreCollections.likes), db: db)
                try await deleteSubcollection(postRef.collection(FirestoreCollections.comments), db: db)
                try await postRef.delete()
            }
        } catch {
            Logger.error(error, context: "deleteAccount: failed to delete posts")
            deletionErrors.append("posts")
        }

        // 4. Delete friendships involving the user
        do {
            let requestedSnapshot = try await db.collection(FirestoreCollections.friendships)
                .whereField("requesterId", isEqualTo: uid)
                .getDocuments()
            let receivedSnapshot = try await db.collection(FirestoreCollections.friendships)
                .whereField("addresseeId", isEqualTo: uid)
                .getDocuments()
            let allFriendshipDocs = requestedSnapshot.documents + receivedSnapshot.documents
            for doc in allFriendshipDocs {
                try await doc.reference.delete()
            }
        } catch {
            Logger.error(error, context: "deleteAccount: failed to delete friendships")
            deletionErrors.append("friendships")
        }

        // 5. Delete conversations the user is part of (and their messages/typing)
        do {
            let convSnapshot = try await db.collection(FirestoreCollections.conversations)
                .whereField("participantIds", arrayContains: uid)
                .getDocuments()
            for doc in convSnapshot.documents {
                let convRef = doc.reference
                try await deleteSubcollection(convRef.collection(FirestoreCollections.messages), db: db)
                try await deleteSubcollection(convRef.collection(FirestoreCollections.typing), db: db)
                try await convRef.delete()
            }
        } catch {
            Logger.error(error, context: "deleteAccount: failed to delete conversations")
            deletionErrors.append("conversations")
        }

        // 6. Delete username claim
        do {
            let usernameSnapshot = try await db.collection(FirestoreCollections.usernames)
                .whereField("userId", isEqualTo: uid)
                .getDocuments()
            for doc in usernameSnapshot.documents {
                try await doc.reference.delete()
            }
        } catch {
            Logger.error(error, context: "deleteAccount: failed to delete username claim")
            deletionErrors.append("usernames")
        }

        // 7. Delete presence document
        do {
            try await db.collection(FirestoreCollections.presence).document(uid).delete()
        } catch {
            Logger.error(error, context: "deleteAccount: failed to delete presence")
            deletionErrors.append("presence")
        }

        // 8. Delete profile photo from Firebase Storage
        do {
            let storageRef = Storage.storage().reference().child("profile-photos/\(uid).jpg")
            try await storageRef.delete()
        } catch let error as NSError {
            // Ignore "object not found" (no photo uploaded) and permission errors
            if error.code != StorageErrorCode.objectNotFound.rawValue &&
               error.code != StorageErrorCode.unauthorized.rawValue {
                Logger.error(error, context: "deleteAccount: failed to delete profile photo")
                deletionErrors.append("storage")
            }
        }

        if !deletionErrors.isEmpty {
            Logger.error("deleteAccount failed before account deletion: \(deletionErrors.joined(separator: ", "))")
            throw AuthError.deletionFailed("Some account data could not be deleted. Please try again or contact support.")
        }

        // 9. Delete the user document itself
        try await userRef.delete()

        // 10. Delete the Firebase Auth account
        do {
            try await user.delete()
        } catch {
            let nsError = error as NSError
            if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw AuthError.requiresReauthentication
            }
            throw error
        }

        // 11. Clear local state
        clearLocalData()
    }

    /// Batch-delete all documents in a subcollection
    private func deleteSubcollection(_ collectionRef: CollectionReference, db: Firestore, batchSize: Int = 400) async throws {
        while true {
            let snapshot = try await collectionRef.limit(to: batchSize).getDocuments()
            if snapshot.documents.isEmpty { return }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
    }

    /// Clear all local data stores (CoreData, UserDefaults, caches)
    private func clearLocalData() {
        // Clear CoreData
        let context = PersistenceController.shared.container.viewContext
        let entityNames = PersistenceController.shared.container.managedObjectModel.entities.compactMap { $0.name }
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                let objects = try context.fetch(fetchRequest)
                for object in objects {
                    context.delete(object)
                }
            } catch {
                Logger.error(error, context: "AuthService.clearLocalData: failed to fetch \(entityName) for deletion")
            }
        }

        do {
            try context.save()
        } catch {
            Logger.error(error, context: "AuthService.clearLocalData: failed to save context after deleting local entities")
        }

        // Clear user-specific UserDefaults
        let userDefaultsKeys = [
            "weightUnit", "distanceUnit", "defaultRestTime", "lastSyncDate",
            "pushNotificationPermissionRequested", "scheduledWorkoutsKey",
            "draftCaptionKey", "friendIdsMigratedKey",
            "deletedModuleIds", "deletedWorkoutIds", "deletedProgramIds",
            "deletedSessionIds", "deletedScheduledWorkoutIdsKey",
            "analytics_trainingExpanded", "analytics_strengthExpanded",
            "analytics_engineExpanded"
        ]
        for key in userDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Clear caches and in-memory state
        ProfileCacheService.shared.clearCache()
        DataRepository.shared.loadAllData()

        lastObservedUserId = nil
        currentUser = nil
        isAuthenticated = false

        // deleteAccount() doesn't route through signOut(), so post here too — any
        // still-mounted ViewModel holding a Firestore listener needs to tear it down.
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
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

// MARK: - Notification Names

extension Notification.Name {
    /// Posted from `signOut()` and `deleteAccount()` once the local auth state has been
    /// cleared. ViewModels holding Firestore listeners (chat, friends, conversations,
    /// activity) observe this to stop their listeners and clear published state before
    /// a different account can sign in and start writing into shared CoreData.
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case notAuthenticated
    case requiresReauthentication
    case signInFailed(String)
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credentials received from Apple Sign In."
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .requiresReauthentication:
            return "For security, please verify your identity to complete this action."
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .deletionFailed(let message):
            return "Account deletion failed: \(message)"
        }
    }
}
