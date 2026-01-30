# Gym App - Development Context

> Reference document for Claude Code sessions
> **Last updated:** 2026-01-30

## Project Overview

iOS workout tracking app built with SwiftUI. Offline-first with CoreData, Firebase for cloud sync.

**Status:** Feature-complete foundation with UX bugs fixed and design system fully implemented. Typography refactoring complete. Major refactoring completed (DataRepository split, Session model split, AppTheme split). Per-exercise progression system implemented. Comprehensive DataRepository tests added.

## Major Refactoring (Jan 29, 2026)

### DataRepository Split

Split monolithic `DataRepository.swift` into entity-specific repositories for better maintainability:

```
Services/
├── DataRepository.swift      (Coordinator - delegates to sub-repositories)
├── ModuleRepository.swift    (Module CRUD, CoreData <-> Model conversion)
├── WorkoutRepository.swift   (Workout CRUD)
├── SessionRepository.swift   (Session CRUD, pagination)
└── ProgramRepository.swift   (Program CRUD, progression fields)
```

Each repository handles:
- CoreData entity management
- Model ↔ Entity conversion
- Collection-specific queries
- Sync support

### Session Model Split

Split 729-line `Session.swift` into focused model files:

```
Models/
├── Session.swift            (Session struct only, ~100 lines)
├── CompletedModule.swift    (Module completion data)
├── SessionExercise.swift    (Exercise logging data)
├── CompletedSetGroup.swift  (Set group completion)
├── SetData.swift            (Individual set data)
└── MeasurableValue.swift    (Equipment measurable values)
```

### AppTheme Split (Jan 30, 2026)

Split monolithic `AppTheme.swift` (1085 lines) into focused, single-responsibility files:

```
Theme/
├── AppTheme.swift        (~620 lines - view modifiers, card styles, buttons, form components)
├── AppColors.swift       (91 lines - color palette, module colors, hex extension)
├── AppGradients.swift    (110 lines - gradient definitions, module gradients)
├── AppSpacing.swift      (26 lines - spacing constants)
├── AppCorners.swift      (18 lines - corner radius values)
├── AppShadows.swift      (27 lines - shadow styles)
└── AppAnimations.swift   (23 lines - animation definitions)
```

**Benefits:**
- Each file has single responsibility
- Easier to find and modify specific design tokens
- Reduced cognitive load when working with theme
- Better git diffs for design changes

### DataRepository Unit Tests (Jan 30, 2026)

Added comprehensive unit tests for all repository CRUD operations:

```
gym appTests/
└── DataRepositoryTests.swift  (878 lines)
    ├── Test Fixtures (Module, Workout, Session, Program, etc.)
    ├── ModuleRepositoryTests (7 tests)
    ├── WorkoutRepositoryTests (5 tests)
    ├── SessionRepositoryTests (9 tests - includes pagination & in-progress)
    ├── ProgramRepositoryTests (6 tests - includes active program constraint)
    └── DataRepositoryIntegrationTests (2 tests - cross-repository workflows)
```

**Test Setup:**
- All tests use `PersistenceController(inMemory: true)` for isolation
- Tests are `@MainActor` to match repository thread safety
- Fixtures use default parameters for easy test creation

### Per-Exercise Progression Configuration

Added granular control over which exercises get automatic progression suggestions.

**New Program Fields:**
```swift
var progressionEnabledExercises: Set<UUID>           // ExerciseInstance IDs enabled for progression
var exerciseProgressionOverrides: [UUID: ProgressionRule]  // Per-exercise custom rules
```

**New Program Methods:**
```swift
func isProgressionEnabled(for exerciseInstanceId: UUID) -> Bool
func progressionRuleForExercise(_ exerciseInstanceId: UUID) -> ProgressionRule?
mutating func setProgressionEnabled(_ enabled: Bool, for exerciseInstanceId: UUID)
mutating func setProgressionOverride(_ rule: ProgressionRule?, for exerciseInstanceId: UUID)
```

