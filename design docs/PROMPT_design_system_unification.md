# Design System Unification — Phase 1: Foundation + Color + Tab Restructure

## Context
The app has been built iteratively across multiple phases. Each main tab (Home, Training Hub, Social) was developed at different times and they've drifted into different visual languages — different accent colors, different card treatments, different header patterns, different button styles. The goal of this task is to unify everything into one cohesive design system and restructure the tab bar.

**This is a visual/structural refactor. No new features. No data model changes. No new ViewModels.**

---

## TASK 1: Color System Cleanup

### Files to modify:
- `gym app/Theme/AppColors.swift`
- `gym app/Theme/AppGradients.swift`

### Current problem:
- `accent4` (hot pink `#FF6B9D`) is used as `programAccent` and bleeds into Training Hub headers, creating a warm/neon feel that clashes with the cool cyan used everywhere else
- The app has 5 accent colors + dominant + reward + semantic colors = too many competing colors
- Pink and cyan are fighting each other across tabs

### Changes to AppColors.swift:

**Remove `accent4` (hot pink) as a primary UI color.** Programs should use `dominant` (cyan) like everything else. Keep `accent4` defined but ONLY for module type color mapping (if a module type currently uses it), not for program-level UI.

**Update `programAccent`:**
```swift
// BEFORE
static let programAccent = accent4  // Hot pink

// AFTER  
static let programAccent = dominant  // Programs use the same dominant cyan as everything else
```

**Rename for clarity (optional but helpful):**
```swift
// Accent colors — used ONLY for module type differentiation, not UI chrome
static let moduleWarmup = Color(hex: "FF5757")     // was accent5
static let modulePrehab = Color(hex: "00E5CC")     // was accent1
static let moduleExplosive = Color(hex: "FFB800")   // was accent2
static let moduleStrength = dominant                 // was dominant
static let moduleCardio = Color(hex: "7B61FF")      // was accent3
```

Keep the old `accent1`–`accent5` names as typealiases if needed for backward compatibility, but the intent should be clear: these colors are for module type badges/pills ONLY, not for section headers, card borders, or UI chrome.

### Changes to AppGradients.swift:

**Replace `programGradient`** — it currently uses hot pink. Replace with a dominant-based gradient:
```swift
// BEFORE
static let programGradient = LinearGradient(
    colors: [AppColors.programAccent, AppColors.programAccent.opacity(0.7), Color(hex: "C44569")],
    ...
)

// AFTER
static let programGradient = LinearGradient(
    colors: [AppColors.dominant.opacity(0.4), AppColors.dominant.opacity(0.15)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### The unified color hierarchy after this change:
```
Dominant (cyan #00D9FF):  Active states, selected tabs, interactive elements, primary highlights
Gold (amber #FFB800):    PRs, streaks, celebrations, achievement moments, primary CTA buttons  
Green (#00E676):         Success states, completed items, checkmarks
Red (#FF5252):           Errors, destructive actions, delete
Purple (#7B61FF):        Cardio module type ONLY (not UI chrome)
```

**Everything else (headers, card borders, section labels, buttons) should use `dominant`, `textPrimary`, `textSecondary`, `textTertiary`, or `surfaceTertiary`. No pink. No random accent colors in UI chrome.**

---

## TASK 2: Unified Card Component

### Files to modify:
- `gym app/Theme/Components.swift`

### Current problem:
Cards across the app use different border colors (some use module accent colors for borders, some use `surfaceTertiary`, some use no border), different corner radii (`AppCorners.large` vs `AppCorners.medium`), and different background treatments (some use gradients, some use flat fills).

### Create/update a `UnifiedCard` ViewModifier:

```swift
struct UnifiedCardStyle: ViewModifier {
    var accentColor: Color? = nil  // Optional subtle accent tint (for module cards, etc.)
    
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
            )
    }
}

extension View {
    func unifiedCard(accent: Color? = nil) -> some View {
        self.modifier(UnifiedCardStyle(accentColor: accent))
    }
}
```

### Update existing card components to use unified style:

**`ModuleCard`** — currently uses `AppColors.moduleColor(module.type).opacity(0.2)` for its border stroke. Change to the unified neutral stroke. The module color should ONLY appear on the icon circle and the type label text, NOT on the card border.

**`WorkoutCard`** — currently uses `AppGradients.subtleGradient` background + `surfaceTertiary.opacity(0.5)` stroke. Change to unified card style (flat `surfacePrimary` fill + same neutral stroke).

**`StatCard`** — currently uses `AppCorners.medium`. Change to `AppCorners.large` to match everything else.

### The rule going forward:
Every card in the app uses the same background, corner radius, and border. The CONTENT inside the card provides visual differentiation (icon colors, text colors, badges), NOT the card container itself.

---

## TASK 3: Section Header Standardization

### Files to modify:
- `gym app/Theme/Components.swift` (the existing `SectionHeader` component)
- All views that create ad-hoc section headers

### Current problem:
- Home uses white bold `.title3` headers ("Week in Review")
- Training Hub uses pink/magenta uppercase labels ("ACTIVE PROGRAM")  
- Some places use `.caption2` uppercase, others use `.headline`

### The ONE section header pattern:

The existing `SectionHeader` in Components.swift is already close to correct. Ensure it looks like this:

```swift
struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "See All"

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.subheadline)
                        .foregroundColor(AppColors.dominant)
                }
            }
        }
    }
}
```

**Then search the entire codebase for ad-hoc section headers** that don't use this component. Common patterns to find and replace:
- Any `Text("SOMETHING").font(.caption2)` used as a section title with pink/magenta/accent coloring
- Any uppercase section labels colored with `programAccent` or `accent4`
- Any section header that uses a color other than `textPrimary` for the title

Replace all of them with `SectionHeader(title: "Whatever")`.

---

## TASK 4: Tab Bar Restructure (5 tabs → 4 tabs)

### Files to modify:
- `gym app/Views/MainTabView.swift`
- `gym app/Views/More/MoreView.swift` (will be deleted or gutted)
- `gym app/Views/HomeView.swift` (minor — add History access)

### Current 5-tab structure:
```
Home | Workout | Social | Analytics | More
```

### New 4-tab structure:
```
Home | Training | Social | Analytics
```

### What happens to "More" contents:
The More tab currently contains: History, Settings, Exercise Library, Equipment Library.

**Redistribute:**
- **History** → Move to Home tab. Add a `NavigationLink` to `HistoryView()` accessible from Home (clock icon in the nav bar top-right, or a "History" row in Home's scroll content).
- **Settings** → Move to a gear icon button in Home's navigation bar (top-right). Tapping it pushes `SettingsView()`.
- **Exercise Library** and **Equipment Library** → These are already accessible from within Settings. If they aren't, add NavigationLinks to them inside SettingsView. They do NOT need their own top-level entry point.

### Changes to MainTabView.swift:

```swift
// Remove the MoreView tab entirely
// Rename "Workout" label to "Training"
// Update tabCount from 5 to 4

