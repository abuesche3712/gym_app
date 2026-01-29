# SwiftUI Design System — Hybrid Athlete Fitness Tracker

A design philosophy and implementation guide for creating a distinctive, joy-inducing iOS experience that doesn't look like every other fitness app.

> **See also:**
> - [TYPOGRAPHY.md](./TYPOGRAPHY.md) — Complete typography system with semantic modifiers
> - [COLOR_PALETTE.md](./COLOR_PALETTE.md) — Full color system with usage guidelines

---

## Design Philosophy

### Core Principles

1. **Workout-First UX**: Every design decision should be evaluated against "can I use this mid-set with sweaty hands and elevated heart rate?" If it requires precision tapping or cognitive load, it fails.

2. **Intentional Minimalism**: Not minimal because lazy — minimal because every element earns its place. The absence of clutter IS the feature.

3. **Data Without Overwhelm**: You're tracking complex modular workouts (1x3 + 3x6 schemes, supersets, etc.). The UI should make complexity feel simple, not hide it.

4. **Personality Through Restraint**: Greyscale + cool accents isn't boring — it's confident. Let the user's data and progress be the color.

---

## Color System

> **Full implementation:** See [COLOR_PALETTE.md](./COLOR_PALETTE.md) for complete color definitions and usage guidelines.

### Philosophy
Dominant neutrals with surgical accent deployment. Accents should feel like rewards, not decorations.

### Current Palette (Implemented)

```swift
// Access via AppColors in Theme/AppTheme.swift
AppColors.background        // Near-black base (#0D0D0F)
AppColors.surfacePrimary    // Cards (#151518)
AppColors.surfaceTertiary   // Borders (#2A2A2E)

AppColors.textPrimary       // High emphasis (#FAFAFA)
AppColors.textSecondary     // Medium emphasis (#A1A1AA)
AppColors.textTertiary      // Low emphasis (#5A5A62)

// Accent Colors (Multiple for visual variety)
AppColors.dominant          // Cyan (#00D4E8) - Primary actions, active states
AppColors.accent1           // Purple (#A78BFA) - Modules, secondary UI
AppColors.accent2           // Rose (#F472B6) - Social features
AppColors.accent3           // Teal (#2DD4BF) - Tertiary accent
AppColors.programAccent     // Amber (#F59E0B) - Programs, scheduling

// Semantic
AppColors.success           // Green (#22C55E) - Completion, PRs
AppColors.warning           // Amber (#F59E0B) - Urgent states
AppColors.error             // Red (#EF4444) - Destructive actions
```

### Usage Rules

| Context | Color |
|---------|-------|
| Active/current exercise | `dominant` |
| Completed sets | `success` checkmark or `textSecondary` |
| Upcoming sets | `textTertiary` |
| Interactive elements (buttons, toggles) | `dominant` |
| Module-related UI | `accent1` or `moduleColor(type)` |
| Program/schedule UI | `programAccent` |
| Destructive actions | `error` (require confirmation) |
| PR indicators | `success` + animation |
| Rest timer (urgent <10s) | `warning` pulse |

### Anti-Patterns
- ❌ Don't use accent color for everything — it loses meaning
- ❌ Don't use pure black (`#000000`) — too harsh, no depth
- ❌ Don't use pure white (`#FFFFFF`) for text — `#FAFAFA` is softer
- ❌ Don't gradient the accent unless it's a celebration moment (PR)

---

## Typography

> **Full implementation:** See [TYPOGRAPHY.md](./TYPOGRAPHY.md) for complete typography system, modifiers, and usage examples.

### Philosophy
Typography does the heavy lifting in a minimal UI. Strong hierarchy, no ambiguity about what's important.

### Semantic Modifiers (Implemented)

All typography now uses semantic View modifiers instead of inline font definitions:

```swift
// Display (Rounded, bold — celebration moments, big stats)
Text("5").displayLarge()           // Workout summaries, massive stats
Text("12").displayMedium()         // Module counts, prominent numbers

// Monospaced (Numbers that change — prevents layout shift)
Text("1:30").monoLarge()           // Rest timers, countdowns
Text("135").monoMedium()           // Weight/reps during sets

// Labels (Uppercase + tracking — elegant headers)
Text("TODAY").elegantLabel(color: AppColors.dominant)
Text("completed").statLabel()      // Stat descriptions

// Standard (Semantic SwiftUI styles with color)
Text("Bench Press").headline()
Text("3 sets remaining").subheadline()
Text("Last performed 2 days ago").caption()
```

### Usage Patterns

| Element | Modifier | Color Override |
|---------|----------|----------------|
| Current weight/reps | `.monoMedium()` | — |
| Exercise name | `.headline()` | — |
| Section headers | `.elegantLabel()` | `AppColors.dominant` |
| Rest timer | `.monoLarge()` | `AppColors.warning` when < 10s |
| Stat labels | `.statLabel()` | — |
| Completed set data | `.monoMedium()` | `AppColors.textSecondary` |