**New UI - ProgressionConfigurationView:**
- Accessible from ProgramDetailView → "Configure Progression" button
- Hierarchical display: Workout → Module → Exercise
- Smart defaults based on module type (skip warmup/recovery/prehab) and exercise type (strength only)
- Per-exercise toggle and customize button
- Bulk selection: "Select All", "Select None", "Smart Select" per module
- Exercise-level progression rule overrides

**Smart Default Logic:**
```swift
// Skip these module types entirely
if [.warmup, .recovery, .prehab].contains(moduleType) { return false }
// Only progress strength-type exercises
if exercise.exerciseType != .strength { return false }
return true
```

**CoreData Persistence:**
- `progressionEnabledExercisesData: Data?` - JSON-encoded Set<UUID>
- `exerciseProgressionOverridesData: Data?` - JSON-encoded [UUID: ProgressionRule]

**ProgressionService Updates:**
```swift
// New signature accepting exercise instance ID mapping
func calculateSuggestions(
    for exercises: [SessionExercise],
    exerciseInstanceIds: [UUID: UUID],  // SessionExercise.id -> ExerciseInstance.id
    workoutId: UUID,
    program: Program?,
    sessionHistory: [Session]
) -> [UUID: ProgressionSuggestion]
```

## Design System Implementation (Jan 28-29, 2025)

Comprehensive typography system and color harmonization finalized. **Full typography refactoring completed Jan 29.**

### Typography System

**Created modular font system** (`Font+Extensions.swift` + integrated into `AppTheme.swift`):
- **Display styles** (rounded, bold) - Big celebratory moments, workout stats
- **Monospaced styles** - Timers/counters that prevent layout shift
- **Label styles** (uppercase + tracking) - Elegant section headers
- **Standard styles** (semantic + color) - Convenience wrappers

**Refactored all 30 view files** - converted inline `.font(.system(size:))` to semantic modifiers:

```swift
// Before (4 lines, verbose)
Text("TODAY")
    .font(.caption.weight(.semibold))
    .textCase(.uppercase)
    .tracking(1.5)
    .foregroundColor(AppColors.dominant)

// After (1 line, modular)
Text("TODAY")
    .elegantLabel(color: AppColors.dominant)
```

**Key modifiers:**
- `.displayLarge()` / `.displayMedium()` / `.displaySmall()` - Rounded display text
- `.monoLarge()` / `.monoMedium()` / `.monoSmall()` - Monospaced numbers (stable layout)
- `.elegantLabel()` - Uppercase headers with tracking (e.g., "TODAY", "TRAINING HUB")
- `.statLabel()` - Stat descriptions (e.g., "completed", "volume")
- `.headline()` / `.body()` / `.caption()` - Standard text with color

**All view files refactored (30 total):**
- Session: `ActiveSessionView`, `SessionComponents`, `IntervalTimerView`, `WorkoutOverviewSheet`, `RecentSetsSheet`, `EndSessionSheet`
- Home: `HomeView`, `HomeScheduleSheets`, `WorkoutBuilderView`
- Programs: `ProgramsListView`, `ProgramFormView`, `ProgramWeeklyGridView`, `AddWorkoutSlotSheet`
- Workouts/Modules: `WorkoutsListView`, `WorkoutFormView`, `ModulesListView`, `ModuleFormView`, `ExerciseFormView`, `SetGroupFormView`
- Library/Settings: `ExerciseLibraryView`, `EquipmentLibraryView`, `ImplementPickerView`, `MuscleGroupPickerView`, `SettingsView`, `DebugSyncLogsView`
- Other: `HistoryView`, `AnalyticsView`, `SocialView`, `SignInView`, `AnimatedComponents`

**Preserved:** Fonts with `.design: .rounded` for numeric input displays (weight/reps/timers)

**Documentation:** `design docs/TYPOGRAPHY.md` - Complete usage guide, before/after examples, decision tree

### Color Harmonization

**HomeView & WorkoutBuilderView visual improvements:**
- Added gradient borders to weekly calendar (dominant 0.20 → surfaceTertiary 0.15)
- Added gradient borders to Week in Review container (dominant 0.25 → surfaceTertiary 0.15)
- Enhanced shadow on Week in Review (dominant 0.08 opacity, 12px radius)
- All cards now use consistent gradient card styling

