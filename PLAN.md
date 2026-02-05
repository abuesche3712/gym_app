# Implementation Plan: Social & Messaging Infrastructure Bugs

## Summary

Six bugs in social features that cause data inconsistency, stale state, and broken functionality. Based on code analysis, **BUG 3 is already fixed**. The remaining 5 bugs need implementation.

**Priority order:** 6 > 1 > 5 > 4 > 2

---

## Status Overview

| Bug | Description | Status | Complexity |
|-----|-------------|--------|------------|
| BUG 3 | Firestore in-query limit | ✅ FIXED | - |
| BUG 6 | Unread counts never increment | ✅ FIXED | High |
| BUG 1 | Friend deletions don't remove local cache | ✅ FIXED | Medium |
| BUG 5 | sendSharedContent doesn't update Firestore | ✅ FIXED | Low |
| BUG 4 | Duplicate conversations across devices | ✅ FIXED | Medium |
| BUG 2 | Feed listener uses stale friend IDs | ✅ FIXED | Medium |

---

## BUG 3: Firestore in-query Limit — ALREADY FIXED ✅

**Location:** `gym app/Services/Firebase/FirestoreFeedService.swift`

The batching is already implemented:
- Lines 20-21: `private let firestoreInQueryLimit = 30`
- `fetchFeedPosts()` (lines 34-65): Batches friend IDs, runs parallel queries, merges results
- `listenToFeedPosts()` (lines 86-129): Creates multiple listeners, merges via `CompositeListenerRegistration`
- `chunked(into:)` helper extension (lines 387-394)

**No action needed.**

---

## BUG 6: Unread Counts Never Increment

### Problem Analysis

Current state:
- `Conversation.unreadCount` is local-only (line 21 in `Conversation.swift`)
- `ConversationRepository.incrementUnreadCount()` exists but is never called
- No listener for incoming messages when chat is closed
- Recipient has no way to know about new messages

### Implementation Plan

#### Step 6.1: Add per-user unread counts to Firestore schema

**File:** `gym app/Services/Firebase/FirestoreMessagingService.swift`

Update `encodeConversation()` to include unread counts map:
```swift
// Add to conversation document structure:
// "unreadCounts": { "userIdA": 0, "userIdB": 2 }
```

Update `decodeConversation()` to extract current user's unread count.

#### Step 6.2: Update unread count when sending message

**File:** `gym app/Services/Firebase/FirestoreMessagingService.swift`

Add method `updateConversationOnNewMessage()`:
```swift
func updateConversationOnNewMessage(
    conversationId: UUID,
    senderId: String,
    recipientId: String,
    preview: String
) async throws {
    let ref = core.db.collection("conversations").document(conversationId.uuidString)
    try await ref.updateData([
        "lastMessageAt": FieldValue.serverTimestamp(),
        "lastMessagePreview": String(preview.prefix(50)),
        "unreadCounts.\(recipientId)": FieldValue.increment(Int64(1))
    ])
}
```

#### Step 6.3: Call update method from ChatViewModel

**File:** `gym app/ViewModels/ChatViewModel.swift`

Update `sendMessage()` and `sendSharedContent()` to call the new method after saving the message.

#### Step 6.4: Reset unread count when opening conversation

**File:** `gym app/Services/Firebase/FirestoreMessagingService.swift`

Add method:
```swift
func resetUnreadCount(conversationId: UUID, userId: String) async throws {
    let ref = core.db.collection("conversations").document(conversationId.uuidString)
    try await ref.updateData([
        "unreadCounts.\(userId)": 0
    ])
}
```

**File:** `gym app/ViewModels/ChatViewModel.swift`

Call `resetUnreadCount()` in `loadMessages()`.

#### Step 6.5: Update conversation listener to read unread counts

**File:** `gym app/Services/Firebase/FirestoreMessagingService.swift`

Update `decodeConversation()` to extract unread count for the listening user. This requires passing the current user ID to the decode function or handling it in the listener.

