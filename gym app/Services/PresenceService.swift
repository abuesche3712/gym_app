//
//  PresenceService.swift
//  gym app
//
//  Manages user online/offline presence and last-seen timestamps
//

import Foundation
import FirebaseFirestore

@MainActor
class PresenceService: ObservableObject {
    static let shared = PresenceService()

    private let core = FirestoreCore.shared
    private let authService = AuthService.shared

    private var currentUserId: String? { authService.currentUser?.uid }

    // MARK: - Presence Updates

    func goOnline() {
        guard let userId = currentUserId else { return }

        let ref = core.db.collection(FirestoreCollections.presence).document(userId)
        ref.setData([
            "isOnline": true,
            "lastSeen": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func goOffline() {
        guard let userId = currentUserId else { return }

        let ref = core.db.collection(FirestoreCollections.presence).document(userId)
        ref.setData([
            "isOnline": false,
            "lastSeen": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Fetch & Listen

    func fetchPresence(userId: String) async -> (isOnline: Bool, lastSeen: Date?) {
        do {
            let doc = try await core.db.collection(FirestoreCollections.presence).document(userId).getDocument()
            guard let data = doc.data() else { return (false, nil) }

            let isOnline = data["isOnline"] as? Bool ?? false
            let lastSeen = (data["lastSeen"] as? Timestamp)?.dateValue()
            return (isOnline, lastSeen)
        } catch {
            Logger.error(error, context: "PresenceService.fetchPresence")
            return (false, nil)
        }
    }

    func listenToPresence(userId: String, onChange: @escaping (Bool, Date?) -> Void) -> ListenerRegistration {
        core.db.collection(FirestoreCollections.presence).document(userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.error(error, context: "PresenceService.listenToPresence")
                    return
                }

                guard let data = snapshot?.data() else {
                    onChange(false, nil)
                    return
                }

                let isOnline = data["isOnline"] as? Bool ?? false
                let lastSeen = (data["lastSeen"] as? Timestamp)?.dateValue()
                onChange(isOnline, lastSeen)
            }
    }

    // MARK: - Typing Indicators

    func setTypingStatus(conversationId: UUID, userId: String, isTyping: Bool) {
        let ref = core.db.collection(FirestoreCollections.conversations)
            .document(conversationId.uuidString)
            .collection(FirestoreCollections.typing)
            .document(userId)

        ref.setData([
            "isTyping": isTyping,
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func listenToTypingStatus(conversationId: UUID, otherUserId: String, onChange: @escaping (Bool) -> Void) -> ListenerRegistration {
        core.db.collection(FirestoreCollections.conversations)
            .document(conversationId.uuidString)
            .collection(FirestoreCollections.typing)
            .document(otherUserId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.error(error, context: "PresenceService.listenToTypingStatus")
                    return
                }

                guard let data = snapshot?.data() else {
                    onChange(false)
                    return
                }

                let isTyping = data["isTyping"] as? Bool ?? false

                // Check staleness (>10s means not actually typing)
                if let lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue() {
                    let elapsed = Date().timeIntervalSince(lastUpdated)
                    if elapsed > 10 {
                        onChange(false)
                        return
                    }
                }

                onChange(isTyping)
            }
    }

    // MARK: - Helpers

    static func formatLastSeen(_ date: Date) -> String {
        let now = Date()
        let seconds = now.timeIntervalSince(date)

        if seconds < 60 {
            return "Active now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "Active \(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "Active \(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            if days == 1 {
                return "Active yesterday"
            }
            return "Active \(days)d ago"
        }
    }
}