**ActiveSession UI enhancements (subtle pop):**
- Current set indicator: 0.12 → **0.15 opacity**
- Timer running state: 0.12 → **0.15 opacity**
- Log button shadow: 0.06 → **0.10 opacity** (8px radius)
- Same as last button: 0.10 → **0.15 opacity**
- Rest timer urgent (<10s): Added **0.15 opacity glow** with amber color
- Rest timer urgent border: 0.3 → **0.4 opacity**

**Updated documentation:** `design docs/COLOR_PALETTE.md` - Implementation status and ActiveSession guidelines

### Benefits

✅ **Consistency** - Same typography style = cohesive feel across app
✅ **Accessibility** - Uses semantic text styles, respects Dynamic Type
✅ **Maintainability** - Change once, updates everywhere
✅ **Layout Stability** - Monospaced numbers prevent timer/counter jumping
✅ **Personality** - Rounded display adds confident, friendly feel
✅ **Elegance** - Tracked labels add premium, refined aesthetic
✅ **Visual Harmony** - HomeView and WorkoutBuilderView feel cohesive
✅ **Subtle Pop** - ActiveSession UI has just enough emphasis without being loud

### Implementation Locations

**Theme Files (split for maintainability):**
```swift
// AppColors.swift - Color definitions
struct AppColors {
    static let dominant = Color(hex: "00CED1")
    static let background = Color(hex: "0A0A0B")
    // ... module colors, semantic colors
}

// AppGradients.swift - Gradient definitions
struct AppGradients {
    static let cardGradient = LinearGradient(...)
    static func moduleGradient(_ type: ModuleType) -> LinearGradient
}

// AppSpacing.swift, AppCorners.swift, AppShadows.swift, AppAnimations.swift
// - Single-purpose design token files
```

**Typography (`AppTheme.swift`):**
```swift
extension Font {
    static var displayLarge: Font      // .largeTitle, rounded, bold
    static var displayMedium: Font     // .title, rounded, bold
    static var monoLarge: Font         // .largeTitle, monospaced
    static var monoMedium: Font        // .title3, monospaced
    // ... 8 total font variants
}

extension View {
    func displayLarge(color:) -> some View
    func monoLarge(color:) -> some View
    func elegantLabel(color:, tracking:) -> some View
    func statLabel(color:, tracking:) -> some View
    // ... 13 total view modifiers
}
```

**Color enhancements:**
- `HomeView.swift:623-725` - Week in Review gradient borders
- `HomeView.swift:165-186` - Weekly calendar gradient border
- `SessionComponents.swift:46-52` - Current set indicator opacity
- `SessionComponents.swift:1009` - Log button enhanced shadow
- `ActiveSessionView.swift:restTimerBar` - Urgent state glow

## Recent Bug Fixes (Jan 27, 2025)

All 10 identified UX bugs have been fixed and pushed to main:

1. **Volume calculation** - Fixed to only count completed sets (not scheduled sets)
   - Location: `Session.swift:270` - `totalVolume` computed property
   - Added `if set.completed` check before adding to volume total

2. **Distance decimal precision** - Increased from 1 to 2 decimal places
   - Location: `FormattingHelpers.swift` - `formatDistance()` and `formatDistanceValue()`
   - Changed format specifier from `%.1f` to `%.2f`

3. **Last session measurables** - Equipment measurables now display correctly
   - Location: `ActiveSessionView.swift` - `equipmentMeasurablesPills()`
   - Already working, verified implementation

4. **Completed set layout overflow** - Fixed elements being pushed outside container
   - Location: `SessionComponents.swift` - SetRowView body
   - Applied `.fixedSize()` to setNumberBadge, sameAsLastButton, logButton
   - Added proper `.layoutPriority()` values to prevent squishing

5. **Skipped exercises in last session** - No longer show exercises with no logged data
   - Location: `SessionViewModel.swift:896` - `getLastSessionData()`
   - Created `hasAnyMetricData()` helper checking all 12 possible set fields
   - Filters exercises that only have scheduled but no completed data

