//
//  AuthService.swift
//  gym app
//
//  Authentication service with Sign in with Apple
//

import Foundation
import CoreData
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

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

        // 9. Delete the user document itself
        try await userRef.delete()

        // 10. Delete the Firebase Auth account
        try await user.delete()

        // 11. Clear local state
        clearLocalData()

        if !deletionErrors.isEmpty {
            Logger.error("deleteAccount completed with partial failures: \(deletionErrors.joined(separator: ", "))")
        }
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
            if let objects = try? context.fetch(fetchRequest) {
                for object in objects {
                    context.delete(object)
                }
            }
        }
        try? context.save()

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
