# Tomorrow's Plan - Joy-Bringing Features & Code Quality

## Smart Features to Implement

### 1. Auto-fill Last Weight/Reps
- [x] When starting a set, pre-populate with values from the last session
- [x] Priority: last session values > target values > empty
- [x] One-tap "same as last" button to copy previous completed set
- [x] Band color auto-suggested from last session

### 2. Progressive Overload Suggestions
- After completing a set, suggest next progression
- "Nice! Try 140 lbs next time?" badge
- Based on RPE and completion rate

### 3. Plate Calculator
- Show which plates to load for target weight
- Account for bar weight (45 lbs default, configurable)
- Visual plate diagram

### 4. Rest Timer Auto-Start
- Automatically start rest countdown when set is logged
- Configurable in settings (on/off, default rest time)
- Haptic when rest is complete

### 5. Personal Records Detection
- Detect when user hits a new PR (weight, reps, volume)
- Celebration animation + haptic
- PR history view

---

## Code Modularization Opportunities

### High Priority (Large Files)

1. **ActiveSessionView.swift (~1700 lines)**
   - Extract `ExerciseCardView` to separate file
   - Extract `SupersetBanner` to separate file
   - Move helper functions to extensions

2. **HomeView.swift (~800 lines)**
   - Extract `CalendarView` component
   - Extract `ScheduleWorkoutSheet` to separate file
   - Extract `QuickStartSection` component

3. **ExerciseLibraryView.swift (~1300 lines)**
   - Move `EquipmentLibraryView` to its own file
   - Extract shared filter components

### Medium Priority

4. **SessionComponents.swift (~1200 lines)**
   - Consider splitting input views by exercise type
   - Extract timer logic to separate utility

5. **EndSessionSheet.swift (~636 lines)**
   - Extract `ExerciseCard` subview
   - Extract progression UI to reusable component

---

## Recently Completed (Jan 2025)

### Bug Fixes
- [x] SetRowView layout stability - use `.fixedSize()` to prevent text compression
- [x] Distance unit selector vertical text - fixed with minWidth
- [x] Force unwrapping crashes - HomeView Calendar.date(), ActiveSessionView URL()
- [x] Silent Firebase decode failures - now tracked in `decodeFailures` array
- [x] Module exercise propagation - refresh modules before starting workout

### UX Improvements
- [x] Auto-suggest from last session (weight, reps, duration, distance, band color, height)
- [x] Compact input sections for all exercise types
- [x] Session pagination - only load last 90 days initially

### Performance
- [x] Session pagination in DataRepository (reduces memory usage)
- [x] `loadMoreSessions()` for on-demand historical loading
- [x] `getExerciseHistory()` queries CoreData directly for full history

---

## Technical Debt Notes
- Some files have grown organically - consider splitting when touching them
- CoreData schema is programmatic (good!) but getting large
- Consider creating a `SessionInputViews.swift` for exercise-type-specific inputs
