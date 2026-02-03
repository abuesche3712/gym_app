# Gym App - Development Context

> Reference document for Claude Code sessions
> **Last updated:** 2026-02-03 (Builder UI components extraction)

## Project Overview

iOS workout tracking app built with SwiftUI. Offline-first with CoreData, Firebase for cloud sync.

**Status:** Feature-complete foundation with UX bugs fixed and design system fully implemented. Typography refactoring complete. Major refactoring completed (DataRepository split, Session model split, AppTheme split, Session views split). Per-exercise progression system implemented. Comprehensive DataRepository tests added. **Social features Phase 1-5 complete** (Profiles, Friendships, Messaging, Sharing, Feed). **Design system unified** (Feb 1, 2026). **Twitter-style feed implemented** (Feb 1, 2026).

## Twitter-Style Feed Implementation (Feb 1, 2026)

Redesigned social feed with flat Twitter/X-style layout and improved workout content display.

### New Feed Components

**FeedPostRow.swift** - Twitter-style flat post row:
```swift
VStack(alignment: .leading, spacing: AppSpacing.sm) {
    // Top row: Avatar + Author info
    HStack(alignment: .top, spacing: AppSpacing.sm) {
        PostAvatarView(...)
        authorLine  // Name, @username, time, menu
    }

    // Caption (if any) - full width
    if let caption = post.post.caption { Text(caption)... }

    // Attachment card (centered on full width)
    attachmentContent.frame(maxWidth: .infinity)

    // Engagement bar (evenly spaced)
    engagementBar  // Like, Comment, Share buttons
}
.padding(.horizontal, AppSpacing.screenPadding)
.background(AppColors.background)
```

**WorkoutAttachmentCard.swift** - Hero content card for workout posts:
- Shows workout name, duration, date
- Stats row: total sets, exercises, volume
- **TOP LIFTS section**: Best weight×reps for strength exercises
- **CARDIO section**: Duration and distance for cardio exercises
- **HOLDS section**: Total hold time for isometric exercises

### Feed Layout Changes
- Flat layout with thin dividers between posts (vs. cards with margins)
- Avatar on left, content flows vertically below author line
- Workout attachment card centered on full screen width
- Engagement buttons evenly distributed with `.frame(maxWidth: .infinity)`

### Tab Navigation Improvements
- Pop-to-root on tab re-tap using `.id()` modifier pattern
- State triggers increment to force NavigationStack reset:
```swift
@State private var homePopToRoot = 0
HomeView().id("home-\(homePopToRoot)").tag(0)

private func popToRoot(tab: Int) {
    switch tab {
    case 0: homePopToRoot += 1
    // ...
    }
}
```

### Compose Button Fix
- Moved above tab bar with `padding(.bottom, 80)`
- Changed to gold color (`AppColors.accent2`)

### Bug Fixes (Feb 1, 2026)

**Quick log/freestyle sessions not appearing until restart:**
- **Root cause:** `QuickLogSheet.saveQuickLog()` saved to DataRepository but never called `sessionViewModel.loadSessions()` to refresh the observable array
- **Fix:** Added `sessionViewModel.loadSessions()` after saving in `QuickLogSheet.swift:521`

**Freestyle session start button requiring multiple clicks:**
- **Root cause:** Keyboard auto-focused on sheet appear; button taps conflicted with keyboard dismissal
- **Fix:** In `FreestyleNameSheet`:
  - Created `startSession()` helper that dismisses keyboard first (`isFocused = false`)
  - Added haptic feedback for immediate response feel
  - Added 0.1s delay before calling `onStart()` to ensure keyboard dismisses
  - Added `.submitLabel(.go)` and `.onSubmit` for keyboard "Go" button support

**Week in Review not updating when navigating weeks:**
- **Root cause:** Stats computed from `Date()` (current week) instead of `selectedCalendarDate`
- **Fix:** In `HomeView.swift`:
  - Added `sessionsInSelectedWeek` computed property that filters by selected week dates
  - Updated `sessionsThisWeek`, `volumeThisWeek`, `cardioMinutesThisWeek`, `scheduledThisWeek` to use selected week
  - Now navigating forward/backward in calendar updates Week in Review stats

**Compose post module drill-down missing:**
- **Root cause:** Clicking a module in SessionContentPicker immediately selected it instead of showing exercises
- **Fix:** In `ComposePostSheet.swift`:
  - Added `selectedModule` state to `SessionContentPicker`
  - Added `ModuleContentPicker` view showing:
    - "Share Entire Module" option at top
    - List of exercises within module with set counts and top set stats
  - Users can now drill into modules to share specific exercises

## Strong App Import Feature (Feb 2, 2026)

Full CSV import from Strong app workout exports, allowing users to migrate their workout history.

### New Files

**StrongImportService.swift** - Core import engine:
- Parses Strong's CSV format (Date, Workout Name, Duration, Exercise Name, Set Order, Weight, Reps, Distance, Seconds, Notes)
- Handles quoted fields with embedded newlines/commas
- Weight unit conversion (lbs ↔ kg)
- Duration string parsing ("1h 15m" → 75 minutes)
- Groups rows by date+workout into Session objects
- Deterministic UUID generation for consistent imports
- Duplicate detection against existing sessions