6. **Quality measure removed** - Removed 1-5 quality rating from explosive exercises
   - Locations: `SessionComponents.swift`, `ActiveSessionView.swift`
   - Removed quality input UI, quality from onLog callback (12 params → 11)
   - Removed quality display from completed sets

7. **Unilateral/RPE toggle updates** - Changes now reflect immediately in active session
   - Location: `ExerciseModificationSheets.swift:127` - EditExerciseSheet
   - Added `.onChange(of: activePicker)` to auto-save when EditSetGroupSheet dismisses
   - Eliminates need to manually save EditExerciseSheet after toggling options

8. **Interval timer accuracy** - Fixed timer running ~1:02 per minute instead of 1:00
   - Location: `IntervalTimerView.swift:283` - `startTimer()`
   - Changed from `Timer.scheduledTimer()` to manual Timer creation
   - Set `tolerance = 0.05` (50ms) for tight accuracy
   - Added to `.common` RunLoop mode to continue during UI interactions

9. **Scheduled workout names** - Now display current workout name instead of snapshot
   - Location: `WorkoutViewModel.swift:344` - Added `getCurrentWorkoutName()`
   - Updated `HomeScheduleSheets.swift:433` and `ProgramsListView.swift:542`
   - Changed from `scheduled.workoutName` to `workout.name` where workout available
   - Falls back to snapshot name if workout deleted

10. **Muscle/equipment editing** - Added full editing capability to EditExerciseSheet
    - Location: `ExerciseModificationSheets.swift:10` - Refactored sheet architecture
    - **Problem:** Swift compiler timeout with multiple `.sheet()` modifiers
    - **Solution:** Created `EditExercisePickerType` enum (Identifiable, Equatable)
    - Unified all sheets into single `.sheet(item: $activePicker)` with enum-based routing
    - Added `selectedImplementIds` state and equipment editing UI
    - Made muscles fully editable (previously read-only)
    - Saves implementIds, primaryMuscles, and secondaryMuscles on changes

### Technical Patterns from Bug Fixes

**Enum-based sheet routing** (fixes Swift compiler complexity):
```swift
enum EditExercisePickerType: Identifiable, Equatable {
    case exercise
    case setGroup(Int)
    case equipment
    case muscles
}
@State private var activePicker: EditExercisePickerType? = nil

// Single sheet instead of 3-4 separate .sheet() modifiers
.sheet(item: $activePicker) { type in
    pickerSheet(for: type)  // @ViewBuilder returns appropriate view
}
```

**Timer accuracy pattern**:
```swift
let timer = Timer(timeInterval: 1.0, repeats: true) { ... }
timer.tolerance = 0.05  // 50ms tolerance for accuracy
RunLoop.current.add(timer, forMode: .common)  // Continue during UI
```

