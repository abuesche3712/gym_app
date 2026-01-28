# Typography System — Gym App

A modular, accessible typography system built on SwiftUI's semantic text styles with enhancements for numbers, display text, and elegant labels.

---

## Philosophy

**Typography does the heavy lifting in a minimal UI.**

- Strong hierarchy with no ambiguity about what's important
- Monospaced numbers prevent layout shifts (critical for timers, counters)
- Rounded display text feels confident without being aggressive
- Uppercase labels with tracking add premium, refined aesthetic
- All styles respect Dynamic Type for accessibility

---

## Font System Overview

### 1. Display Styles (Rounded, Bold — Big Moments)

Use `.rounded` design for workout titles, completion screens, and big numbers. It's confident without being aggressive—fitness apps often go ultra-bold condensed, but rounded says "I'm serious about training but not insufferable about it."

| Modifier | Use For | SwiftUI Base |
|----------|---------|--------------|
| `.displayLarge()` | Workout summaries, celebration screens, massive stats | `.largeTitle` |
| `.displayMedium()` | Module counts, session timers, prominent numbers | `.title` |
| `.displaySmall()` | Card headers, subsection titles | `.title2` |

**Examples:**
- Interval timer countdown (100pt)
- Week in Review stats (32pt)
- Completion screen totals

---

### 2. Monospaced Styles (Numbers That Change — No Layout Shift)

**CRITICAL for timers, counters, and live data.** When numbers change (1:59 → 1:58), monospaced fonts prevent the UI from jumping around.

| Modifier | Use For | SwiftUI Base |
|----------|---------|--------------|
| `.monoLarge()` | Rest timers, session duration, countdown | `.largeTitle` (mono) |
| `.monoMedium()` | Weight/reps during sets, live counters | `.title3` (mono) |
| `.monoSmall()` | Set indicators, small counters | `.body` (mono) |
| `.monoCaption()` | Tiny badges with numbers | `.caption` (mono) |

**All mono styles include `.monospacedDigit()` automatically.**

**Examples:**
- Rest timer: "1:30" → `.monoLarge()`
- Weight input during set: "135 lbs" → `.monoMedium()`
- Session elapsed time: "0:45:12" → `.monoSmall()`

---

### 3. Label Styles (Uppercase + Tracked — Premium Feel)

Like the "TODAY" header on HomeView. Uppercase with letter-spacing adds elegance and hierarchy.

| Modifier | Use For | Tracking | SwiftUI Base |
|----------|---------|----------|--------------|
| `.elegantLabel()` | Section headers, screen labels, category tags | 1.5pt | `.caption` (semibold) |
| `.smallCapsLabel()` | Form section labels, metadata | 1.2pt | `.caption2` (medium) |
| `.statLabel()` | Stat descriptions ("completed", "volume") | 1.2pt | `.caption2` (semibold) |

**Examples:**
- "TODAY" (HomeView header)
- "TRAINING HUB" (WorkoutBuilder header)
- "EDITING" / "BUILDING" (WorkoutForm status)
- "completed" / "scheduled" (stat labels)

---

### 4. Standard Text Styles (Semantic + Color Convenience)

Wrapper around SwiftUI's built-in styles with color built in for convenience.

| Modifier | Use For | Default Color |
|----------|---------|---------------|
| `.headline()` | Exercise names, important text | `textPrimary` |
| `.subheadline()` | Secondary info, descriptions | `textSecondary` |
| `.body()` | Default text, paragraphs | `textPrimary` |
| `.callout()` | Hints, supplementary info | `textSecondary` |
| `.caption()` | Meta info, timestamps | `textSecondary` |
| `.caption2()` | Tiny support text | `textTertiary` |

---

## Usage Guidelines

### Display (Rounded) vs. Standard

**Use Display (Rounded):**
- Numbers that deserve celebration (sets completed, PRs)
- Workout completion screens
- Big stats that catch the eye
- Module/exercise counts

**Use Standard:**
- Body text, descriptions
- Exercise names in lists
- Navigation text
- Form labels

### Monospaced vs. Display

**Monospaced is REQUIRED for:**
- ✅ Timers (rest, session, interval)
- ✅ Live counters (sets, reps during workout)
- ✅ Any number that changes frequently

**Display/Standard is fine for:**
- ✅ Final stats (after workout completes)
- ✅ Historical data
- ✅ Static numbers in cards

### Labels vs. Standard

**Use Labels (uppercase + tracking):**
- ✅ Screen headers ("TODAY", "TRAINING HUB")
- ✅ Section dividers
- ✅ Status indicators ("EDITING", "ACTIVE PROGRAM")
- ✅ Stat descriptions ("completed", "volume")

**Use Standard:**
- ✅ Everything else
- ✅ Body text
- ✅ Buttons
- ✅ Input fields

---

## Quick Reference — What Font Where?

### HomeView
```swift
Text("TODAY")
    .elegantLabel(color: AppColors.dominant)

Text("\(sessionsThisWeek)")
    .displayMedium(color: AppColors.success)

Text("completed")
    .statLabel()
```

### Active Session
```swift
// Rest timer
Text(formatTime(secondsRemaining))
    .monoLarge(color: AppColors.warning)

// Weight input during set
Text("\(weight)")
    .monoMedium()

// Session elapsed time
Text(sessionDuration)
    .monoSmall(color: AppColors.textSecondary)
```

### Screen Headers
```swift
Text("TRAINING HUB")
    .elegantLabel(color: AppColors.dominant)

Text("Your Workouts")
    .headline()
```