TabView(selection: $selectedTab) {
    HomeView()
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
        .tag(0)

    WorkoutBuilderView()  // Keep the same view, just rename the tab label
        .tabItem {
            Label("Training", systemImage: "dumbbell.fill")
        }
        .tag(1)

    SocialView()
        .tabItem {
            Label("Social", systemImage: "person.2.fill")
        }
        .tag(2)

    AnalyticsView()
        .tabItem {
            Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
        }
        .tag(3)
}
```

Update `tabCount` to 4.

---

## TASK 5: Kill Pink Throughout the Codebase

### Files to search: ENTIRE `gym app/` directory

This is the most important sweep. Search for ALL usages of:
- `AppColors.accent4`
- `AppColors.programAccent` (after the change in Task 1, this is now cyan, but check all usages are appropriate)  
- `Color(hex: "FF6B9D")` (the raw hot pink hex)
- `Color(hex: "C44569")` (the darker pink from programGradient)
- `AppGradients.programGradient` (now updated, but verify all call sites look right)
- Any hardcoded pink/magenta hex values

For each usage found:
- If it's a **section header or label color** → replace with `AppColors.textPrimary` or `AppColors.dominant`
- If it's a **card border/stroke** → replace with `AppColors.surfaceTertiary.opacity(0.5)`
- If it's an **icon background** → replace with `AppColors.dominant.opacity(0.15)` or the appropriate module color
- If it's a **button or CTA** → replace with `AppColors.dominant` or `AppColors.accent2` (gold) for primary actions
- If it's specifically `moduleColor()` mapping for a module type → that's fine, leave it (but verify it's actually needed)

### Key files that likely have pink contamination:
- `gym app/Views/Programs/ProgramsListView.swift` — program list headers
- `gym app/Views/Programs/ProgramDetailView.swift` — program detail headers  
- `gym app/Views/Programs/ProgramFormView.swift` — form accents
- `gym app/Views/WorkoutBuilder/WorkoutBuilderView.swift` — Training Hub headers, Quick Create buttons
- `gym app/Views/HomeView.swift` — may reference programAccent for active program display

---

## TASK 6: Unify Header Patterns Across Tabs

### Files to modify:
- `gym app/Views/HomeView.swift`
- `gym app/Views/WorkoutBuilder/WorkoutBuilderView.swift`  
- `gym app/Views/Social/SocialView.swift`
- `gym app/Views/Analytics/AnalyticsView.swift`

### Current problem:
- Home: custom header with teal date label, no NavigationStack title
- Training Hub: custom header with pink "TRAINING HUB" label
- Social: standard NavigationStack with centered "Feed" title
- Analytics: unknown/may differ

### Target: Every tab uses the same header structure

Use a consistent pattern — either all use `NavigationStack` with `.navigationTitle()` and `.navigationBarTitleDisplayMode(.large)`, OR all use a custom header. 

**Recommended: Custom inline headers** (more control, matches current Home style which is the most polished):

```swift
// Top of each tab's ScrollView content:
HStack {
    Text("Home")  // or "Training", "Feed", "Analytics"
        .font(.title.bold())
        .foregroundColor(AppColors.textPrimary)
    
    Spacer()
    
    // Right-side contextual items (streak badge, settings gear, search icon, etc.)
}
.padding(.horizontal, AppSpacing.screenHorizontal)
```

If tabs currently use `NavigationStack` with `.navigationTitle()`, convert them to this custom pattern. Each tab should still be wrapped in `NavigationStack` for push navigation, but use `.navigationBarHidden(true)` and render the custom header manually.

**Contextual subtitle (optional per tab):**
```swift
// Below the main title, only if contextually useful:
Text("SUNDAY, FEB 1")  // Home only — shows today's date
    .font(.caption.weight(.semibold))
    .foregroundColor(AppColors.dominant)
    .kerning(1.0)
```

Only Home needs the date subtitle. Training, Feed, and Analytics don't need subtitles.

---

## Verification Checklist

After all changes, verify:

- [ ] No pink/magenta visible anywhere in the app
- [ ] All cards use the same background (`surfacePrimary`), corner radius (`AppCorners.large`), and border stroke (`surfaceTertiary.opacity(0.5)`)
- [ ] All section headers use `SectionHeader` component or match its styling exactly
- [ ] Tab bar shows 4 tabs: Home, Training, Social, Analytics
- [ ] History and Settings are accessible from Home tab
- [ ] All tab headers follow the same left-aligned bold title pattern
- [ ] Module type colors (warmup red, prehab teal, explosive gold, strength cyan, cardio purple) still work correctly in module pills, module cards, and session views
- [ ] Program-related UI uses cyan/dominant instead of pink
- [ ] No build errors or broken navigation paths
- [ ] The app compiles and all existing navigation flows still work

---

## What NOT to change

- **Data models** — no CoreData or model changes
- **ViewModels** — no logic changes
- **Session/workout tracking** — don't touch ActiveSessionView internals
- **Social features** — don't restructure feed, messaging, or friend systems
- **Module type color mapping** — the function `moduleColor(_ type:)` should still return distinct colors per module type for differentiation. Just make sure those colors aren't bleeding into UI chrome.
- **Any feature behavior** — this is purely visual/structural

---

## Priority if this is too large for one pass

If you need to break this up:
1. **Task 1 + Task 5** (color cleanup) — highest impact, kills the disjointed feeling
2. **Task 2 + Task 3** (card + header unification) — establishes consistency
3. **Task 4** (tab restructure) — structural change, can be done independently
4. **Task 6** (header pattern) — polish pass
