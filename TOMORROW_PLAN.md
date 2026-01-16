# Tomorrow's Plan - Joy-Bringing Features & Code Quality

## Smart Features to Implement

### 1. Auto-fill Last Weight/Reps
- When starting a set, pre-populate with values from the last session
- Show "Last: 135 x 8" hint below input fields
- One-tap to use last values

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

1. **ActiveSessionView.swift (1642 lines)**
   - Extract `ExerciseCardView` to separate file
   - Extract `SupersetBanner` to separate file
   - Move helper functions to extensions

2. **HomeView.swift (1375 lines)**
   - Extract `CalendarView` component
   - Extract `ScheduleWorkoutSheet` to separate file
   - Extract `QuickStartSection` component

3. **ExerciseLibraryView.swift (1318 lines)**
   - Move `EquipmentLibraryView` to its own file
   - Extract shared filter components

### Medium Priority

4. **SessionComponents.swift (1115 lines)**
   - Consider splitting input views by exercise type
   - Extract timer logic to separate utility

5. **EndSessionSheet.swift (636 lines)**
   - Extract `ExerciseCard` subview
   - Extract progression UI to reusable component

---

## Quick Wins for Tonight
- [x] Progression feature complete
- [x] Exercise notes added
- [x] Mobility tracking fixed
- [ ] Code review for obvious issues

---

## Technical Debt Notes
- Some files have grown organically - consider splitting when touching them
- CoreData schema is programmatic (good!) but getting large
- Consider creating a `SessionInputViews.swift` for exercise-type-specific inputs
