# Gym App - Development Context

> Reference document for Claude Code sessions
> **Last updated:** 2025-01-26

## Project Overview

iOS workout tracking app built with SwiftUI. Offline-first with CoreData, Firebase for cloud sync.

**Status:** Feature-complete foundation, not rushing to launch - focusing on UX refinement and infrastructure hardening.

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Language | Swift 5+ |
| Local Storage | CoreData (offline-first) |
| Cloud Sync | Firebase/Firestore v10.29.0 |
| Authentication | Firebase Auth + Apple Sign In |
| Security | Firebase App Check |
| Analytics | Google App Measurement |

## Project Structure

```
gym app/                          (90+ Swift files)
├── ViewModels/                   (6 files, ~76KB)
│   ├── AppState.swift
│   ├── SessionViewModel.swift    (35KB - largest)
│   ├── SessionNavigator.swift
│   ├── WorkoutViewModel.swift
│   ├── ProgramViewModel.swift
│   └── ModuleViewModel.swift
│
├── Views/                        (40+ files)
│   ├── Session/                  (8 files - workout session UI)
│   │   ├── ActiveSessionView.swift     (~1700 lines)
│   │   ├── SessionComponents.swift     (~1200 lines)
│   │   ├── EndSessionSheet.swift
│   │   ├── WorkoutOverviewSheet.swift
│   │   ├── RecentSetsSheet.swift
│   │   ├── ExerciseModificationSheets.swift
│   │   ├── IntervalTimerView.swift
│   │   └── SessionModels.swift
│   │
│   ├── Programs/                 (8 files)
│   │   ├── ProgramsListView.swift
│   │   ├── ProgramFormView.swift       (~1050 lines)
│   │   ├── ProgramDetailView.swift
│   │   └── [program management sheets]
│   │
│   ├── Modules/                  (6+ files)
│   │   ├── ModulesListView.swift
│   │   ├── ModuleDetailView.swift
│   │   ├── ModuleFormView.swift
│   │   ├── ExerciseDetailView.swift
│   │   ├── ExerciseFormView.swift
│   │   └── ExercisePickerView.swift
│   │
│   ├── History/                  (3 files)
│   ├── Settings/                 (4 files)
│   ├── Library/                  (3 files)
│   ├── Auth/                     (1 file)
│   ├── Analytics/                (1 file)
│   ├── Components/               (2 files)
│   ├── Social/                   (1 file)
│   ├── HomeView.swift            (~800 lines)
│   ├── HomeScheduleSheets.swift  (29KB)
│   └── MainTabView.swift
│
├── Models/                       (15+ files)
│   ├── ExerciseInstance.swift
│   ├── Module.swift
│   ├── Workout.swift
│   ├── Program.swift
│   ├── ScheduledWorkout.swift
│   ├── Session.swift
│   ├── SetGroup.swift
│   ├── UserProfile.swift
│   ├── ExerciseLibrary.swift
│   ├── CustomExerciseLibrary.swift
│   ├── ResolvedExercise.swift
│   ├── SyncQueue.swift
│   ├── SchemaVersions.swift
│   └── Enums.swift
│
├── Services/                     (15 files)
│   ├── FirebaseService.swift     (34KB)
│   ├── AuthService.swift
│   ├── SyncManager.swift         (25KB)
│   ├── DataRepository.swift
│   ├── ExerciseResolver.swift
│   ├── SyncLogger.swift
│   ├── Logger.swift
│   ├── DeletionTracker.swift
│   ├── AppConfig.swift
│   └── [supporting services]
│
├── CoreData/                     (3 files)
├── Theme/                        (2 files)
├── Utilities/                    (3 files)
└── gym_appApp.swift

TodayWorkoutWidget/               (iOS widget extension)
Tests/                            (6 test files)
```

## Architecture

```
Views/ViewModels → DataRepository → FirebaseService (cloud)
                                  → CoreData (local)
```

**Key Principles:**
- Offline-first: CoreData is source of truth, Firebase is sync target
- Deep merge: Multi-device edits preserved at exercise level
- Decode failure tracking: No silent data loss
- Session pagination: Loads last 90 days initially, 30 more on-demand

## Data Models

### Hierarchy
```
Program (training block)
  └─ ScheduledWorkout (planned slot, day of week)
      └─ Workout (composition of modules)
          └─ Module (exercise grouping by type)
              └─ ExerciseInstance (exercise in module)
                  └─ SetGroup (sets configuration)

Session (completed workout - denormalized snapshot)
  └─ SessionExercise → CompletedSetGroup
```

### Exercise Data Flow
```
ExerciseTemplate (Library)
    │ templateId reference
    ▼
ExerciseInstance (Module Planning)
    │ resolve via ExerciseResolver
    ▼
ResolvedExercise (View Model)
    │ snapshot during session
    ▼
SessionExercise (Logged Data)
```

### Exercise Types
- **Strength**: weight/reps tracking
- **Cardio**: time and/or distance
- **Mobility**: reps and/or duration
- **Isometric**: hold time
- **Explosive**: power movements
- **Recovery**: stretching, sauna, cold plunge, massage, meditation

### Key Enums
- `ModuleType`: warmup, prehab, explosive, strength, cardio_long, cardio_speed, recovery
- `ExerciseType`: strength, cardio, mobility, isometric, explosive, recovery
- `SyncStatus`: synced, pendingSync, syncing, syncFailed, conflict
- `MetricType`: weight, reps, sets, duration, distance, pace, heartRate, holdTime, RPE

## Key Services

