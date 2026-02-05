# Refactor Invariants

This document captures behaviors that **MUST NOT change** during refactoring. These invariants protect sync integrity, data consistency, and UI reliability.

---

## 1. Sync Invariants

### 1.1 Offline-First Architecture

**Invariant:** All saves go to CoreData first; cloud sync is asynchronous and non-blocking.

| Behavior | Location | Details |
|----------|----------|---------|
| Local save first | `DataRepository.swift:71-84` | `saveModule()` saves to CoreData immediately, then attempts async cloud push |
| Async cloud push | `DataRepository.swift:163-170` | Cloud sync runs in background `Task`, doesn't block UI |
| Queue on failure | `SyncManager.swift:442-469` | Failed cloud syncs are queued to `SyncQueueEntity` for retry |

**Why it matters:** Users can work offline. Never block local saves waiting for network.

---

### 1.2 Queue-Based Retry Logic

**Invariant:** Failed syncs retry up to 5 times with linear backoff (via polling interval).

| Behavior | Location | Details |
|----------|----------|---------|
| Max retries = 5 | `SyncQueue.swift:72` | `maxRetries = 5` |
| Skip exhausted items | `SyncManager.swift:80` | Predicate: `retryCount < maxRetries` |
| Increment on failure | `SyncManager.swift:134-136` | Increment `retryCount`, update `lastAttemptAt`, store `lastError` |
| Decoding failures permanent | `SyncManager.swift:126-130` | Decoding failures are immediately removed (unrecoverable) |
| Background polling | `SyncManager.swift:315` | 5-minute interval (`backgroundSyncInterval = 300`) |
| Manual intervention flag | `SyncQueueEntity:1278-1280` | `needsManualIntervention = true` when `retryCount >= maxRetries` |

**Why it matters:** Transient failures recover automatically; permanent failures don't retry forever.

---

### 1.3 Sync Priority Ordering

**Invariant:** Entities sync in priority order: active workout data first, library data last.

| Priority | Entity Type | Rationale |
|----------|-------------|-----------|
| 1 | `setData` | Active workout - user is waiting |
| 2 | `session` | Completed workout history |
| 3 | `userProfile` | Profile updates |
| 4 | `customExercise` | User-created exercises |
| 5 | `module` | Workout building blocks |
| 6 | `workout` | Workout templates |
| 7 | `program` | Multi-week programs |
| 8 | `scheduledWorkout` | Future scheduled items |

**Location:** `SyncQueue.swift:43-55`, processed at `SyncManager.swift:84`

**Why it matters:** Prioritizes user-facing data during active workouts.

---

### 1.4 Conflict Resolution: Timestamp-Based

**Invariant:** Cloud wins if `cloudUpdatedAt > localUpdatedAt`; otherwise local wins.

```swift
// FirebaseService.swift:1126-1137
func resolveConflict(localUpdatedAt: Date, cloudUpdatedAt: Date?) -> ConflictResolution {
    guard let cloudDate = cloudUpdatedAt else {
        return .useLocal  // No cloud version exists
    }
    if cloudDate > localUpdatedAt {
        return .useCloud  // Cloud is newer
    } else {
        return .useLocal  // Local is newer or equal (tie goes to local)
    }
}
```

**Why it matters:** Consistent conflict resolution prevents data oscillation between devices.

---

### 1.5 Deletion Trumps Edits

**Invariant:** Deletions always win over concurrent edits via `wasDeletedAfter()` check.

| Behavior | Location | Details |
|----------|----------|---------|
| Check before merge | `DataRepository.swift:659-661` | If local entity updated AFTER deletion, keep local (edge case) |
| Deletion records sync | `DataRepository.swift:703-718` | Unsynced deletions pushed to cloud |
| 30-day retention | `DeletionTracker.swift:33` | `retentionDays = 30` |
| Deletions sync first | `DataRepository.swift:641-653` | `syncDeletionsFromCloud()` called before merges |

**Why it matters:** Prevents resurrection of deleted items from stale device caches.

---

### 1.6 Deep Merge for Modules and Workouts

**Invariant:** Modules/Workouts merge exercises by ID; each exercise uses last-write-wins.

