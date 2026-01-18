# Gym App - Development Context

> Reference document for Claude Code sessions
> **Last updated:** 2025-01-18

## Last Session Summary
- Fixed Swift 6 concurrency warnings (moved `.shared` access from default params to init bodies)
- Implemented deep merge strategy for sync conflict resolution
- Added `mergedWith()`, `contentHash`, `needsSync()` to Module and Workout
- Created ModuleMergeTests.swift with comprehensive unit tests

## Project Overview

iOS gym/workout tracking app built with SwiftUI. Offline-first with CoreData, Firebase for sync.

## Current State (Jan 2025)

### Core Features Implemented
- Workout → Module → Exercise hierarchy
- Exercise types: strength, cardio, isometric, mobility, explosive
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

### Architecture
```
Views/ViewModels → DataRepository → FirebaseService (swappable)
                                  → CoreData (local)
```

Key files:
- `DataRepository.swift` - data abstraction layer
- `FirebaseService.swift` - Firebase-specific calls (thin wrapper)
- `SyncManager.swift` - sync orchestration
- `PersistenceController.swift` - CoreData stack

### Recent Refactoring (Jan 2025)
Modularized `ActiveSessionView.swift` from ~2600 lines into:
```
Views/Session/
├── ActiveSessionView.swift       (main view, ~1125 lines)
├── SessionModels.swift           (FlatSet, RecentSet, SetLocation)
├── SessionComponents.swift       (SetIndicator, SetRowView)
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

All Codable models now include schema versioning for safe future migrations.

**Central version registry:** `SchemaVersions.swift`
```swift
enum SchemaVersions {
    static let exercise = 1
    static let exerciseInstance = 1
    static let module = 1
    static let workout = 1
    static let session = 1
    static let program = 1
    static let setGroup = 1
    static let scheduledWorkout = 1
}
```

**How it works:**
1. Each model has `schemaVersion: Int` property (defaults to current version from `SchemaVersions`)
2. Decoder reads version with `decodeIfPresent` (defaults to 1 for backward compatibility)
3. Switch on version in `init(from decoder:)` to handle migrations
4. Always stores current version after decoding

**Migration pattern:**
```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    schemaVersion = SchemaVersions.exercise  // Always current

    switch version {
    case 1:
        break  // Current version
    case 2:
        // Future: migrate from v2 format
        break
    default:
        break  // Unknown future version - best effort
    }
    // ... decode fields
}
```

**To bump a version:**
1. Increment version in `SchemaVersions`
2. Add migration case in decoder's switch statement
3. Implement migration logic in `*Migrations` enum if complex
4. Update this documentation

**Models with versioning:** Exercise, ExerciseInstance, Module, Workout, Session, Program

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

### Pending Items from Plan File
Located at: `~/.claude/plans/structured-churning-stream.md`
- Remove 3x10 default set groups
- Make set groups editable after creation
- (Time pickers already done)
- Superset capability (foundation in place)

## Code Style Notes
- Uses `AppColors`, `AppSpacing`, `AppCorners`, `AppAnimation` from Theme
- Sheets use `.presentationDetents([.medium])` pattern
- Exercise types have `.icon` property for SF Symbols

## Build Notes
- Firebase packages can be slow to resolve
- If PIF errors occur: `rm -rf ~/Library/Developer/Xcode/DerivedData/gym_app-*`
- Build with `CODE_SIGNING_ALLOWED=NO` for CI/testing