### Files Changed
- `gym app/Services/Firebase/FirestoreMessagingService.swift`
- `gym app/ViewModels/ChatViewModel.swift`
- `gym app/ViewModels/ConversationsViewModel.swift`
- `gym app/Models/Conversation.swift` (may need to add `unreadCounts` field for cloud storage)

---

## BUG 1: Friend Deletions Don't Remove Local Cache

### Problem Analysis

**Current flow in `FriendsViewModel.handleFriendshipsUpdate()` (lines 92-102):**
```swift
private func handleFriendshipsUpdate(_ cloudFriendships: [Friendship], userId: String) {
    // Update local cache with cloud data
    for friendship in cloudFriendships {
        friendshipRepo.updateFromCloud(friendship)  // Only adds/updates, never removes!
    }
    // ...
}
```

The listener callback provides the complete set of friendships from Firestore. If a friendship was deleted, it simply won't be in `cloudFriendships`. But the code only updates existing items—it never removes items that are no longer in the cloud.

### Implementation Plan

#### Step 1.1: Detect and remove deleted friendships

**File:** `gym app/ViewModels/FriendsViewModel.swift`

Update `handleFriendshipsUpdate()`:
```swift
private func handleFriendshipsUpdate(_ cloudFriendships: [Friendship], userId: String) {
    // Get IDs that exist in cloud
    let cloudIds = Set(cloudFriendships.map { $0.id })

    // Get IDs that exist locally for this user
    let localFriendships = friendshipRepo.getAllFriendships(for: userId)
    let localIds = Set(localFriendships.map { $0.id })

    // Delete local friendships that no longer exist in cloud
    let deletedIds = localIds.subtracting(cloudIds)
    for deletedId in deletedIds {
        friendshipRepo.deleteFromCloud(id: deletedId)
    }

    // Update local cache with cloud data
    for friendship in cloudFriendships {
        friendshipRepo.updateFromCloud(friendship)
    }

    // Categorize and load profiles
    Task {
        await categorizeAndLoadProfiles(cloudFriendships, userId: userId)
    }
}
```

#### Step 1.2: Verify deleteFromCloud method exists

**File:** `gym app/Repositories/FriendshipRepository.swift`

Method already exists at lines 253-259:
```swift
func deleteFromCloud(id: UUID) {
    if let entity = findEntity(id: id) {
        viewContext.delete(entity)
        persistence.save()
        loadAll()
    }
}
```

### Files Changed
- `gym app/ViewModels/FriendsViewModel.swift`

---

## BUG 5: sendSharedContent Doesn't Update Firestore Conversation

### Problem Analysis

**`sendMessage()` (lines 112-154):**
```swift
// ... saves message ...
// Also update conversation in cloud
if let updatedConversation = conversationRepo.getConversation(id: conversation.id) {
    try await firestoreService.saveConversation(updatedConversation)  // ✅
}
```

**`sendSharedContent()` (lines 156-193):**
```swift
// ... saves message ...
// Sync to cloud
do {
    try await firestoreService.saveMessage(message)
    // MISSING: firestoreService.saveConversation() call!
} catch {
    // ...
}
```

### Implementation Plan

#### Step 5.1: Add conversation update to sendSharedContent

**File:** `gym app/ViewModels/ChatViewModel.swift`

Update `sendSharedContent()` to match `sendMessage()` pattern:
```swift
func sendSharedContent(_ content: MessageContent) async throws {
    // ... existing code ...

    // Sync to cloud
    do {
        try await firestoreService.saveMessage(message)

        // Also update conversation in cloud (MISSING LINE - add this)
        if let updatedConversation = conversationRepo.getConversation(id: conversation.id) {
            try await firestoreService.saveConversation(updatedConversation)
        }
    } catch {
        Logger.error(error, context: "ChatViewModel.sendSharedContent")
    }
}
```

### Files Changed
- `gym app/ViewModels/ChatViewModel.swift`

---

## BUG 4: Duplicate Conversations Across Devices

### Problem Analysis

**Current conversation creation in `ConversationRepository.getOrCreateConversation()` (lines 87-98):**
```swift
func getOrCreateConversation(between userA: String, and userB: String) -> Conversation {
    if let existing = getConversation(between: userA, and: userB) {
        return existing
    }

    let conversation = Conversation(
        participantIds: [userA, userB],
        createdAt: Date()
    )  // Uses UUID() internally — random!

    save(conversation)
    return conversation
}
```