**Layout priority pattern** (prevent UI element squishing):
```swift
HStack {
    fixedElement.fixedSize().layoutPriority(2)  // Never squish
    flexibleElement.layoutPriority(1)           // Can shrink
    Spacer(minLength: 0)
    button.fixedSize().layoutPriority(1)        // Prefer keeping
}
```

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
│   ├── Programs/                 (9 files)
│   │   ├── ProgramsListView.swift
│   │   ├── ProgramFormView.swift       (~1050 lines)
│   │   ├── ProgramDetailView.swift
│   │   ├── ProgressionConfigurationView.swift  (~530 lines)
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
├── Models/                       (20+ files)
│   ├── ExerciseInstance.swift
│   ├── Module.swift
│   ├── Workout.swift
│   ├── Program.swift
│   ├── ScheduledWorkout.swift
│   ├── Session.swift             (Session struct only)
│   ├── SessionExercise.swift     (Exercise logging data)
│   ├── CompletedModule.swift     (Module completion data)
│   ├── CompletedSetGroup.swift   (Set group completion)
│   ├── SetData.swift             (Individual set data)
│   ├── MeasurableValue.swift     (Equipment measurable values)
│   ├── ProgressionRule.swift     (Progression rules & suggestions)
│   ├── SetGroup.swift
│   ├── UserProfile.swift
│   ├── ExerciseLibrary.swift
│   ├── CustomExerciseLibrary.swift
│   ├── ResolvedExercise.swift
│   ├── SyncQueue.swift
│   ├── SchemaVersions.swift
│   └── Enums.swift
│
├── Services/                     (19 files)
│   ├── FirebaseService.swift     (34KB)
│   ├── AuthService.swift
│   ├── SyncManager.swift         (25KB)
│   ├── DataRepository.swift      (Coordinator)
│   ├── ModuleRepository.swift    (Module CRUD)
│   ├── WorkoutRepository.swift   (Workout CRUD)
│   ├── SessionRepository.swift   (Session CRUD)
│   ├── ProgramRepository.swift   (Program CRUD + progression)
│   ├── ProgressionService.swift  (Progression calculations)
│   ├── ExerciseResolver.swift
│   ├── SyncLogger.swift
│   ├── Logger.swift
│   ├── DeletionTracker.swift
│   ├── AppConfig.swift
│   └── [supporting services]
│
├── CoreData/                     (3 files)
├── Theme/                        (8 files)
│   ├── AppTheme.swift            (~620 lines - view modifiers, cards, buttons, forms)
│   ├── AppColors.swift           (Color palette, module colors, hex extension)
│   ├── AppGradients.swift        (Gradient definitions)
│   ├── AppSpacing.swift          (Spacing constants)
│   ├── AppCorners.swift          (Corner radius values)
│   ├── AppShadows.swift          (Shadow styles)
│   ├── AppAnimations.swift       (Animation definitions)
│   ├── Components.swift
│   └── Font+Extensions.swift     (Standalone, also in AppTheme)
├── Utilities/                    (3 files)
└── gym_appApp.swift

TodayWorkoutWidget/               (iOS widget extension)
Tests/                            (7 test files)
├── DataRepositoryTests.swift     (Comprehensive CRUD tests)
├── ModuleMergeTests.swift
├── ExerciseInstanceTests.swift
├── SessionNavigatorTests.swift
├── ProgressionServiceTests.swift
└── gym_appTests.swift
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
- [x] Scheduled workouts within programs (dynamically reflect workout name changes)
- [x] Reusable workout modules
- [x] Sets, reps, weight, RPE, duration, distance logging
- [x] Exercise substitution during workout
- [x] Add exercises on-the-fly
- [x] Delete exercises (swipe-to-delete)
- [x] Superset support
- [x] Edit workout history
- [x] Edit exercises during active session (name, type, muscles, equipment, set groups)
- [x] Unilateral/RPE toggles update session immediately

### Smart Features
- [x] Auto-fill from last session (weight, reps, duration, distance, band color, RPE, equipment measurables)
- [x] Priority: last session > target values > empty
- [x] Recent sets quick-edit sheet
- [x] Workout overview with jump-to-exercise
- [x] Last session excludes exercises with no logged data (skipped exercises filtered)
- [x] Progressive overload suggestions (per-exercise configuration, smart defaults, custom rules)

### UI/UX
- [x] Dark theme with custom palette
- [x] Time wheel pickers
- [x] Tab-based navigation
- [x] Sheet-based editing
- [x] Interval timer (accurate 1-second intervals with proper RunLoop configuration)
- [x] Session pagination
- [x] Sync error banner
- [x] Completed set layout with proper sizing (no overflow)
- [x] Distance precision to 2 decimal places
- [x] Volume calculations accurate (completed sets only)

### Data Management
- [x] Offline-first CoreData persistence
- [x] Firebase cloud sync
- [x] Deep merge for multi-device
- [x] Deletion tracking
- [x] Decode failure tracking
- [x] Schema versioning

## Planned Features

### Smart Features (Next Priority)
- [x] Progressive overload suggestions (per-exercise configuration, automatic calculations)
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
- ✅ Recent bug fix sprint completed (10 bugs fixed)
- Ongoing: Dogfood and identify new friction points
- Focus areas: Animation timing, button hit targets, keyboard flow
- User testing: Watch others use it without guidance

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