**ImportDataView.swift** - Import UI:
- Multi-state flow: ready → parsing → preview → importing → complete/error
- Weight unit picker (match CSV source)
- Preview shows workout count, exercise count, date range
- Duplicate warnings before import
- Progress bar during import
- Session list preview (first 50 workouts)

### Session Model Changes

```swift
// Session.swift - New flag for imported sessions
var isImported: Bool  // true for sessions imported from external apps
```

- Added to init, decoder, and CodingKeys
- Backward compatible (defaults to false)
- Imported sessions show distinct "Imported" badge in history (vs "Quick Log")

### Pagination Fix for Old Imports

**Problem:** Sessions older than 90 days weren't appearing in History after import (pagination cutoff)

**Solution:**
- Added `loadAllSessions()` to SessionViewModel - bypasses pagination
- ImportDataView calls `loadAllSessions()` after import
- HistoryView pull-to-refresh now calls `loadAllSessions()` to show full history

### Files Modified
- `Session.swift` - Added `isImported` flag
- `SessionViewModel.swift` - Added `loadAllSessions()` method
- `HistoryView.swift` - "Imported" badge, pull-to-refresh loads all sessions
- `SettingsView.swift` - "Import from Strong" navigation link

### Usage Flow
1. User goes to Settings → Import from Strong
2. Selects weight unit used in Strong CSV
3. Picks CSV file from Files app
4. Reviews preview (workout count, warnings, duplicates)
5. Confirms import
6. Sessions appear in History with "Imported" badge

## Bug Fixes (Feb 2, 2026)

**Widget not updating when session deleted:**
- **Root cause:** `SessionViewModel.deleteSession()` removed session from CoreData but never notified WidgetKit
- **Fix:** In `SessionViewModel.swift`:
  - Added `import WidgetKit`
  - After deleting session, check if it was from today
  - If today had other sessions, update widget with latest session data
  - If today is now empty, write `.noWorkout` to widget data
  - Call `WidgetCenter.shared.reloadTimelines(ofKind: "TodayWorkoutWidget")`

**Add set button not working when no sets prescheduled:**
- **Root cause:** `addSetToCurrentExercise()` in `ActiveSessionView.swift:480` had a guard that returned early if `completedSetGroups` was empty
- **Fix:** Changed guard to conditional logic:
  - If existing sets exist: copy targets from last set (same as before)
  - If no sets exist: create new `CompletedSetGroup` with default empty `SetData`
- **Impact:** Freestyle and quick log workouts can now add sets even when starting with no prescheduled sets

**Feed posts only showing lifting data (Bug 5):**
- **Root cause:** `ExerciseAttachmentCard` and `SetAttachmentCard` in `FeedPostRow.swift` were hardcoded for strength exercises
- **Fix:** Added exercise type detection based on available set data:
  - Detects strength (weight/reps), cardio (duration/distance), isometric (holdTime), band (bandColor)
  - `ExerciseAttachmentCard` now shows appropriate metrics: cardio shows total duration/distance, isometric shows total hold time
  - `SetAttachmentCard` displays time/distance for cardio, hold time for isometric, band color for band exercises
  - Uses appropriate icons and colors per type (dumbbell for strength, figure.run for cardio, timer for isometric)

**Feed post distances ignore per-exercise unit (Bug 6):**
- **Root cause:** `WorkoutAttachmentCard` cardio section hardcoded "mi" for distance display
- **Fix:** In `WorkoutAttachmentCard.swift`:
  - Added `distanceUnit: DistanceUnit` to `cardioHighlights` tuple
  - `formatDistance()` now uses exercise's `distanceUnit.abbreviation` instead of hardcoded "mi"
  - Distance displays correctly as km, mi, m, etc. based on how user logged it

**Module sync not working for resumed sessions (Bug 7):**
- **Root cause:** `resumeSession()` in `SessionViewModel.swift` didn't restore `originalModules`, leaving it empty
- **Fix:** Added original module restoration when resuming a session:
  ```swift
  if let workout = repository.getWorkout(id: session.workoutId) {
      originalModules = workout.moduleReferences.compactMap { repository.getModule(id: $0.moduleId) }
  }
  ```
- **Impact:** Structural change detection now works correctly for sessions resumed after crash recovery

## Major Refactoring (Jan 29, 2026)

### Builder UI Components Extraction (Feb 3, 2026)

Extracted shared UI patterns from `ModuleFormView` and `WorkoutFormView` into reusable components.

**New files in `Views/Components/Builder/`:**

| Component | Lines | Purpose |
|-----------|-------|---------|
| `BuilderEmptyState.swift` | 48 | Empty state placeholder with icon/title/subtitle |
| `BuilderQuickAddBar.swift` | 78 | Search bar with add/clear button support |
| `BuilderSearchResultRow.swift` | 104 | Search result row (simple and detail variants) |
| `BuilderItemRow.swift` | 121 | Item row with order indicator, drag handle, edit/delete |
| `BuilderActionButton.swift` | 69 | Action button for browse/create actions |

**Line reductions:**
- `ModuleFormView.swift`: 735 → 626 lines (-109)
- `WorkoutFormView.swift`: 1150 → 979 lines (-171)