If user A starts a conversation from device 1 and device 2 simultaneously, both create different UUIDs → two conversations.

### Implementation Plan

#### Step 4.1: Generate canonical conversation ID

**File:** `gym app/Repositories/ConversationRepository.swift`

Update `getOrCreateConversation()`:
```swift
func getOrCreateConversation(between userA: String, and userB: String) -> Conversation {
    // Check local cache first
    if let existing = getConversation(between: userA, and: userB) {
        return existing
    }

    // Generate canonical ID from sorted participants
    let participants = [userA, userB].sorted()
    let canonicalId = Conversation.canonicalId(for: participants)

    // Check if conversation with canonical ID exists locally
    if let existingById = getConversation(id: canonicalId) {
        return existingById
    }

    let conversation = Conversation(
        id: canonicalId,
        participantIds: participants,
        createdAt: Date()
    )

    save(conversation)
    return conversation
}
```

#### Step 4.2: Add canonical ID generator to Conversation model

**File:** `gym app/Models/Conversation.swift`

Add static helper:
```swift
extension Conversation {
    /// Generates a deterministic UUID for a conversation between two users
    static func canonicalId(for participantIds: [String]) -> UUID {
        let sorted = participantIds.sorted()
        let combined = sorted.joined(separator: "_")

        // Create deterministic UUID using djb2 hash
        var hash: UInt64 = 5381
        for char in combined.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }

        // Convert hash to UUID bytes
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8((hash >> (i * 8)) & 0xFF)
        }
        // Fill second half with shifted hash
        let hash2 = hash &* 31
        for i in 0..<8 {
            bytes[8 + i] = UInt8((hash2 >> (i * 8)) & 0xFF)
        }

        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                          bytes[4], bytes[5], bytes[6], bytes[7],
                          bytes[8], bytes[9], bytes[10], bytes[11],
                          bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
```

#### Step 4.3: Update startConversation to handle cloud conflicts

**File:** `gym app/ViewModels/ConversationsViewModel.swift`

Update `startConversation()`:
```swift
func startConversation(with friendId: String) async throws -> Conversation {
    guard let userId = currentUserId else {
        throw ConversationError.notAuthenticated
    }

    if friendshipRepo.isBlockedByOrBlocking(userId, friendId) {
        throw ConversationError.userBlocked
    }

    // Generate canonical ID
    let participants = [userId, friendId].sorted()
    let canonicalId = Conversation.canonicalId(for: participants)

    // Try to fetch from Firestore first (in case other device created it)
    if let cloudConversation = try? await firestoreService.fetchConversation(id: canonicalId) {
        conversationRepo.updateFromCloud(cloudConversation)
        return cloudConversation
    }

    // Create locally with canonical ID
    let conversation = conversationRepo.getOrCreateConversation(between: userId, and: friendId)

    // Sync to cloud
    do {
        try await firestoreService.saveConversation(conversation)
    } catch {
        Logger.error(error, context: "ConversationsViewModel.startConversation")
    }

    return conversation
}
```

#### Step 4.4: Add fetchConversation method

**File:** `gym app/Services/Firebase/FirestoreMessagingService.swift`

Add single conversation fetch:
```swift
func fetchConversation(id: UUID) async throws -> Conversation? {
    let doc = try await core.db.collection("conversations").document(id.uuidString).getDocument()
    guard let data = doc.data() else { return nil }
    return decodeConversation(from: data)
}
```

### Files Changed
- `gym app/Models/Conversation.swift`
- `gym app/Repositories/ConversationRepository.swift`
- `gym app/ViewModels/ConversationsViewModel.swift`
- `gym app/Services/Firebase/FirestoreMessagingService.swift`

---

## BUG 2: Feed Listener Uses Stale Friend IDs

### Problem Analysis

