# Gym App - Development Context

> Reference document for Claude Code sessions
> **Last updated:** 2025-01-13

## Last Session Summary
- Modularized ActiveSessionView.swift into 6 separate files
- Added live workout modification features (add sets, substitute exercise, add exercise to module)
- Discussed infrastructure priorities: UX polish → auth → data model → sync → backend
- Firebase strategy: CRUD only, keep abstracted for easy future migration

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