**Usage patterns:**
```swift
// Empty state
BuilderEmptyState(
    icon: "dumbbell",
    title: "No exercises yet",
    subtitle: "Search above or browse the library"
)

// Quick add search bar
BuilderQuickAddBar(
    placeholder: "Quick add exercise...",
    text: $searchText,
    accentColor: moduleColor,
    showAddButton: true,
    onAdd: { addExercise() }
)

// Search result row (simple)
BuilderSearchResultRow(
    icon: template.exerciseType.icon,
    iconColor: AppColors.dominant,
    title: template.name,
    subtitle: template.exerciseType.displayName,
    accentColor: moduleColor,
    onSelect: { selectTemplate(template) }
)

// Search result row with detail
BuilderSearchResultRowWithDetail(
    icon: module.type.icon,
    iconColor: AppColors.moduleColor(module.type),
    title: module.name,
    detail: "\(module.exercises.count) exercises",
    accentColor: AppColors.accent1,
    onSelect: { selectModule(module) }
)

// Item row
BuilderItemRow(
    index: index,
    title: exercise.name,
    subtitle: "\(exercise.exerciseType.displayName) • 3x10",
    accentColor: moduleColor,
    showDragHandle: true,
    showEditButton: true,
    onEdit: { editExercise(exercise) },
    onDelete: { deleteExercise(at: index) }
)

// Action button
BuilderActionButton(
    icon: "books.vertical",
    title: "Browse Exercise Library",
    color: moduleColor,
    action: { showingPicker = true }
)
```

**Note:** Exercise row in `WorkoutFormView` kept custom due to superset selection complexity.

### CoreDataRepository Protocol (Feb 3, 2026)

Consolidated ~50% of repetitive CRUD boilerplate from the four main repositories into a shared protocol.

**New file:** `Repositories/CoreDataRepository.swift`

```swift
protocol CoreDataRepository {
    associatedtype DomainModel: Identifiable where DomainModel.ID == UUID
    associatedtype CDEntity: NSManagedObject

    var persistence: PersistenceController { get }
    var entityName: String { get }
    var defaultSortDescriptors: [NSSortDescriptor] { get }
    var defaultPredicate: NSPredicate? { get }  // Optional, defaults to nil

    func toDomain(_ entity: CDEntity) -> DomainModel
    func updateEntity(_ entity: CDEntity, from model: DomainModel)
}
```

**Default implementations provided via protocol extension:**
- `viewContext` - computed property accessing persistence.container.viewContext
- `loadAll()` - generic fetch with sort/predicate
- `find(id:)` - find by UUID
- `save(_:)` - find-or-create + update + persist
- `delete(_:)` - find + delete + persist
- `findEntity(id:)` - low-level entity lookup for sync
- `deleteEntity(id:)` - low-level deletion for sync
- `findOrCreateEntity(id:)` - find or create new entity with ID

**Refactored repositories:**
- `ModuleRepository` - removed ~60 lines, kept exercise instance conversion helpers
- `WorkoutRepository` - removed ~55 lines, uses `defaultPredicate` for `archived == NO`
- `ProgramRepository` - removed ~45 lines, kept `findActive()` specialized query
- `SessionRepository` - kept all specialized methods (pagination, history, in-progress recovery)

**Pattern for conforming:**
```swift
@MainActor
class ModuleRepository: CoreDataRepository {
    typealias DomainModel = Module
    typealias CDEntity = ModuleEntity

    let persistence: PersistenceController
    var entityName: String { "ModuleEntity" }
    var defaultSortDescriptors: [NSSortDescriptor] {
        [NSSortDescriptor(keyPath: \ModuleEntity.name, ascending: true)]
    }

    func toDomain(_ entity: ModuleEntity) -> Module { /* conversion */ }
    func updateEntity(_ entity: ModuleEntity, from module: Module) { /* update */ }
}
```

### DataRepository Split

Split monolithic `DataRepository.swift` into entity-specific repositories for better maintainability:

```
Repositories/
├── CoreDataRepository.swift  (Protocol with default CRUD implementations)
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

## Session Views Refactoring (Jan 31, 2026)

Split large session-related files into focused, single-responsibility components:

### SessionComponents.swift Split
Split 1,379-line file into focused view files:
```
Views/Session/
├── SetRowView.swift           (Main set input row - strength, cardio, etc.)
├── StrengthInputsView.swift   (Weight/reps input fields)
├── CardioInputsView.swift     (Duration/distance input fields)
└── TimeInputPickers.swift     (Time picker sheets, set indicators)
```

### ExerciseModificationSheets.swift Split
Split 1,306-line file into focused sheet files:
```
Views/Session/
├── EditExerciseSheet.swift    (Edit exercise during session - name, type, muscles, equipment)
├── EditSetGroupSheet.swift    (Edit set group configuration)
└── AddExerciseSheet.swift     (Add exercise to module sheet)
```

### ActiveSessionView.swift Partial Split
Extracted key components (~1,874 → ~1,400 lines):
```
Views/Session/
├── SessionHeaderView.swift      (Header with progress ring)
├── RestTimerBar.swift           (Inline rest timer display)
├── SessionCompleteOverlay.swift (Workout complete animation)
├── PreviousPerformanceSection.swift (Previous workout data display)
└── SetListSection.swift         (All sets display)
```

### New View Modifiers (AppTheme.swift)
```swift
// Convenience modifiers for common patterns
extension View {
    func cardBackground(_ corners: AppCorners.Size = .medium, color: Color = AppColors.surfacePrimary) -> some View
    func screenPadded(_ edges: Edge.Set = .horizontal) -> some View
}
```

### Logger Integration
Replaced `print()` statements with `Logger` utility in:
- `HapticManager.swift` - Audio session and haptic feedback logging
- `WidgetData.swift` - Widget data encoding/decoding errors

## Design System Unification (Feb 1, 2026)

Comprehensive visual unification: eliminated pink, standardized cards/headers, restructured tabs.

### Color Scheme Standardization

**Entity-to-Color Mapping:**
| Entity | Color | Constant |
|--------|-------|----------|
| Programs | Gold/Amber | `AppColors.accent2` |
| Workouts | Cyan | `AppColors.dominant` |
| Modules | Purple | `AppColors.accent3` |

**AppColors.swift Changes:**
```swift
// Changed programAccent from pink to gold
static let programAccent = accent2  // was: accent4 (pink)
```

**AppGradients.swift Changes:**
```swift
// Gold-based gradient for programs
static let programGradient = LinearGradient(
    colors: [AppColors.accent2.opacity(0.4), AppColors.accent2.opacity(0.15)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### Unified Card Styling

**Pattern:** Flat background + fading gradient colored border

```swift
// Card with fading colored border (e.g., WorkoutBuilderView BuilderCard)
.background(AppColors.surfacePrimary)
.cornerRadius(AppCorners.large)
.overlay(
    RoundedRectangle(cornerRadius: AppCorners.large)
        .stroke(
            LinearGradient(
                colors: [iconColor.opacity(0.4), iconColor.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
)
```

**Files Updated:**
- `WorkoutBuilderView.swift` - BuilderCard with colored fading borders
- `ModulesListView.swift` - ModuleListCard with purple fading border
- `WorkoutsListView.swift` - WorkoutListCard with cyan fading border
- `ProgramsListView.swift` - ProgramListCard with gold fading border
- `HomeView.swift` - Week Calendar and Week in Review use neutral borders

### Tab Bar Restructure (5 → 4 tabs)

**Before:** Home, Workout, Social, Analytics, More
**After:** Home, Training, Social, Analytics

**MainTabView.swift Changes:**
- Removed "More" tab entirely
- Renamed "Workout" to "Training"
- History and Settings now accessible from HomeView header

**HomeView.swift Header Additions:**
```swift
// Navigation links in header
NavigationLink(destination: HistoryView()) {
    Image(systemName: "clock.arrow.circlepath")
}
NavigationLink(destination: SettingsView()) {
    Image(systemName: "gearshape.fill")
}
```

### Pink Removal (14 files)

Replaced all pink/magenta (`accent4`) usage with appropriate colors:

**Program Views (now gold/accent2):**
- `ProgramDetailView.swift` - badges, progress bars, buttons, icons
- `ProgramsListView.swift` - indicators, progress bars, buttons
- `ProgramFormView.swift` - status indicators, section headers
- `ProgramWeeklyGridView.swift` - plus buttons
- `CreateProgramSheet.swift` - icon colors
- `AddWorkoutSlotSheet.swift` - checkmarks, row highlights

**Social Views (program content now cyan/dominant):**
- `ComposePostSheet.swift` - program content type color
- `PostCard.swift` - program type badges
- `PostDetailView.swift` - program template card
- `SharedContentCard.swift` - program content type

**Other Views:**
- `WorkoutBuilderView.swift` - section headers, program card uses gold
- `SessionDetailView.swift` - program context badge

### Header Pattern Unification

All tabs now use consistent left-aligned custom header:

```swift
NavigationStack {
    ScrollView {
        VStack {
            // Custom header (no toolbar-based navigation title)
            HStack {
                Text("Tab Name")
                    .font(.title.bold())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                // Right-side navigation items
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            // Tab content...
        }
    }
    .toolbar(.hidden, for: .navigationBar)
}
```

## Bug Fixes (Jan 31, 2026)

### Timer Sounds Not Playing Over Music
**Problem:** Rest timer completion sounds wouldn't play when music was playing
**Solution:** Enhanced audio session configuration in `HapticManager.swift`:
```swift
// Added .duckOthers to temporarily lower music volume
try AVAudioSession.sharedInstance().setCategory(
    .playback,
    mode: .default,
    options: [.mixWithOthers, .duckOthers]
)

// Ensure session is active before each sound
private func ensureAudioSessionActive() {
    try AVAudioSession.sharedInstance().setActive(true)
}

// Use system sound instead of alert sound
AudioServicesPlaySystemSound(soundID)  // Not AudioServicesPlayAlertSound
```

### Sheet Layout Issues from Active Session
**Problem:** Picker sheets (muscle group, equipment, add exercise) displayed with incorrect sizing
**Solution:** Added proper presentation configuration:
```swift
// EditExerciseSheet.swift - Equipment picker
.presentationDetents([.medium, .large])
.presentationDragIndicator(.visible)

// EditExerciseSheet.swift - Muscle group picker
.presentationDetents([.large])

// AddExerciseSheet.swift - Exercise picker
.presentationDetents([.large])
.presentationDragIndicator(.visible)

// ImplementPickerView.swift - Added ScrollView wrapper
ScrollView {
    VStack(alignment: .leading, spacing: AppSpacing.md) { /* content */ }
    .padding()
}
.background(AppColors.background)

// MuscleGroupEnumPickerView - Added background
.background(AppColors.background)
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
├── ViewModels/                   (9 files)
│   ├── AppState.swift
│   ├── SessionViewModel.swift    (35KB - largest)
│   ├── SessionNavigator.swift
│   ├── WorkoutViewModel.swift
│   ├── ProgramViewModel.swift
│   ├── ModuleViewModel.swift
│   ├── FriendsViewModel.swift    (Social - friendships)
│   ├── ConversationsViewModel.swift (Social - message list)
│   └── ChatViewModel.swift       (Social - individual chat)
│
├── Views/                        (40+ files)
│   ├── Session/                  (17 files - workout session UI)
│   │   ├── ActiveSessionView.swift     (~1400 lines, refactored)
│   │   ├── SessionHeaderView.swift     (Header with progress ring)
│   │   ├── RestTimerBar.swift          (Inline rest timer)
│   │   ├── SessionCompleteOverlay.swift (Workout complete animation)
│   │   ├── PreviousPerformanceSection.swift (Previous workout data)
│   │   ├── SetListSection.swift        (All sets display)
│   │   ├── SetRowView.swift            (Main set input row)
│   │   ├── StrengthInputsView.swift    (Weight/reps inputs)
│   │   ├── CardioInputsView.swift      (Duration/distance inputs)
│   │   ├── TimeInputPickers.swift      (Time picker sheets)
│   │   ├── EditExerciseSheet.swift     (Edit exercise during session)
│   │   ├── EditSetGroupSheet.swift     (Edit set group config)
│   │   ├── AddExerciseSheet.swift      (Add exercise to module)
│   │   ├── EndSessionSheet.swift
│   │   ├── WorkoutOverviewSheet.swift
│   │   ├── RecentSetsSheet.swift
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
│   ├── Components/               (7 files)
│   │   ├── Builder/              (5 files - reusable builder UI components)
│   │   │   ├── BuilderEmptyState.swift
│   │   │   ├── BuilderQuickAddBar.swift
│   │   │   ├── BuilderSearchResultRow.swift
│   │   │   ├── BuilderItemRow.swift
│   │   │   └── BuilderActionButton.swift
│   ├── Social/                   (13 files - social features)
│   │   ├── SocialView.swift
│   │   ├── FeedPostRow.swift           (Twitter-style flat post row)
│   │   ├── WorkoutAttachmentCard.swift (Hero workout card)
│   │   ├── AccountProfileView.swift
│   │   ├── UserSearchView.swift
│   │   ├── FriendsListView.swift
│   │   ├── FriendRequestsView.swift
│   │   ├── ConversationsListView.swift
│   │   ├── ChatView.swift
│   │   ├── NewConversationSheet.swift
│   │   ├── ShareWithFriendSheet.swift  (Share content with friends)
│   │   ├── SharedContentCard.swift     (Display shared content)
│   │   └── ImportConflictSheet.swift   (Resolve import conflicts)
│   ├── HomeView.swift            (~800 lines)
│   ├── HomeScheduleSheets.swift  (29KB)
│   └── MainTabView.swift
│
├── Models/                       (25 files)
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
│   ├── UserProfile.swift         (Social - user profile)
│   ├── Friendship.swift          (Social - friend relationships)
│   ├── Conversation.swift        (Social - messaging)
│   ├── Message.swift             (Social - messages with MessageContent enum)
│   ├── ShareBundles.swift        (Social - share bundle models)
│   ├── ImportConflict.swift      (Social - import conflict handling)
│   ├── ExerciseLibrary.swift
│   ├── CustomExerciseLibrary.swift
│   ├── ResolvedExercise.swift
│   ├── SyncQueue.swift
│   ├── SchemaVersions.swift
│   └── Enums.swift
│
├── Repositories/                 (11 files)
│   ├── CoreDataRepository.swift  (Protocol with default CRUD implementations)
│   ├── DataRepository.swift      (Coordinator - delegates to sub-repositories)
│   ├── ModuleRepository.swift    (Module CRUD, conforms to CoreDataRepository)
│   ├── WorkoutRepository.swift   (Workout CRUD, conforms to CoreDataRepository)
│   ├── SessionRepository.swift   (Session CRUD + pagination, conforms to CoreDataRepository)
│   ├── ProgramRepository.swift   (Program CRUD + progression, conforms to CoreDataRepository)
│   ├── ProfileRepository.swift   (Social - user profiles)
│   ├── FriendshipRepository.swift (Social - friendships)
│   ├── ConversationRepository.swift (Social - conversations)
│   ├── MessageRepository.swift   (Social - messages)
│   └── PostRepository.swift      (Social - feed posts)
│
├── Services/                     (14 files)
│   ├── FirebaseService.swift     (38KB - includes social operations)
│   ├── AuthService.swift
│   ├── SyncManager.swift         (25KB)
│   ├── SharingService.swift      (Social - share bundles & import)
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

## Social Features (Jan 31, 2026)

Implemented in 5 phases: Profile → Friendships → Messaging → Sharing → Feed.

### Phase 1: User Profiles
- `UserProfile` model with username, displayName, bio, avatarURL
- `ProfileRepository` for CoreData persistence
- `AccountProfileView` for profile editing
- Username uniqueness validation via Firestore
- Firebase sync for public profile data

### Phase 2: Friendships
- `Friendship` model with status enum (pending, accepted, blocked)
- `FriendshipRepository` for local CRUD + queries
- `FriendsViewModel` managing friends list, requests, blocked users
- Real-time Firestore listener for friendship changes with error callbacks
- Views: `FriendsListView`, `FriendRequestsView`, `UserSearchView`
- Features: Send/accept/decline requests, block/unblock users
- Debounced username search with block filtering

### Phase 3: Messaging
- `Conversation` model with participant IDs, last message preview, unread count
- `Message` model with polymorphic `MessageContent` enum
- `ConversationRepository` and `MessageRepository` for local persistence
- `ConversationsViewModel` managing conversation list with real-time sync
- `ChatViewModel` managing individual chat with message sending
- Views: `ConversationsListView`, `ChatView`, `NewConversationSheet`
- Features:
  - Real-time messaging via Firestore listeners
  - Offline-first with pendingSync status
  - Block filtering (conversations with blocked users hidden)
  - Unread message badges on conversation list and Social tab
  - Message types: text (now), sharing types prepared for Phase 4

### Phase 4: Sharing (Unified)
- Share bundles: `ProgramShareBundle`, `WorkoutShareBundle`, `ModuleShareBundle`, `SessionShareBundle`, `ExerciseShareBundle`, `SetShareBundle`
- Self-contained snapshots with all dependencies (exercises, templates, implements)
- UUID remapping during import to avoid conflicts
- `SharingService` for creating bundles and importing content
- `ShareableContent` protocol for:
  - **Templates:** Programs, Workouts, Modules (importable)
  - **Performance:** Sessions, Exercises, Sets (view-only)
- Wrapper types for performance sharing: `ShareableExercisePerformance`, `ShareableSetPerformance`
- Import conflict detection with resolution options (use existing, import as copy)
- Views:
  - `ShareWithFriendSheet` - Unified friend picker for all shareable content
  - `SharedContentCard` - Display shared content in chat messages
  - `ImportConflictSheet` - Resolve conflicts during import
- Share buttons added to:
  - ProgramDetailView, WorkoutDetailView, ModuleDetailView (templates)
  - SessionDetailView (whole session, modules, exercises, individual sets)
  - HistoryView (via context menu on sessions)
- Module-level sharing: "Post to Feed" and "Share with Friend" options on each completed module in SessionDetailView

### Phase 5: Social Feed (Strava/Twitter Hybrid)
- Redesigned `PostCard` component with sleek, professional appearance
- Content-type-specific cards for each shareable type
- Components extracted for maintainability:
  - `PostHeaderView` - Avatar, username, time, content type badge
  - `PostAvatarView` - User avatar with gradient border
  - `PostContentView` - Routes to type-specific content views
  - `PostFooterView` - Like/comment buttons (animated)
- Type-specific content views with workout statistics:
  - `SessionPostContent` - Duration, volume, sets with exercise breakdown
  - `ExercisePostContent` - Sets, volume, top set for shared exercises
  - `SetPostContent` - PR display with weight/reps, exercise context
  - `CompletedModulePostContent` - Module name, exercise/set counts
  - `ProgramPostContent`, `WorkoutPostContent`, `ModulePostContent` - Template previews
- `StatBox` component for consistent stat display
- Module-level sharing from `SessionDetailView`:
  - Added "Post to Feed" and "Share with Friend" to module share menus
  - `ShareableModulePerformance` wrapper for completed modules
  - `CompletedModuleShareBundle` for serialization

### PostContent Enum (Post.swift)
```swift
enum PostContent: Codable {
    case session(id: UUID, workoutName: String, date: Date, snapshot: Data)
    case exercise(snapshot: Data)
    case set(snapshot: Data)
    case program(id: UUID, name: String, snapshot: Data)
    case workout(id: UUID, name: String, snapshot: Data)
    case module(id: UUID, name: String, snapshot: Data)
    case completedModule(snapshot: Data)  // New: completed module from session
    case text(String)
}
```

### MessageContent Enum
```swift
enum MessageContent: Codable {
    case text(String)
    case sharedProgram(id: UUID, name: String, snapshot: Data)
    case sharedWorkout(id: UUID, name: String, snapshot: Data)
    case sharedModule(id: UUID, name: String, snapshot: Data)
    case sharedSession(id: UUID, workoutName: String, date: Date, snapshot: Data)
    case sharedExercise(snapshot: Data)
    case sharedSet(snapshot: Data)
    case sharedCompletedModule(snapshot: Data)  // New: module from completed session
}
```

### Social File Structure
```
Models/
├── UserProfile.swift
├── Friendship.swift
├── Conversation.swift
├── Message.swift              (MessageContent enum with sharedCompletedModule)
├── Post.swift                 (PostContent enum with completedModule)
├── ShareBundles.swift         (All share bundles including CompletedModuleShareBundle)
└── ImportConflict.swift       (Conflict types and resolution)

Repositories/
├── ProfileRepository.swift
├── FriendshipRepository.swift
├── ConversationRepository.swift
└── MessageRepository.swift

Services/
└── SharingService.swift       (Create bundles, import with UUID remapping)

ViewModels/
├── FriendsViewModel.swift
├── ConversationsViewModel.swift
├── ChatViewModel.swift        (+ import methods for shared content)
└── ComposePostViewModel.swift (Create posts from shareable content)

Views/Social/
├── SocialView.swift           (Main social tab with feed)
├── FeedView.swift             (Social feed display)
├── FeedPostRow.swift          (Twitter-style flat post row)
├── WorkoutAttachmentCard.swift (Hero workout card with exercise highlights)
├── PostCard.swift             (Strava/Twitter hybrid post card)
├── ComposePostSheet.swift     (Create new posts)
├── AccountProfileView.swift   (Profile editing)
├── UserSearchView.swift       (Find friends)
├── FriendsListView.swift      (Friends management)
├── FriendRequestsView.swift   (Pending requests)
├── ConversationsListView.swift (Message list)
├── ChatView.swift             (Individual chat)
├── NewConversationSheet.swift (Start new chat)
├── ShareWithFriendSheet.swift (Share content picker + ShareableModulePerformance)
├── SharedContentCard.swift    (Shared content display in chat)
└── ImportConflictSheet.swift  (Resolve import conflicts)
```

### Firestore Collections
```
users/{userId}/
├── profile (public profile data)
├── modules, workouts, sessions, programs (existing)
└── customExercises (existing)

friendships/{friendshipId} (indexed by participantIds)
conversations/{conversationId}/
├── (conversation metadata)
└── messages/{messageId}

usernames/{username} → userId (uniqueness enforcement)
```

### Required Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - full access to own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Public profile subcollection - readable by all authenticated users
      match /profile/{document=**} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == userId;
      }

      // Exercise library subcollection
      match /exerciseLibrary/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      // Catch-all for other subcollections (modules, workouts, sessions, programs)
      match /{subcollection}/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // Usernames collection (public read for search)
    match /usernames/{username} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow delete: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    // Friendships (read/write if participant)
    match /friendships/{friendshipId} {
      allow create: if request.auth != null &&
        request.auth.uid in request.resource.data.participantIds;
      allow read, update, delete: if request.auth != null &&
        request.auth.uid in resource.data.participantIds;
    }

    // Conversations (read/write if participant)
    match /conversations/{conversationId} {
      allow create: if request.auth != null &&
        request.auth.uid in request.resource.data.participantIds;
      allow read, update, delete: if request.auth != null &&
        request.auth.uid in resource.data.participantIds;

      match /messages/{messageId} {
        allow read, write: if request.auth != null &&
          request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
      }
    }

    // Posts collection (public read, authenticated write)
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if request.auth != null && resource.data.authorId == request.auth.uid;
    }
  }
}
```

## Planned Features

### Smart Features (Next Priority)
- [x] Progressive overload suggestions (per-exercise configuration, automatic calculations)
- [ ] Plate calculator (visual plate loading guide)
- [ ] Rest timer auto-start with haptic
- [ ] Personal records detection with celebration

### Future
- [ ] Analytics dashboard (PRs, volume tracking, trends)
- [x] Social features Phase 1-5 (profiles, friendships, messaging, sharing, feed)

## Code Modularization Opportunities

### Completed (Jan 31, 2026)
- ✅ **SessionComponents.swift** - Split into SetRowView, StrengthInputsView, CardioInputsView, TimeInputPickers
- ✅ **ExerciseModificationSheets.swift** - Split into EditExerciseSheet, EditSetGroupSheet, AddExerciseSheet
- ✅ **ActiveSessionView.swift** - Extracted SessionHeaderView, RestTimerBar, SessionCompleteOverlay, PreviousPerformanceSection, SetListSection

### Remaining Opportunities
1. **HomeView.swift (~800 lines)** - Extract CalendarView, ScheduleWorkoutSheet
2. **EndSessionSheet.swift (~636 lines)** - Extract ExerciseCard subview

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
- Sheets: `.presentationDetents([.medium])` or `.presentationDetents([.large])`
- Exercise types have `.icon` property for SF Symbols
- Cards use `.gradientCard()` or `.cardBackground()` modifier for consistent styling
- Buttons use `.buttonStyle(.bouncy)` for tactile feedback
- Screen padding: `.screenPadded()` for consistent horizontal margins
- Sheet backgrounds: Always include `.background(AppColors.background)` for proper dark mode

## Key Code Locations

### Session/Workout Flow
- **Active session UI**: `ActiveSessionView.swift` (~1400 lines, refactored)
- **Session header**: `SessionHeaderView.swift` - Progress ring and workout info
- **Rest timer display**: `RestTimerBar.swift` - Inline rest timer with skip button
- **Session complete**: `SessionCompleteOverlay.swift` - Workout completion animation
- **Previous performance**: `PreviousPerformanceSection.swift` - Last workout data display
- **Set list**: `SetListSection.swift` - All sets display
- **Set input row**: `SetRowView.swift` - Main input component dispatching to type-specific inputs
- **Strength inputs**: `StrengthInputsView.swift` - Weight/reps input fields
- **Cardio inputs**: `CardioInputsView.swift` - Duration/distance input fields
- **Time pickers**: `TimeInputPickers.swift` - Time picker sheets, set indicators
- **Session state management**: `SessionViewModel.swift` (35KB)
- **Exercise editing**: `EditExerciseSheet.swift` - Edit exercise during session
- **Set group editing**: `EditSetGroupSheet.swift` - Edit set group configuration
- **Add exercise**: `AddExerciseSheet.swift` - Add exercise to module
- **Last session data lookup**: `SessionViewModel.swift:896` - `getLastSessionData()`
- **Interval timer**: `IntervalTimerView.swift` - full-screen timer with pause/skip
- **Session end flow**: `EndSessionSheet.swift` - workout summary, feeling rating, progression notes
- **Haptic/sound feedback**: `HapticManager.swift` - Timer sounds with music ducking

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

### Firestore Listener Error Handling
**Pattern:** Pass error callback to prevent silent listener failures

```swift
// FirebaseService.swift - Listener with error callback
func listenToFriendships(
    for userId: String,
    onChange: @escaping ([Friendship]) -> Void,
    onError: ((Error) -> Void)? = nil  // Optional error callback
) -> ListenerRegistration {
    return db.collection("friendships")
        .whereField("participantIds", arrayContains: userId)
        .addSnapshotListener { snapshot, error in
            if let error = error {
                Logger.error(error, context: "listenToFriendships")
                onError?(error)  // Report error to caller
                return
            }
            // Process snapshot...
        }
}

// ViewModel usage - Handle errors to update UI state
friendshipListener = firestoreService.listenToFriendships(
    for: userId,
    onChange: { [weak self] friendships in
        Task { @MainActor in
            self?.handleFriendshipsUpdate(friendships, userId: userId)
        }
    },
    onError: { [weak self] error in
        Task { @MainActor in
            Logger.error(error, context: "FriendsViewModel.loadFriendships")
            self?.error = error
            self?.isLoading = false
        }
    }
)
```

**Files using this pattern:**
- `FirebaseService.swift` - `listenToFriendships`, `listenToConversations`, `listenToMessages`
- `FriendsViewModel.swift` - Handles friendship listener errors
- `ConversationsViewModel.swift` - Handles conversation listener errors
- `ChatViewModel.swift` - Handles message listener errors

### Feed Reload on Related Data Change
**Pattern:** Reload feed when dependent data changes (e.g., new friends)

```swift
// SocialView.swift - Reload feed when friends list changes
.onChange(of: friendsViewModel.friends.count) { _, _ in
    if authService.isAuthenticated {
        feedViewModel.loadFeed()
    }
}
```

This ensures the feed includes new friends' posts immediately after accepting friend requests.

### Tab Pop-to-Root Pattern
**Pattern:** Reset NavigationStack when tapping already-selected tab
```swift
// State triggers - increment to force view identity change
@State private var homePopToRoot = 0
@State private var trainingPopToRoot = 0

// Apply .id() to views in TabView
HomeView()
    .id("home-\(homePopToRoot)")
    .tag(0)

// In tab button action
if selectedTab == tab.tag {
    popToRoot(tab: tab.tag)  // Already on this tab
} else {
    selectedTab = tab.tag     // Switch to new tab
}

private func popToRoot(tab: Int) {
    switch tab {
    case 0: homePopToRoot += 1
    case 1: trainingPopToRoot += 1
    // ...
    }
}
```

### Keyboard-Safe Button Handling in Sheets
**Pattern:** Dismiss keyboard before triggering sheet dismissal
```swift
@FocusState private var isFocused: Bool

private func startSession() {
    isFocused = false  // Dismiss keyboard first
    HapticManager.shared.impact()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        onStart()  // Now safe to dismiss sheet
    }
}

TextField("Name", text: $name)
    .focused($isFocused)
    .submitLabel(.go)
    .onSubmit { startSession() }  // Handle keyboard "Go" button
```

### Audio Playback Over Music
**Pattern:** Play notification sounds while music is playing
```swift
import AVFoundation
import AudioToolbox

// Configure audio session to duck (lower volume of) other audio
try AVAudioSession.sharedInstance().setCategory(
    .playback,
    mode: .default,
    options: [.mixWithOthers, .duckOthers]
)
try AVAudioSession.sharedInstance().setActive(true)

// Ensure session is active before each sound play
func ensureAudioSessionActive() {
    try? AVAudioSession.sharedInstance().setActive(true)
}

// Play sound using system sound (not alert sound)
ensureAudioSessionActive()
AudioServicesPlaySystemSound(soundID)  // Works even when ringer is silent
```