### DataRepository
- Session pagination (90 days initial, page 30 on demand)
- Save/load modules, workouts, sessions, programs
- Exercise history queries (full history from CoreData)
- Sync orchestration

### FirebaseService (34KB)
- Firestore CRUD operations
- Decode failure tracking with timestamps
- User document structure: modules, workouts, sessions, programs, customExercises

### SyncManager (25KB)
- SyncQueueProcessor actor for background operations
- Retry logic with configurable max retries
- Merge conflict resolution
- Performance tracking

### ExerciseResolver
- Single source of truth for exercise lookups
- Caches from built-in and custom libraries
- Resolves template + instance into complete data

## Implemented Features

### Core Workout Tracking
- [x] Programs (training blocks/periodization)
- [x] Scheduled workouts within programs
- [x] Reusable workout modules
- [x] Sets, reps, weight, RPE, duration, distance logging
- [x] Exercise substitution during workout
- [x] Add exercises on-the-fly
- [x] Delete exercises (swipe-to-delete)
- [x] Superset support
- [x] Edit workout history

### Smart Features
- [x] Auto-fill from last session (weight, reps, duration, distance, band color)
- [x] Priority: last session > target values > empty
- [x] Recent sets quick-edit sheet
- [x] Workout overview with jump-to-exercise

### UI/UX
- [x] Dark theme with custom palette
- [x] Time wheel pickers
- [x] Tab-based navigation
- [x] Sheet-based editing
- [x] Interval timer
- [x] Session pagination
- [x] Sync error banner

### Data Management
- [x] Offline-first CoreData persistence
- [x] Firebase cloud sync
- [x] Deep merge for multi-device
- [x] Deletion tracking
- [x] Decode failure tracking
- [x] Schema versioning

## Planned Features

### Smart Features (Next Priority)
- [ ] Progressive overload suggestions ("Nice! Try 140 lbs next time?")
- [ ] Plate calculator (visual plate loading guide)
- [ ] Rest timer auto-start with haptic
- [ ] Personal records detection with celebration

### Future
- [ ] Analytics dashboard (PRs, volume tracking, trends)
- [ ] Social features (shared workouts, friends, leaderboards)

## Code Modularization Opportunities

### High Priority (Large Files)
1. **ActiveSessionView.swift (~1700 lines)** - Extract ExerciseCardView, SupersetBanner
2. **HomeView.swift (~800 lines)** - Extract CalendarView, ScheduleWorkoutSheet
3. **SessionComponents.swift (~1200 lines)** - Split input views by exercise type

### Medium Priority
4. **EndSessionSheet.swift (~636 lines)** - Extract ExerciseCard subview

## Development Phases

### Phase 1: UX Refinement (Current)
- Dogfood and fix friction points
- Animation timing, button hit targets, keyboard flow
- Watch others use it without guidance

### Phase 2: Infrastructure
1. **Auth flow** - full sign up/login/reset, Apple Sign In
2. **Data model hardening** - schema stability
3. **Sync strategy** - conflict resolution refinement
4. **Backend** - Firebase for now, keep options open
5. **Modularization** - Swift packages for logical boundaries

### Phase 3: Future Features
- Analytics, Social features

## Technical Notes

### Session Pagination
```swift
@Published private(set) var isLoadingMoreSessions = false
@Published private(set) var hasMoreSessions = true
private let initialSessionLoadDays = 90
private let sessionPageSize = 30

func loadSessions()        // Last 90 days
func loadMoreSessions()    // 30 older sessions
func loadAllSessions()     // Everything (for export)
```

### Firebase Decode Failure Tracking
```swift
struct DecodeFailure: Identifiable {
    let id: String
    let collection: String
    let error: Error
    let timestamp: Date
}
@Published private(set) var decodeFailures: [DecodeFailure] = []
```

### Sync & Merge Strategy
- Compare each nested Exercise by its own `updatedAt`
- Keep newer version of each individual exercise
- Module metadata uses last-write-wins from newer `updatedAt`

| Scenario | Result |
|----------|--------|
| Local edits Ex A, cloud edits Ex B | Both preserved |
| Both edit same exercise | Newer `updatedAt` wins |
| Local deletes, cloud edits | Cloud version added back |
| Cloud adds new exercise | Added to merged result |

### Schema Versioning
All Codable models include `schemaVersion`. Central registry in `SchemaVersions.swift`.

### Logging Configuration
```swift
// AppConfig.swift
static var isDebug: Bool
static var isTestFlight: Bool
static var enableSyncLogging: Bool     // DEBUG + TestFlight
static var enablePerformanceLogging: Bool  // DEBUG only
static var showDebugUI: Bool           // DEBUG + TestFlight

// Thresholds
static let slowSyncThreshold: TimeInterval = 2.0
static let slowLoadThreshold: TimeInterval = 0.5
static let slowSaveThreshold: TimeInterval = 0.3
```

### Logger Usage
```swift
Logger.debug("message")     // DEBUG only
Logger.error("message")     // Always logs
Logger.syncInfo("msg", context:)  // Persisted via SyncLogger

// Redaction helpers
Logger.redactUUID(uuid)     // "12345678..."
Logger.redactEmail(email)   // "ab***@example.com"
```

## Code Style

- Theme: `AppColors`, `AppSpacing`, `AppCorners`, `AppAnimation`
- Sheets: `.presentationDetents([.medium])`
- Exercise types have `.icon` property for SF Symbols

## Build Notes

- Firebase packages can be slow to resolve
- If PIF errors: `rm -rf ~/Library/Developer/Xcode/DerivedData/gym_app-*`
- Build with `CODE_SIGNING_ALLOWED=NO` for CI/testing