**Theme System (split into focused files):**
- Colors: `AppColors.dominant`, `AppColors.textPrimary`, etc. (`Theme/AppColors.swift`)
- Gradients: `AppGradients.cardGradient`, `AppGradients.moduleGradient()` (`Theme/AppGradients.swift`)
- Typography: `.displayLarge()`, `.monoMedium()`, `.elegantLabel()`, `.statLabel()` (`Theme/AppTheme.swift`)
- Spacing: `AppSpacing.sm`, `AppSpacing.md`, `AppSpacing.lg` (`Theme/AppSpacing.swift`)
- Corners: `AppCorners.small`, `AppCorners.medium`, `AppCorners.large` (`Theme/AppCorners.swift`)
- Shadows: `AppShadows.soft`, `AppShadows.glow` (`Theme/AppShadows.swift`)
- Animation: `AppAnimation.quick`, `AppAnimation.standard`, `AppAnimation.bounce` (`Theme/AppAnimations.swift`)

**Typography Guidelines:**
- Timers/counters → `.monoLarge()` / `.monoMedium()` (prevents layout shift)
- Big stats/numbers → `.displayLarge()` / `.displayMedium()` (rounded, bold)
- Section headers → `.elegantLabel()` (uppercase + tracking)
- Stat labels → `.statLabel()` (tiny uppercase under numbers)
- Body text → `.headline()` / `.body()` / `.caption()`
- See `design docs/TYPOGRAPHY.md` for complete guide

**UI Patterns:**
- Sheets: `.presentationDetents([.medium])`
- Exercise types have `.icon` property for SF Symbols
- Cards use `.gradientCard()` modifier for consistent styling
- Buttons use `.buttonStyle(.bouncy)` for tactile feedback

## Key Code Locations

### Session/Workout Flow
- **Active session UI**: `ActiveSessionView.swift` (~1700 lines)
- **Set input components**: `SessionComponents.swift` (~1200 lines) - SetRowView with exercise-type-specific inputs
- **Session state management**: `SessionViewModel.swift` (35KB)
- **Exercise editing during session**: `ExerciseModificationSheets.swift` - EditExerciseSheet, EditSetGroupSheet
- **Last session data lookup**: `SessionViewModel.swift:896` - `getLastSessionData()`
- **Interval timer**: `IntervalTimerView.swift` - full-screen timer with pause/skip
- **Session end flow**: `EndSessionSheet.swift` - workout summary, feeling rating, progression notes

### Data Models
- **Session data structure**: `Session.swift`, `SessionExercise.swift`, `CompletedSetGroup.swift`, `SetData.swift`
- **Module/Workout planning**: `Module.swift`, `Workout.swift`, `ExerciseInstance.swift`
- **Programs**: `Program.swift` - training blocks with scheduled workouts + progression config
- **Progression rules**: `ProgressionRule.swift` - ProgressionMetric, ProgressionRule, ProgressionSuggestion
- **Scheduled workouts**: `ScheduledWorkout.swift` - workout slots on calendar
- **Exercise library**: `ExerciseLibrary.swift` (built-in), `CustomExerciseLibrary.swift` (user)

### Progression System
- **Progression configuration UI**: `ProgressionConfigurationView.swift` - per-exercise toggle + rule editing
- **Progression calculations**: `ProgressionService.swift` - weight/reps progression based on history
- **Program progression fields**: `Program.swift` - progressionEnabledExercises, exerciseProgressionOverrides
- **CoreData persistence**: `ProgramRepository.swift` - progression field encoding/decoding

### Formatting & Utilities
- **Number/time formatting**: `FormattingHelpers.swift` - distance, weight, duration, pace
- **Exercise resolution**: `ExerciseResolver.swift` - template + instance → resolved exercise
- **Theme system**: `Theme/` folder - AppColors, AppGradients, AppSpacing, AppCorners, AppShadows, AppAnimations, AppTheme
- **Logging**: `Logger.swift`, `SyncLogger.swift`