### Why `.rounded` for Display?
It's confident without being aggressive. Fitness apps often go ultra-bold condensed — that screams "GAINS BRO." Rounded says "I'm serious about training but I'm not insufferable about it."

### Why Monospaced for Numbers?
Numbers changing (timer counting, weight incrementing) shouldn't cause layout shifts. Mono keeps everything stable.

### Numeric Input Fields
Weight/rep/timer input fields use `.design: .rounded` for visual consistency with the display aesthetic. These are preserved as inline definitions since they're specialized UI.

---

## Spacing & Layout

### Spacing Scale

```swift
extension CGFloat {
    static let space2: CGFloat = 2
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space48: CGFloat = 48
    static let space64: CGFloat = 64
}
```

### Layout Principles

1. **Generous Touch Targets**: Minimum 44pt for anything tappable. During a workout, make primary actions 56pt+.

2. **Breathing Room**: Don't cram. `space16` minimum padding on cards. `space24` between major sections.

3. **Visual Grouping**: Related items close together (`space8`), unrelated items far apart (`space24`+). Gestalt principles — proximity implies relationship.

4. **Edge-to-Edge When It Matters**: Cards can bleed to edges on smaller content. But primary workout controls get centered with margins.

### Card Pattern

```swift
struct WorkoutCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .space12) {
            // Content
        }
        .padding(.space16)
        .background(Color.surfacePrimary)
        .cornerRadius(12)
    }
}
```

### Safe Area Respect
Always use `.safeAreaInset` for bottom action buttons. Don't fight the notch/home indicator — embrace it.

---

## Motion & Animation

### Philosophy
Animation should provide feedback and delight, not delay. If an animation makes the app feel slower, cut it.

### Timing Standards

```swift
extension Animation {
    // MARK: - Micro (Feedback)
    static let micro = Animation.easeOut(duration: 0.15)
    
    // MARK: - Standard (State changes)
    static let standard = Animation.easeInOut(duration: 0.25)
    
    // MARK: - Emphasis (Celebrations, attention)
    static let emphasis = Animation.spring(response: 0.4, dampingFraction: 0.7)
    
    // MARK: - Smooth (Sheet presentations, large moves)
    static let smooth = Animation.easeInOut(duration: 0.35)
}
```

### When to Animate

| Action | Animation | Why |
|--------|-----------|-----|
| Set completed | `.emphasis` + checkmark scale | Reward! Dopamine hit. |
| Rest timer tick | None | Don't distract |
| Rest timer < 10s | Pulse on `warning` | Attention without panic |
| PR achieved | `.emphasis` + confetti/glow | CELEBRATE THIS |
| Navigation push | Default SwiftUI | Don't reinvent |
| Button press | `.micro` scale to 0.97 | Tactile feedback |
| Delete swipe | `.standard` | Smooth but not slow |

### Anti-Patterns
- ❌ Don't animate every state change — it becomes noise
- ❌ Don't use `linear` timing — feels robotic
- ❌ Don't exceed 0.4s for common interactions — feels sluggish
- ❌ Don't animate during active set logging — get out of the way

### Haptics Pairing

```swift
extension UIImpactFeedbackGenerator {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
```

Use haptics WITH animation for:
- Set completion (`.success`)
- Weight/rep increment (`.light`)
- PR notification (`.success` + delay + `.medium`)

---

## Component Patterns

### Primary Action Button

```swift
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headlineSmall)
                .foregroundColor(.background)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accent)
                .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.micro, value: configuration.isPressed)
    }
}
```

### Set Row (During Workout)

```swift
struct SetRow: View {
    let setNumber: Int
    let targetReps: Int
    let weight: Double
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: .space16) {
            // Set indicator
            Circle()
                .fill(isCurrent ? Color.accent : (isCompleted ? Color.textTertiary : Color.surfaceTertiary))
                .frame(width: 8, height: 8)
            
            // Set number
            Text("Set \(setNumber)")
                .font(.bodyMedium)
                .foregroundColor(isCurrent ? .textPrimary : .textSecondary)
            
            Spacer()
            
            // Weight x Reps
            HStack(spacing: .space4) {
                Text("\(weight, specifier: "%.1f")")
                    .font(.monoMedium)
                Text("×")
                    .font(.bodySmall)
                    .foregroundColor(.textTertiary)
                Text("\(targetReps)")
                    .font(.monoMedium)
            }
            .foregroundColor(isCurrent ? .textPrimary : .textSecondary)
            
            // Completion indicator
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.labelLarge)
                    .foregroundColor(.success)
            }
        }
        .padding(.vertical, .space12)
        .padding(.horizontal, .space16)
        .background(isCurrent ? Color.accentSubtle : Color.clear)
        .cornerRadius(8)
    }
}
```

### Rest Timer