```swift
// Module.swift:193-225
func mergeExerciseArrays(local: [ExerciseInstance], cloud: [ExerciseInstance]) -> [ExerciseInstance] {
    var merged: [UUID: ExerciseInstance] = [:]

    // Add all local exercises
    for exercise in local {
        merged[exercise.id] = exercise
    }

    // For each cloud exercise:
    for cloudExercise in cloud {
        if let localExercise = merged[cloudExercise.id] {
            // Keep whichever is newer
            if cloudExercise.updatedAt > localExercise.updatedAt {
                merged[cloudExercise.id] = cloudExercise
            }
        } else {
            // Cloud-only exercise: add it
            merged[cloudExercise.id] = cloudExercise
        }
    }

    return merged.values.sorted { $0.order < $1.order }
}
```

**Module metadata merge:** `Module.swift:184-191` - uses cloud metadata if cloud is newer

**Content hash optimization:** `Module.swift:251-254` - only syncs if `contentHash` actually changed

**Why it matters:** Allows collaborative editing without losing either user's work.

---

### 1.7 Sessions Are Append-Only

**Invariant:** Session data (completed sets, times) is never merged - only whole sessions sync.

- Sessions don't have `mergedWith()` method like Modules
- Once logged, set data is immutable
- Sessions sync as complete units

**Why it matters:** Historical workout data must be immutable for integrity.

---

### 1.8 Network-Aware Retry

**Invariant:** Sync pauses when offline; automatically retries failed items when network returns.

| Behavior | Location | Details |
|----------|----------|---------|
| Network monitoring | `SyncManager.swift:352-371` | Subscribes to `networkMonitor.$isConnected` |
| Auto-retry on reconnect | `SyncManager.swift:357-360` | Triggers `retryFailedSyncs()` when network returns |
| State transitions | `SyncManager.swift:367-369` | Sets `.offline` state when disconnected |
| Guard clauses | `SyncManager.swift:392` | `guard syncEnabled, isOnline else { return }` |

**Why it matters:** Prevents wasted requests and provides accurate sync status to UI.

---

## 2. Data Integrity Invariants

### 2.1 Thread Safety via @MainActor

**Invariant:** All CoreData operations use the shared `viewContext` on the main thread.

| Component | Location | Pattern |
|-----------|----------|---------|
| DeletionTracker | `DeletionTracker.swift:12` | `@preconcurrency @MainActor` |
| ModuleRepository | `CoreDataRepository.swift:10` | `@MainActor` |
| SessionRepository | `CoreDataRepository.swift:11` | `@MainActor` |
| viewContext accessor | `CoreDataRepository.swift:32-34` | Computed property to `persistence.container.viewContext` |

**Merge policy:** `PersistenceController.swift:79-80`
```swift
container.viewContext.automaticallyMergesChangesFromParent = true
container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
```

**Why it matters:** Prevents CoreData threading violations and data corruption.

---

### 2.2 Two-Layer Model Conversion

**Invariant:** All data flows through two conversion layers: `NSManagedObject <-> Codable struct`

| Direction | Location | Example |
|-----------|----------|---------|
| Entity → Domain | `ModuleRepository.swift:32-42` | `ModuleEntity` → `Module` |
| Domain → Entity | `ModuleRepository.swift:76-189` | `Module` → `ModuleEntity` |
| Nested conversion | `SessionRepository.swift:35-109` | Deep hierarchy with null-safety |

**Fallback pattern for migrations:**
```swift
// ModuleRepository.swift:100-161
let name = instanceEntity.name
    ?? instanceEntity.nameOverride
    ?? ExerciseResolver.shared.getTemplate(id: templateId)?.name
    ?? "Unknown Exercise"
```

**Why it matters:** Isolates persistence layer from business logic; enables safe migrations.

---

### 2.3 UUID Stability

**Invariant:** UUIDs are assigned at creation and never regenerated.

| Behavior | Location | Details |
|----------|----------|---------|
| ID field type | `CoreDataEntities.swift:49` | `@NSManaged public var id: UUID` |
| Find or create | `CoreDataRepository.swift:76-96` | Reuses existing entity by ID |
| Direct pass-through | `ModuleRepository.swift:32-42` | `id: entity.id` in conversion |

**Why it matters:** IDs are used for sync, merge, and relationship tracking across devices.

