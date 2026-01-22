# Gym App - Development Context

> Reference document for Claude Code sessions
> **Last updated:** 2025-01-22

## Last Session Summary
- Fixed SetRowView layout issues using `.fixedSize()` to prevent text compression
- Changed auto-suggest priority: last session values > target values > empty
- Fixed force unwrapping in HomeView (Calendar.date) and ActiveSessionView (URL)
- Added decode failure tracking to FirebaseService (no more silent data loss)
- Implemented session pagination in DataRepository (load last 90 days initially)
- Added `loadMoreSessions()` for on-demand historical session loading
- Updated `getExerciseHistory()` to query CoreData directly for full history
- Compacted all input sections (cardio, isometric, mobility, explosive, recovery)

## Project Overview

iOS gym/workout tracking app built with SwiftUI. Offline-first with CoreData, Firebase for sync.

## Current State (Jan 2025)

### Core Features Implemented
- Workout → Module → Exercise hierarchy
- Exercise types: strength, cardio, isometric, mobility, explosive, recovery
- Live session tracking with sets, reps, weight, RPE, duration, distance
- Superset support (exercises linked by `supersetGroupId`)
- Live workout modifications:
  - Add sets to current exercise
  - Substitute exercises with alternatives
  - Add new exercises to modules on-the-fly
- Dark theme UI
- Time wheel pickers for duration inputs
- Recent sets quick-edit during session
- Workout overview with jump-to-exercise
- Smart auto-fill from last session (weight, reps, duration, distance, band color)
- Session pagination for memory efficiency

### Architecture
```
Views/ViewModels → DataRepository → FirebaseService (swappable)
                                  → CoreData (local)
```

Key files:
- `DataRepository.swift` - data abstraction layer, session pagination
- `FirebaseService.swift` - Firebase-specific calls, decode failure tracking
- `SyncManager.swift` - sync orchestration
- `PersistenceController.swift` - CoreData stack

### Session Pagination (Jan 2025)

Sessions are now paginated to reduce memory usage:

```swift
// DataRepository pagination state
@Published private(set) var isLoadingMoreSessions = false
@Published private(set) var hasMoreSessions = true
private let initialSessionLoadDays = 90  // Load last 90 days initially
private let sessionPageSize = 30  // Load 30 more at a time

// Methods
func loadSessions()        // Loads recent sessions (last 90 days)
func loadMoreSessions()    // Loads 30 older sessions on demand
func loadAllSessions()     // Loads everything (for export)
func getTotalSessionCount() -> Int  // Count without loading all
```

**Key behavior:**
- `getExerciseHistory()` queries CoreData directly (full history)
- `getLastProgressionRecommendation()` checks loaded sessions first, then queries older
- Views can call `loadMoreSessions()` when user scrolls to bottom

### Firebase Decode Failure Tracking (Jan 2025)

Decode failures are now tracked instead of silently dropped:

```swift
struct DecodeFailure: Identifiable {
    let id: String  // Document ID
    let collection: String
    let error: Error
    let timestamp: Date
}

// FirestoreService properties
@Published private(set) var decodeFailures: [DecodeFailure] = []
var hasDecodeFailures: Bool { !decodeFailures.isEmpty }
func clearDecodeFailures()
```

### Exercise Data Model (Jan 2025)

The exercise system uses a normalized architecture with four distinct types:

```
┌─────────────────────────────────────────────────────────────────┐
│                     EXERCISE DATA FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ExerciseTemplate (Library)                                     │
│  ├── id: UUID (stable, never changes)                          │
│  ├── name, category, exerciseType                              │
│  ├── primaryMuscles, secondaryMuscles                          │
│  └── isCustom, isArchived                                      │
│           │                                                     │
│           │ templateId reference                                │
│           ▼                                                     │
│  ExerciseInstance (Module Planning)                            │
│  ├── id: UUID                                                  │
│  ├── templateId → ExerciseTemplate                             │
│  ├── setGroups: [SetGroup]                                     │
│  ├── supersetGroupId (optional)                                │
│  └── order, notes, nameOverride                                │
│           │                                                     │
│           │ resolve via ExerciseResolver                        │
│           ▼                                                     │
│  ResolvedExercise (View Model)                                 │
│  ├── instance: ExerciseInstance                                │
│  ├── template: ExerciseTemplate?                               │
│  └── Computed: name, exerciseType, muscles, etc.               │
│           │                                                     │
│           │ snapshot during session                             │
│           ▼                                                     │
│  SessionExercise (Logged Data)                                 │
│  ├── exerciseId, exerciseName (denormalized)                   │
│  ├── exerciseType, primaryMuscles, secondaryMuscles            │
│  ├── completedSetGroups: [CompletedSetGroup]                   │
│  └── isSubstitution, isAdHoc, progressionRecommendation        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**ExerciseTemplate** - Canonical definition in the exercise library
- Built-in exercises in `ExerciseLibrary.shared` (stable UUIDs)
- Custom exercises in `CustomExerciseLibrary.shared` (user-created)
- Immutable reference data (name, muscles, type)

**ExerciseInstance** - A planned exercise within a Module
- References template via `templateId`
- Contains workout-specific configuration (sets, reps, weight targets)
- Supports supersets via `supersetGroupId`

**ResolvedExercise** - Hydrated view model for UI rendering
- Combines instance + template data
- Created on-demand via `ExerciseResolver.shared.resolve(instance)`
- Handles orphaned instances (template deleted) gracefully

**SessionExercise** - Logged workout data (denormalized snapshot)
- Captures exercise state at time of workout
- Stores actual completed sets/reps/weights
- Independent of template changes (historical accuracy)

**Key service:** `ExerciseResolver.shared`
- Single source of truth for all exercise lookups
- Caches templates from both built-in and custom libraries
- Methods: `search()`, `resolve()`, `getTemplate()`, `allExercises`

### Recent Refactoring (Jan 2025)
Modularized `ActiveSessionView.swift` from ~2600 lines into:
```
Views/Session/
├── ActiveSessionView.swift       (main view, ~1700 lines)
├── SessionModels.swift           (FlatSet, RecentSet, SetLocation)
├── SessionComponents.swift       (SetIndicator, SetRowView, ~1200 lines)
├── EndSessionSheet.swift
├── RecentSetsSheet.swift
├── WorkoutOverviewSheet.swift
└── ExerciseModificationSheets.swift
```

## Owner's Priorities

**Not rushing to launch** - building foundation properly.

### Phase 1: UX Refinement
- Dogfood and fix friction points
- Animation timing, button hit targets, keyboard flow
- Watch others use it without guidance

### Phase 2: Infrastructure for Growth
Recommended order:
1. **Auth flow** - full sign up/login/reset, Apple Sign In
2. **Data model hardening** - schema stability before heavy sync usage
3. **Sync strategy** - conflict resolution (currently skeletal)
4. **Backend** - Firebase for now, keep options open
5. **Modularization** - Swift packages for logical boundaries

### Phase 3: Future Features (not yet started)
- Analytics (PRs, volume tracking, trends)
- Social features (shared workouts, friends, leaderboards)

## Technical Notes

### Firebase Strategy
- Using Firestore for CRUD only (no real-time listeners)
- Free tier is sufficient for now
- **Migration-friendly**: keep `FirebaseService` as thin wrapper
- Future options: Supabase, custom backend + Postgres
- **Decode failures tracked** - no more silent data loss

### Migration Prep
Keep this pattern for easy backend swap:
```swift
protocol CloudSyncService {
    func save<T: Codable>(_ item: T, collection: String) async throws
    func fetch<T: Codable>(collection: String) async throws -> [T]
    // etc.
}
```

### Sync & Merge Strategy (Jan 2025)

**Problem solved:** Module has `updatedAt`, nested Exercise also has `updatedAt`. If Device A edits Exercise 1 and Device B edits Exercise 2 in the same Module, simple module-level comparison would lose one edit.

**Solution:** Deep merge at the entity level:
- Compare each nested Exercise by its own `updatedAt`
- Keep the newer version of each individual exercise
- Module metadata (name, type, notes) uses last-write-wins from newer `updatedAt`

**Key methods added to Module and Workout:**
```swift
// Deep merge: keeps newer version of each nested entity
func mergedWith(_ cloudModule: Module) -> Module

// Quick dirty-check via content hash
var contentHash: Int { ... }