```swift
struct RestTimer: View {
    let remainingSeconds: Int
    let totalSeconds: Int
    
    private var isUrgent: Bool { remainingSeconds <= 10 }
    private var progress: Double { Double(remainingSeconds) / Double(totalSeconds) }
    
    var body: some View {
        VStack(spacing: .space8) {
            Text(formatTime(remainingSeconds))
                .font(.monoLarge)
                .foregroundColor(isUrgent ? .warning : .textPrimary)
                .scaleEffect(isUrgent ? 1.05 : 1.0)
                .animation(.emphasis, value: isUrgent)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.surfaceTertiary)
                    Rectangle()
                        .fill(isUrgent ? Color.warning : Color.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
```

---

## Iconography

### Philosophy
Icons support, they don't lead. Use SF Symbols for consistency and accessibility.

### Weight Standards
- Navigation/tab bars: `.medium`
- Inline with text: `.regular`
- Primary actions: `.semibold`

### Sizing
- Tab bar: 24pt
- Inline: Match text line height
- Standalone buttons: 20-24pt

### Custom vs SF Symbols
Stick with SF Symbols unless you have a VERY good reason. They're:
- Automatically accessible
- Adapt to Dynamic Type
- Consistent with iOS
- Support symbol effects in iOS 17+

If you need custom icons (maybe for exercise types?), ensure they match SF Symbol stroke weights.

---

## Dark Mode (It's the Only Mode)

This app is dark mode native. No light mode variant needed for v1.

### Why?
1. Gym lighting varies wildly — dark UI adapts better
2. OLED battery savings (lots of true black)
3. Reduces eye strain during early AM/late PM sessions
4. Looks more premium

### If You Add Light Mode Later
- Don't just invert — redesign surfaces
- `surfacePrimary` becomes off-white, not pure white
- Accent color may need saturation adjustment
- Test in direct sunlight

---

## Accessibility

### Non-Negotiables

1. **Dynamic Type Support**: Use SwiftUI's built-in scaling. Test at accessibility sizes.

```swift
// Good
Text("Weight").font(.bodyMedium)

// Bad
Text("Weight").font(.system(size: 15))
```

2. **Minimum Contrast**: 4.5:1 for body text, 3:1 for large text. Your greys are already designed for this.

3. **Touch Targets**: 44pt minimum. During workout, 56pt for primary actions.

4. **VoiceOver Labels**: Every interactive element needs a label.

```swift
Button(action: completeSet) {
    Image(systemName: "checkmark.circle.fill")
}
.accessibilityLabel("Complete set")
.accessibilityHint("Marks current set as finished")
```

5. **Reduce Motion**: Respect the setting.

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

.animation(reduceMotion ? nil : .emphasis, value: isCompleted)
```

---

## What Makes This UNFORGETTABLE?

Every design system needs a "signature" — the thing that makes people recognize your app instantly.

### Candidates for Your App:

1. **The Set Completion Moment**: That micro-celebration when you log a set. Subtle but satisfying. Could be a custom animation, a particular haptic pattern, a sound.

2. **The PR Notification**: When someone hits a personal record, this should feel SPECIAL. More than just green text. Think: subtle screen glow, custom animation, maybe even a screenshot-worthy moment.

3. **The Rest Timer Tension**: The countdown creates natural drama. The transition from calm → urgent could be your signature interaction.

4. **The Workout Summary**: After completing a workout, the summary view could be beautiful and shareable. This is organic marketing.

### Pick ONE to obsess over for v1. The others can be "good enough."

---

## Implementation Checklist

- [x] Create `Color+Extensions.swift` with full palette → `Theme/AppTheme.swift` (AppColors)
- [x] Create `Font+Extensions.swift` with type scale → `Theme/Font+Extensions.swift` + `AppTheme.swift`
- [x] Create `CGFloat+Spacing.swift` with spacing constants → `Theme/AppTheme.swift` (AppSpacing)
- [x] Create `Animation+Extensions.swift` with timing presets → `Theme/AppTheme.swift` (AppAnimation)
- [x] Build `PrimaryButton` component → `Theme/Components.swift`
- [x] Build `SetRow` component → `Views/Session/SessionComponents.swift`
- [x] Build `RestTimer` component → `Views/Session/ActiveSessionView.swift`
- [x] Audit all touch targets (44pt minimum) → `AppSpacing.minTouchTarget = 44`
- [x] Add haptic feedback to key interactions → `HapticManager` service
- [x] Refactor all views to semantic typography (Jan 29, 2025) → 30 files converted
- [ ] Test with Dynamic Type at all sizes
- [ ] Test with VoiceOver
- [ ] Choose your "signature moment" and polish it

---

## Final Thought

This design system is opinionated, and that's the point. Generic apps come from hedging every decision. Your app has a clear audience (hybrid athletes), a clear use case (complex workout tracking), and a clear vibe (confident minimalism).

Trust the system, but break the rules when you have a good reason. The best apps know when to be consistent and when to be surprising.

Now go make something people love using at 5am with chalk on their hands. 💪