---

### 2.4 Deletion Tracking with 30-Day Retention

**Invariant:** Deleted entities are tracked for 30 days to sync deletions across devices.

| Behavior | Location | Details |
|----------|----------|---------|
| Record deletion | `DeletionTracker.swift:93-117` | Creates `DeletionRecordEntity` with timestamp |
| Track sync status | `DeletionTracker.swift:206-224` | `syncedAt` updated after cloud push |
| Cleanup old records | `DeletionTracker.swift:274-295` | Only deletes synced records older than 30 days |
| Deduplication | `DeletionTracker.swift:107-109` | Checks for existing record before creating |

**Entity structure:** `CoreDataEntities.swift:1364-1390`
```swift
DeletionRecordEntity:
  - id: UUID
  - entityTypeRaw: String
  - entityId: UUID
  - deletedAt: Date
  - syncedAt: Date?  // nil until synced
```

**Why it matters:** Ensures deletions propagate to all devices within sync window.

---

### 2.5 Automatic Timestamp Management

**Invariant:** `updatedAt` is automatically set via `willSave()` hook; prevents infinite loops.

```swift
// CoreDataEntities.swift:25-43
extension SyncableEntity where Self: NSManagedObject {
    func updateTimestampsOnSave() {
        if hasChanges && !changedValues().isEmpty {
            let changedKeys = changedValues().keys
            // Avoid infinite loop: don't update if only updatedAt changed
            if changedKeys.count == 1 && changedKeys.contains("updatedAt") {
                return
            }
            let now = Date()
            if updatedAt != now {
                setPrimitiveValue(now, forKey: "updatedAt")
            }
        }
    }
}
```

**Applied in willSave():**
- `ModuleEntity:61-64`
- `ExerciseInstanceEntity:225-228`
- `SessionEntity:564-574`
- All `SyncableEntity` conformers

**Why it matters:** Consistent timestamps for conflict resolution; prevents save loops.

---

### 2.6 Store Recovery on Corruption

**Invariant:** Corrupted CoreData store is destroyed and recreated (with data loss) rather than crashing.

```swift
// PersistenceController.swift:44-77
container.loadPersistentStores { storeDescription, error in
    if let error = error as NSError? {
        // Destroy incompatible store
        try container.persistentStoreCoordinator.destroyPersistentStore(...)
        // Clean up WAL files
        for suffix in ["", "-shm", "-wal"] {
            try? fileManager.removeItem(atPath: storePath + suffix)
        }
        // Retry load
    }
}
```

**Why it matters:** App remains functional after major version migrations; data recovers from cloud.

---

## 3. UI Flow Invariants

### 3.1 Reload After CRUD

**Invariant:** Every save/delete operation immediately calls `loadX()` to refresh `@Published` arrays.

| ViewModel | Save Pattern | Delete Pattern |
|-----------|--------------|----------------|
| ModuleViewModel | `saveModule()` → `loadModules()` | `deleteModule()` → `loadModules()` |
| WorkoutViewModel | `saveWorkout()` → `loadWorkouts()` | `deleteWorkout()` → `loadWorkouts()` |
| SessionViewModel | `saveSession()` → `loadSessions()` | `deleteSession()` → `loadSessions()` |

**Example:** `ModuleViewModel.swift:32-43`
```swift
func saveModule(_ module: Module) {
    var moduleToSave = module
    moduleToSave.cleanupOrphanedSupersets()
    repository.saveModule(moduleToSave)
    loadModules()  // <-- Always reload
}
```

**Why it matters:** SwiftUI observes `@Published` arrays; stale data causes UI bugs.

---

### 3.2 Fresh Data on View Entry

**Invariant:** ViewModels load fresh data in `init()` and views use `.onAppear` / `.refreshable`.

| Pattern | Location | Trigger |
|---------|----------|---------|
| Init load | `SessionViewModel.swift:86` | `loadSessions()` in init |
| Refreshable | `ModulesListView.swift:152-154` | Pull-to-refresh calls `loadModules()` |
| AppState refresh | `AppState.swift:173-178` | `refreshAllData()` reloads all ViewModels |

**Why it matters:** Ensures UI reflects latest data, especially after background sync.

---