// Compare for changes
func needsSync(comparedTo other: Module) -> Bool
```

**Merge behavior:**
| Scenario | Result |
|----------|--------|
| Local edits Ex A, cloud edits Ex B | Both edits preserved |
| Both edit same exercise | Newer `updatedAt` wins |
| Local deletes, cloud edits | Cloud version added back (no tombstones yet) |
| Cloud adds new exercise | Added to merged result |

**Dirty-checking:** `contentHash` combines name, type, notes, and all nested entity IDs/timestamps. If hashes match, skip the save.

**Test coverage:** `ModuleMergeTests.swift` covers all scenarios above.

### Schema Versioning (Jan 2025)

All Codable models include schema versioning for future migrations.

**Central version registry:** `SchemaVersions.swift`
```swift
enum SchemaVersions {
    static let exerciseInstance = 1
    static let module = 1
    static let workout = 1
    static let session = 1
    static let program = 1
    static let setGroup = 1
    static let scheduledWorkout = 1
}
```

**Current decoders:** Clean, organized by field type:
```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.module

    // Required fields - fail if missing
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)

    // Optional with defaults
    exercises = try container.decodeIfPresent([ExerciseInstance].self, forKey: .exercises) ?? []

    // Truly optional
    notes = try container.decodeIfPresent(String.self, forKey: .notes)
}
```

**To bump a version:** Increment in `SchemaVersions`, then handle in decoder if needed.

**Models with versioning:** ExerciseInstance, Module, Workout, Session, Program

### Logging & Debug Configuration (Jan 2025)

The app uses a centralized logging system that respects debug/release builds.

**Configuration:** `AppConfig.swift`
```swift
enum AppConfig {
    static var isDebug: Bool          // true in DEBUG builds
    static var isTestFlight: Bool     // true for TestFlight builds
    static var enableSyncLogging: Bool     // DEBUG + TestFlight
    static var enablePerformanceLogging: Bool  // DEBUG only
    static var showDebugUI: Bool      // DEBUG + TestFlight

    // Performance thresholds (seconds)
    static let slowSyncThreshold: TimeInterval = 2.0
    static let slowLoadThreshold: TimeInterval = 0.5
    static let slowSaveThreshold: TimeInterval = 0.3
}
```

**Logger utility:** `Logger.swift`
```swift
Logger.debug("message")    // DEBUG only, includes file:line
Logger.verbose("message")  // DEBUG only, requires enableVerboseLogging
Logger.info("message")     // DEBUG only
Logger.warning("message")  // DEBUG only
Logger.error("message")    // Always logs (DEBUG + RELEASE)
Logger.error(error, context:) // Error objects

// Sync logging (persisted via SyncLogger)
Logger.syncInfo("msg", context:)
Logger.syncWarning("msg", context:)
Logger.syncError("msg", context:)

// Performance logging
Logger.performance("operation", duration:, threshold:)
Logger.measure("operation") { ... }       // Sync operations
Logger.measureAsync("operation") { ... }  // Async operations
PerformanceTimer("operation")             // Manual timing

// Sensitive data redaction
Logger.redactUUID(uuid)    // "12345678..."
Logger.redactUserID(id)    // "1234..."
Logger.redactEmail(email)  // "ab***@example.com"
```

**Rules:**
- Never log sensitive data (user IDs, emails, full UUIDs) even in DEBUG
- Use `Logger.redact*()` helpers when logging identifiers
- `Logger.error()` always logs - use for critical issues
- Use `Logger.verbose()` for detailed tracing (off by default)
- SyncLogger persists logs to CoreData for debugging sync issues

### SetRowView Layout Fix (Jan 2025)

Input sections in `SessionComponents.swift` use `.fixedSize(horizontal: true, vertical: false)` on VStacks containing labels. This prevents SwiftUI from compressing them and causing text to wrap vertically.

```swift
VStack(spacing: 4) {
    // Input field
    TextField(...)
    // Label
    Text("distance")
        .font(.caption2)
}
.fixedSize(horizontal: true, vertical: false)  // Prevents compression
```

## Code Style Notes
- Uses `AppColors`, `AppSpacing`, `AppCorners`, `AppAnimation` from Theme
- Sheets use `.presentationDetents([.medium])` pattern
- Exercise types have `.icon` property for SF Symbols

## Build Notes
- Firebase packages can be slow to resolve
- If PIF errors occur: `rm -rf ~/Library/Developer/Xcode/DerivedData/gym_app-*`
- Build with `CODE_SIGNING_ALLOWED=NO` for CI/testing