**Current `loadFeed()` (lines 85-113):**
```swift
func loadFeed() {
    // Get friend IDs ONCE
    let friends = friendshipRepo.getAcceptedFriends(for: userId)
    var friendIds = friends.compactMap { $0.otherUserId(from: userId) }

    // Listener uses these captured friendIds forever
    feedListener = firestoreService.listenToFeedPosts(friendIds: friendIds, ...)
}
```

If user adds/removes friends, feed doesn't update until manual reload.

### Implementation Plan

#### Step 2.1: Observe friendship changes

**File:** `gym app/ViewModels/FeedViewModel.swift`

Add Combine subscription to friendship changes:
```swift
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    // ... existing properties ...

    private var friendshipCancellable: AnyCancellable?

    init(...) {
        // ... existing init ...
        setupFriendshipObserver()
    }

    private func setupFriendshipObserver() {
        friendshipCancellable = friendshipRepo.$friendships
            .dropFirst() // Skip initial value
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                // Friendships changed — restart feed listener
                self?.restartFeedListener()
            }
    }

    private func restartFeedListener() {
        guard let userId = currentUserId else { return }

        // Remove old listener
        feedListener?.remove()

        // Get fresh friend IDs
        let friends = friendshipRepo.getAcceptedFriends(for: userId)
        var friendIds = friends.compactMap { $0.otherUserId(from: userId) }
        friendIds.append(userId)

        guard !friendIds.isEmpty else {
            posts = []
            return
        }

        // Start new listener with current friends
        feedListener = firestoreService.listenToFeedPosts(
            friendIds: friendIds,
            limit: 50,
            onChange: { [weak self] posts in
                Task { @MainActor in
                    await self?.processFeedPosts(posts, userId: userId)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.error = error
                }
            }
        )
    }

    deinit {
        feedListener?.remove()
        friendshipCancellable?.cancel()
        // ... existing cleanup ...
    }
}
```

#### Step 2.2: Refactor loadFeed to use restartFeedListener

Update `loadFeed()` to use the new helper:
```swift
func loadFeed() {
    guard currentUserId != nil else { return }
    isLoading = true
    restartFeedListener()
    isLoading = false
}
```

### Files Changed
- `gym app/ViewModels/FeedViewModel.swift`

---

## Implementation Order

1. **BUG 5** — Simplest fix, one line change
2. **BUG 1** — Medium complexity, improves data consistency
3. **BUG 6** — Most complex, core UX feature
4. **BUG 4** — Medium complexity, edge case but important
5. **BUG 2** — Nice to have, workaround is manual refresh

---

## Testing Checklist

### BUG 1 Verification
- [ ] Unfriend someone → they immediately disappear from friend list
- [ ] Unfriend someone → they don't appear in feed
- [ ] Force quit app, reopen → unfriended person still gone

### BUG 2 Verification
- [ ] Add new friend → their posts appear in feed without manual refresh
- [ ] Unfriend someone → their posts disappear from feed without manual refresh

### BUG 4 Verification
- [ ] Start conversation with user B from device 1
- [ ] Start conversation with user B from device 2 simultaneously
- [ ] Only ONE conversation exists in Firestore
- [ ] Both devices see the same conversation

### BUG 5 Verification
- [ ] User A shares content to User B via DM
- [ ] User B's conversation list shows the new message preview
- [ ] User B's conversation list reorders to show this conversation at top

### BUG 6 Verification
- [ ] User A sends message to User B (B has app closed)
- [ ] User B opens app → conversation shows unread badge/count
- [ ] User B opens conversation → unread count resets to 0
- [ ] User B closes conversation → new messages increment count again

---

## Files Summary

| File | Bugs |
|------|------|
| `gym app/ViewModels/FeedViewModel.swift` | 2 |
| `gym app/ViewModels/FriendsViewModel.swift` | 1 |
| `gym app/ViewModels/ChatViewModel.swift` | 5, 6 |
| `gym app/ViewModels/ConversationsViewModel.swift` | 4, 6 |
| `gym app/Repositories/ConversationRepository.swift` | 4 |
| `gym app/Models/Conversation.swift` | 4, 6 |
| `gym app/Services/Firebase/FirestoreMessagingService.swift` | 4, 6 |