### 3.3 Navigator Indices Point to Live Data

**Invariant:** `SessionNavigator` stores indices into `currentSession`; computed properties read live.

```swift
// SessionViewModel.swift:135-162
var currentModuleIndex: Int { navigator?.currentModuleIndex ?? 0 }
var currentExerciseIndex: Int { navigator?.currentExerciseIndex ?? 0 }
var currentSetGroupIndex: Int { navigator?.currentSetGroupIndex ?? 0 }
var currentSetIndex: Int { navigator?.currentSetIndex ?? 0 }

// Computed from currentSession using indices
var currentModule: CompletedModule? {
    guard let session = currentSession,
          currentModuleIndex < session.completedModules.count else { return nil }
    return session.completedModules[currentModuleIndex]
}
```

**Navigator lifecycle:**
- Created at session start: `SessionViewModel.swift:372`
- Cleared at session end: `SessionViewModel.swift:662`

**Why it matters:** Indices and data must stay in sync; stale indices cause crashes.

---

### 3.4 Sheet Dismissal Preserves ViewModel State

**Invariant:** Dismissing sheets doesn't clear ViewModel data; state persists for re-opening.

| Behavior | Location | Details |
|----------|----------|---------|
| Delayed cleanup | `ActiveSessionView.swift:269-298` | `asyncAfter(deadline: .now() + 0.3)` for smooth transitions |
| State persists | `SessionViewModel.swift` | @Published properties survive sheet dismiss |
| Explicit clear | `SessionViewModel.swift:652-662` | Only `endSession()` clears session state |

**Why it matters:** Users can dismiss/reopen sheets without losing workout progress.

---

### 3.5 Timer Persistence Across Navigation

**Invariant:** Rest, exercise, and session timers survive view navigation and sheet dismissal.

```swift
// SessionViewModel.swift:48-66
@Published var restTimerSeconds = 0
@Published var restTimerTotal = 0
@Published var isRestTimerRunning = false
@Published var sessionStartTime: Date?
@Published var sessionElapsedSeconds = 0
@Published var exerciseTimerSeconds = 0
@Published var exerciseTimerTotal = 0
@Published var isExerciseTimerRunning = false
@Published var exerciseTimerSetId: String?  // Tracks which set started timer
```

**Foreground observer:** `SessionViewModel.swift:1051-1086` - recalculates time after app returns from background

**Why it matters:** Timers are critical UX; losing them mid-workout is a major bug.

---

### 3.6 Sync Error Surfacing

**Invariant:** Sync errors are published to UI via `@Published syncError` and displayed as banner.

```swift
// AppState.swift:61
@Published var syncError: SyncErrorInfo?

// AppState.swift:126-137 - Listener
SyncManager.shared.$syncState
    .receive(on: DispatchQueue.main)
    .sink { [weak self] state in
        if case .error(let message) = state {
            self?.syncError = SyncErrorInfo(
                message: message,
                timestamp: Date(),
                isRetryable: true
            )
        }
    }

// MainTabView.swift:70-86 - Display
if let syncError = appState.syncError {
    SyncErrorBanner(
        errorInfo: syncError,
        onDismiss: { appState.dismissSyncError() },
        onRetry: { Task { await appState.retrySyncAfterError() } }
    )
}
```

**Why it matters:** Users need visibility into sync failures; silent failures erode trust.

---

### 3.7 Auto-Save for Crash Recovery

**Invariant:** Session progress is auto-saved with debouncing after each set log.

| Behavior | Location | Details |
|----------|----------|---------|
| Debouncer | `SessionViewModel.swift:764-769` | 2-second delay to batch rapid changes |
| Trigger | `SessionViewModel.swift:756` | Called in `logSet()` after each set |

**Why it matters:** Workout progress survives crashes without excessive disk I/O.

---

## 4. Explicit Scope

### 4.1 What IS Changing (Refactor Scope)

- Code organization and file structure
- Naming conventions and consistency
- Reducing code duplication via shared utilities
- Improving testability via dependency injection
- Documentation and code comments
- Performance optimizations that don't change behavior

### 4.2 What IS NOT Changing (Protected Behaviors)