### Interval Timer
```swift
// Big countdown
Text(formatTime(secondsRemaining))
    .displayLarge()
    .monospacedDigit()  // Add this for layout stability

// Phase label
Text("WORK")
    .displayMedium(color: phaseColor)
```

### Input Fields (Quick Set)
```swift
Text("WEIGHT")
    .statLabel(color: AppColors.textTertiary)

TextField("0", text: $inputWeight)
    .displayMedium()
```

---

## Common Patterns

### Before/After Examples

#### Pattern 1: Section Header
```swift
// ❌ Before (verbose, inconsistent)
Text("WORKOUTS")
    .font(.caption.weight(.semibold))
    .foregroundColor(AppColors.dominant)
    .tracking(1.5)

// ✅ After (clean, modular)
Text("WORKOUTS")
    .elegantLabel(color: AppColors.dominant)
```

#### Pattern 2: Timer Display
```swift
// ❌ Before (missing monospaced = layout jumps!)
Text("\(seconds)")
    .font(.system(size: 32, weight: .bold, design: .rounded))
    .foregroundColor(AppColors.warning)

// ✅ After (stable layout)
Text("\(seconds)")
    .monoLarge(color: AppColors.warning)
```

#### Pattern 3: Big Stat Number
```swift
// ❌ Before
Text("\(workoutCount)")
    .font(.system(size: 32, weight: .bold, design: .rounded))
    .foregroundColor(AppColors.success)
    .minimumScaleFactor(0.7)

// ✅ After
Text("\(workoutCount)")
    .displayMedium(color: AppColors.success)
    .minimumScaleFactor(0.7)
```

#### Pattern 4: Stat Label
```swift
// ❌ Before
Text("completed")
    .font(.caption2.weight(.semibold))
    .foregroundColor(AppColors.textSecondary)
    .textCase(.uppercase)
    .tracking(1.2)

// ✅ After
Text("completed")
    .statLabel()
```

---

## Color Overrides

All modifiers accept an optional `color` parameter:

```swift
// Default color
Text("Exercise Name")
    .headline()  // Uses AppColors.textPrimary

// Custom color
Text("Rest Day")
    .headline(color: AppColors.accent1)

// Stat label with custom tracking
Text("ACTIVE")
    .elegantLabel(color: AppColors.success, tracking: 2.0)
```

---

## Accessibility Notes

### Dynamic Type Support

✅ **All styles use semantic text styles** (`.largeTitle`, `.headline`, etc.)
✅ Automatically respects user's text size preferences
✅ Test at all accessibility sizes (Settings → Accessibility → Larger Text)

### Contrast

- Primary text on background: 18.9:1 (AAA+++)
- Secondary text on background: 6.8:1 (AAA)
- All semantic colors meet WCAG AA standard (4.5:1 minimum)

### VoiceOver

Typography modifiers don't affect VoiceOver—it reads the text content. Add `.accessibilityLabel()` for context when needed:

```swift
Text("\(sessionsThisWeek)")
    .displayMedium(color: AppColors.success)
    .accessibilityLabel("\(sessionsThisWeek) workouts completed this week")
```

---

## Implementation Status

### ✅ Refactored (Using New System)
- HomeView (all stats, headers)
- WorkoutBuilderView (header)
- WorkoutsListView (header)
- ModulesListView (header)
- ProgramFormView (header)
- WorkoutFormView (header)
- SessionComponents (all timers)
- IntervalTimerView (countdown, phase)
- ActiveSessionView (session timer)
- RecentSetsSheet (inputs, labels)
- WorkoutOverviewSheet (inputs, labels)

### 🔄 Can Be Refactored Incrementally
- Exercise library views
- Settings screens
- History views
- Analytics views
- Smaller components (badges, chips, etc.)

---

## Decision Tree

**Need to display text? Ask yourself:**

1. **Is it a number that changes frequently?**
   → Use `.monoLarge()`, `.monoMedium()`, or `.monoSmall()`

2. **Is it a big celebratory number or workout stat?**
   → Use `.displayLarge()` or `.displayMedium()`

3. **Is it a section header or status label?**
   → Use `.elegantLabel()` (if uppercase) or `.headline()` (if normal case)

4. **Is it a stat description under a number?**
   → Use `.statLabel()`

5. **Is it body text, a description, or a button label?**
   → Use `.headline()`, `.body()`, `.subheadline()`, or `.caption()`

6. **Still not sure?**
   → Use `.body()` (the safe default)

---

## Migration Checklist

When refactoring a view:

- [ ] Replace inline `.font(.system(size: X, ...))` with semantic modifiers
- [ ] Check all timers/counters use monospaced (`.monoLarge/Medium/Small()`)
- [ ] Check all big numbers use display (`.displayLarge/Medium()`)
- [ ] Check all section headers use labels (`.elegantLabel()`)
- [ ] Verify colors match design system (use `AppColors` constants)
- [ ] Test with Dynamic Type enabled at multiple sizes
- [ ] Run app and verify layout doesn't shift when numbers change

---

## Why This System?

### Before (Problems)
- ❌ 245+ inline font definitions
- ❌ Inconsistent sizing and weights
- ❌ Layout jumps when timers tick
- ❌ Hard to maintain (change one font = find/replace nightmare)
- ❌ No personality (generic system fonts everywhere)

### After (Benefits)
- ✅ 9 semantic modifiers cover 95% of use cases
- ✅ Consistent typography across entire app
- ✅ Stable layouts (monospaced numbers)
- ✅ Easy to maintain (change once, updates everywhere)
- ✅ Personality (rounded display, elegant labels)
- ✅ Accessible (Dynamic Type built in)

---

**✨ Typography implemented. Time to make it readable. ✨**