### Home & Scheduling
- **Home view**: `HomeView.swift` (~800 lines) - today's workout, recent sessions, calendar
- **Schedule sheets**: `HomeScheduleSheets.swift` (29KB) - date detail, scheduling UI
- **Workout scheduling**: `WorkoutViewModel.swift` - schedule/unschedule, get current name

### Sync & Persistence
- **Local storage coordinator**: `DataRepository.swift` - delegates to entity-specific repositories
- **Entity repositories**: `ModuleRepository.swift`, `WorkoutRepository.swift`, `SessionRepository.swift`, `ProgramRepository.swift`
- **Cloud sync**: `FirebaseService.swift` (34KB) - Firestore CRUD
- **Sync coordination**: `SyncManager.swift` (25KB) - queue, retry, conflict resolution
- **Merge logic**: Deep merge in `Module.swift:mergedWith()`, `Workout.swift:mergedWith()`

## Build Notes

- Firebase packages can be slow to resolve
- If PIF errors: `rm -rf ~/Library/Developer/Xcode/DerivedData/gym_app-*`
- Build with `CODE_SIGNING_ALLOWED=NO` for CI/testing

## Common Patterns & Solutions

### Swift Compiler Timeout with Multiple Sheets
**Problem:** Adding 3+ `.sheet()` modifiers to a view causes "compiler unable to type-check this expression in reasonable time"

**Solution:** Use enum-based sheet routing with single `.sheet(item:)` modifier
```swift
enum PickerType: Identifiable, Equatable {
    case option1
    case option2(Int)  // Can have associated values

    var id: String { /* unique ID */ }
}

@State private var activePicker: PickerType? = nil

.sheet(item: $activePicker) { type in
    switch type {
    case .option1: PickerView1()
    case .option2(let index): PickerView2(index: index)
    }
}
```

### Auto-Saving Sheet Changes
**Pattern:** Child sheet edits should reflect immediately in parent view
```swift
.sheet(item: $picker) { /* sheet content */ }
.onChange(of: picker) { oldValue, newValue in
    // When specific sheet dismisses (oldValue != nil, newValue == nil)
    if case .specificSheet = oldValue, newValue == nil {
        saveChanges()  // Auto-save to update parent
    }
}
```

### Accurate Timer Implementation
**Pattern:** RunLoop configuration for precise timing
```swift
let timer = Timer(timeInterval: 1.0, repeats: true) { _ in /* work */ }
timer.tolerance = 0.05          // 50ms tolerance
RunLoop.current.add(timer, forMode: .common)  // Continue during UI interactions
```

### Layout Priority to Prevent Squishing
**Pattern:** Critical UI elements should never compress
```swift
HStack {
    criticalElement
        .fixedSize()           // Never compress
        .layoutPriority(2)     // Highest priority

    flexibleContent
        .layoutPriority(1)     // Can shrink if needed

    Spacer(minLength: 0)

    button
        .fixedSize()
        .layoutPriority(1)
}
```

### Comprehensive Data Validation
**Pattern:** Check all possible fields when filtering data
```swift
// Example: Checking if set has any logged data
private func hasAnyMetricData(_ set: SetData) -> Bool {
    return set.weight != nil ||
           set.reps != nil ||
           set.duration != nil ||
           set.distance != nil ||
           set.rpe != nil ||
           set.bandColor != nil ||
           set.holdTime != nil ||
           set.intensity != nil ||
           set.height != nil ||
           set.temperature != nil ||
           !set.implementMeasurableValues.isEmpty
}
```

### Dynamic Name Resolution
**Pattern:** Reference data by ID, look up display name dynamically
```swift
// Store: workoutId (UUID reference)
// Display: workout.name (current name from lookup)
// Fallback: scheduled.workoutName (snapshot if deleted)

func getCurrentWorkoutName(for scheduled: ScheduledWorkout) -> String {
    guard let workoutId = scheduled.workoutId,
          let workout = getWorkout(id: workoutId) else {
        return scheduled.workoutName  // Fallback to snapshot
    }
    return workout.name  // Current name
}
```