| Category | Protected Behavior |
|----------|-------------------|
| **Sync** | Offline-first saves, retry counts, priority order, conflict resolution |
| **Sync** | Deletion tracking, deep merge logic, network-aware pausing |
| **Data** | Thread safety model, UUID stability, timestamp auto-update |
| **Data** | Two-layer conversion, deletion retention period |
| **UI** | Reload-after-CRUD pattern, fresh data on view entry |
| **UI** | Navigator index management, timer persistence, error surfacing |

### 4.3 Refactor Red Lines

**NEVER:**
- Change sync retry count or backoff strategy without migration plan
- Modify conflict resolution timestamp comparison logic
- Remove @MainActor annotations from repositories
- Change UUID assignment timing or regeneration
- Skip reload calls after CRUD operations
- Move timer state from ViewModel to View
- Suppress sync errors from reaching UI

---

## 5. Post-Refactor Verification Checklist

### 5.1 Sync Verification

- [ ] **Offline save:** Turn off network, save a module, verify it saves locally
- [ ] **Queue persistence:** Kill app while offline, reopen, verify queued items still exist
- [ ] **Retry behavior:** Cause a sync failure, verify retry count increments (max 5)
- [ ] **Priority order:** Queue multiple entity types, verify sets sync before modules
- [ ] **Conflict resolution:** Edit same module on two devices, verify newer timestamp wins
- [ ] **Deletion sync:** Delete on device A, verify it deletes on device B within 30 days
- [ ] **Deep merge:** Add different exercises on two devices, verify both appear after sync

### 5.2 Data Integrity Verification

- [ ] **Thread safety:** Run with Thread Sanitizer enabled, verify no violations
- [ ] **UUID stability:** Create entity, sync, verify same UUID on both devices
- [ ] **Timestamp auto-update:** Edit entity, verify `updatedAt` changes automatically
- [ ] **Deletion tracking:** Delete entity, verify `DeletionRecordEntity` created
- [ ] **Model conversion:** Round-trip entity through save/load, verify no data loss

### 5.3 UI Flow Verification

- [ ] **Reload after save:** Save module, verify list immediately shows update
- [ ] **Reload after delete:** Delete workout, verify list immediately removes it
- [ ] **Fresh data on entry:** Sync in background, navigate to screen, verify new data shows
- [ ] **Navigator indices:** Navigate through session exercises, verify correct data displays
- [ ] **Sheet state preservation:** Dismiss and reopen sheet, verify state persists
- [ ] **Timer persistence:** Start rest timer, navigate away and back, verify timer continues
- [ ] **Sync error display:** Cause sync error, verify banner appears with retry option

### 5.4 Edge Cases

- [ ] **Network transitions:** Sync during network drop, verify graceful degradation
- [ ] **App backgrounding:** Background app mid-sync, verify resumes correctly
- [ ] **Concurrent edits:** Edit same item rapidly, verify no data corruption
- [ ] **Empty states:** Delete all items, verify UI handles empty state correctly
- [ ] **Large data:** Sync 100+ modules, verify performance remains acceptable

---

## Appendix: Key File Reference

| Area | Files | Purpose |
|------|-------|---------|
| **Sync** | `SyncManager.swift` | Queue processing, retry logic, network monitoring |
| **Sync** | `SyncQueue.swift` | Priority definitions, queue entity types |
| **Sync** | `FirebaseService.swift` | Cloud operations, conflict resolution |
| **Sync** | `DataRepository.swift` | Coordination layer, deletion sync |
| **Data** | `PersistenceController.swift` | CoreData stack, merge policy, store recovery |
| **Data** | `DeletionTracker.swift` | Deletion recording, retention cleanup |
| **Data** | `CoreDataEntities.swift` | Entity definitions, timestamp hooks |
| **Data** | `*Repository.swift` | Model conversion, CRUD operations |
| **Models** | `Module.swift` | Deep merge logic, content hash |
| **Models** | `Workout.swift`, `Session.swift` | Domain models |
| **UI** | `AppState.swift` | Sync error publishing, refresh coordination |
| **UI** | `SessionViewModel.swift` | Timer state, navigator, session lifecycle |
| **UI** | `WorkoutViewModel.swift` | CRUD patterns, scheduled workouts |
| **UI** | `ModuleViewModel.swift` | CRUD patterns |
