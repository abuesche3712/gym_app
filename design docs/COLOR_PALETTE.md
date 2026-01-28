# Color Palette — Joyful Redesign

> **Status:** Draft — awaiting color values from palette generator
> **Philosophy:** One dominant color, 3-5 sparse accents, simple text, subtle gradients
> **Generated:** TBD
> **Tool:** TBD (Coolors.co, Realtime Colors, etc.)

---

## 1. Base Palette (FILL IN — From Generator)

### Neutrals (Cool-Toned Dark)

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| background | `#1A0B2E` | rgb(26, 11, 46) | App background, behind all content |
| surfacePrimary | `#2D1B3D` | rgb(45, 27, 61) | Cards, primary containers |
| surfaceSecondary | `#3E2551` | rgb(62, 37, 81) | Elevated surfaces, sheets, overlays |
| surfaceTertiary | `#4A3A5A` | rgb(74, 58, 90) | Borders, dividers, input backgrounds |

**Notes:**
- Should feel "cool" not "warm" (blues/grays, not browns)
- Subtle progression from darkest (background) to lightest (tertiary)
- NOT pure black — near-black with slight blue/gray tint

---

## 2. Text Colors (FILL IN — From Generator)

### Text Hierarchy

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| textPrimary | `#FFFCF9` | rgb(255, 252, 249) | Main headings, primary content, active values |
| textSecondary | `#A09CA6` | rgb(160, 156, 166) | Supporting text, labels, completed set data |
| textTertiary | `#5A5662` | rgb(90, 86, 98) | Hints, placeholders, low-emphasis text |

**Usage Rules:**
- **Default text:** Use `textPrimary` or `textSecondary` ONLY
- **Colored text:** Only use accent/semantic colors when it needs to stand out (current exercise, PR, warnings)
- **Never:** Don't use palette colors for regular body text

**Contrast Requirements:**
- textPrimary on background: ≥ 7:1 (AAA)
- textSecondary on background: ≥ 4.5:1 (AA)
- textTertiary on background: ≥ 3:1 (minimum for large text)

---

## 3. Dominant + Accent System (FILL IN — From Generator)

### Primary Dominant Color

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| **dominant** | `#00D9FF` | rgb(0, 217, 255) | Primary actions, active states, current exercise indicator, main interactive elements |

**When to use:**
- Active/current exercise in session
- Primary action buttons ("Log Set", "End Workout")
- Toggle switches (ON state)
- Active tab indicator
- Current set highlight background (subtle opacity)

**When NOT to use:**
- Don't spray everywhere — use sparingly for impact
- Avoid for static decorations
- Not for long-form text

**Variants:**
```swift
dominantMuted = dominant.opacity(0.15)    // Subtle backgrounds, selection states
dominantSubtle = dominant.opacity(0.08)   // Hover states, very subtle highlights
dominantBright = dominant.opacity(1.0)    // Full intensity for important actions
```

---

### Accent Colors (Sparse Use)

Fill in 3-5 accent colors. These should be RARE — used only where specific meaning is needed.

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| accent1 | `#00E5CC` | rgb(0, 229, 204) | Vibrant teal — recovery/prehab modules |
| accent2 | `#FFB800` | rgb(255, 184, 0) | Bright gold — explosive modules |
| accent3 | `#7B61FF` | rgb(123, 97, 255) | Vibrant purple — cardio modules |
| accent4 | `#FF6B9D` | rgb(255, 107, 157) | Hot pink — programs! |
| accent5 | `#FF5757` | rgb(255, 87, 87) | Bright red-orange — warmup modules |

**Chosen Strategy: Sophisticated Minimal (3 accents)**

Using 3 sparse accent colors for specific module contexts:
- **accent1 (teal #14B8A6):** Recovery & prehab modules — calm, restorative vibe
- **accent2 (gold #EAB308):** Explosive modules — energetic, dynamic
- **accent3 (blue #6366F1):** Cardio modules — steady, endurance

**Philosophy:**
- Dominant cyan is THE primary color for all main interactions
- Accents are used ONLY for module differentiation (sparingly)
- If using symbol-first approach, accents may only appear as subtle tints, not bold colors

---

## 4. Semantic Colors (FILL IN — From Generator)

These are functional colors with specific meaning. Used primarily in `ActiveSessionView`.

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| success | `#00E676` | rgb(0, 230, 118) | PR hit, set completed checkmark, workout complete |
| warning | `#FFB800` | rgb(255, 184, 0) | Rest timer urgent (<10s), approaching failure, attention needed |
| destructive | `#FF5252` | rgb(255, 82, 82) | Delete actions, failed sets, errors |
| **reward** | `#00FFF0` | rgb(0, 255, 240) | **ELECTRIC PR celebration glow, achievement moments!** |
| programAccent | `#FF6B9D` | rgb(255, 107, 157) | Hot pink for programs (replaces weird green!) |

**Usage Rules:**
- **Success:** Checkmark on set completion, PR celebration, "Workout Complete" badge
- **Warning:** Rest timer when < 10s remaining, yellow pulse, "Rest almost over"
- **Destructive:** Delete buttons, "Remove exercise" confirmation, error messages

**Accessibility:**
- Never rely on color alone — always pair with icon or text label
- Success = checkmark icon + green
- Warning = warning triangle + amber
- Destructive = trash icon + red

---

## 5. Gradients (Pre-Filled — Adjust if needed)

All gradients should be SUBTLE. We do this well currently — keep that vibe.

### Card Gradient (Subtle Depth)
```swift
LinearGradient(
    colors: [
        surfacePrimary.lighter(by: 0.05),  // Slightly lighter top
        surfacePrimary,                     // Mid
        surfacePrimary.darker(by: 0.05)     // Slightly darker bottom
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```
**Usage:** Primary card backgrounds, elevated surfaces

---

### Dominant Gradient (Accent Emphasis)
```swift
LinearGradient(
    colors: [
        dominant,
        dominant.adjustedHue(by: 10)  // Slight hue shift for interest
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```
**Usage:** Primary action buttons, "Log Set" button, accent elements

---

### Success Gradient (PR Celebration)
```swift
LinearGradient(
    colors: [
        success,
        success.lighter(by: 0.15)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```
**Usage:** PR celebration overlay, workout complete screen

---

### Card Shine (Subtle Highlight)
```swift
LinearGradient(
    colors: [
        Color.white.opacity(0.05),   // Very subtle top highlight
        Color.white.opacity(0.015),  // Fades quickly
        Color.clear                   // Gone by mid-card
    ],
    startPoint: .topLeading,
    endPoint: .center
)
```
**Usage:** Overlay on cards for subtle "shine" effect (current implementation is good)

---

### Progress Bar Gradient
```swift
LinearGradient(
    colors: [
        dominant,
        dominant.adjustedHue(by: 15),
        dominant.lighter(by: 0.1)
    ],
    startPoint: .leading,
    endPoint: .trailing
)
```
**Usage:** Rest timer progress bar, workout completion progress, animated progress indicators

---

## 6. Module Type Colors (Pre-Filled — Current Strategy)

**Current Approach:** 7 distinct colors for 7 module types
**Proposed Approach:** Use symbols primarily, color secondarily

### Option A: Keep Distinct Colors (Muted)
Lower saturation, use as subtle tints rather than bold colors.

| Module Type | Current Color | Proposed | Symbol | Usage |
|-------------|---------------|----------|--------|-------|
| Warmup | #D4956A (terracotta) | accent2 @ 60% saturation | 🔥 flame | Warm orange tint |
| Prehab | #5AAF9E (teal) | accent3 @ 60% saturation | 🛡️ shield | Cool teal tint |
| Explosive | #D4B754 (gold) | accent4 @ 60% saturation | ⚡ bolt | Bright yellow tint |
| Strength | #C75B5B (coral) | dominant | 💪 muscle | Use dominant color |
| Cardio (Long) | #5B9BD5 (blue) | accent1 @ 60% saturation | 🏃 runner | Cool blue tint |
| Cardio (Speed) | #9B8ABF (lavender) | accent5 @ 60% saturation | 🚀 rocket | Purple tint |
| Recovery | #5AAF9E (teal) | accent3 @ 40% saturation | 🧘 meditation | Very muted teal |

### Option B: Symbol-First, Color-Last
Use symbols as primary identifier, color as secondary. All modules use `surfacePrimary` background with symbol in `dominant` color.

| Module Type | Symbol | Background | Symbol Color |
|-------------|--------|------------|--------------|
| Warmup | 🔥 | surfacePrimary | dominant |
| Prehab | 🛡️ | surfacePrimary | dominant |
| Explosive | ⚡ | surfacePrimary | dominant |
| Strength | 💪 | surfacePrimary | dominant |
| Cardio (Long) | 🏃 | surfacePrimary | dominant |
| Cardio (Speed) | 🚀 | surfacePrimary | dominant |
| Recovery | 🧘 | surfacePrimary | dominant |

**Recommendation:** Try Option B first (symbol-first). It's cleaner, more cohesive, and lets the dominant color shine. If users need color-coding for quick scanning, add subtle tints later.

---

## 7. Migration Map (Pre-Filled — Based on Current Code)

### Color Replacements

| Current Color | Current Hex | New Color | New Hex | Migration Notes |
|---------------|-------------|-----------|---------|-----------------|
| background | #0C0C0B | background | `[FILL IN]` | Cooler tone |
| cardBackground | #161615 | surfacePrimary | `[FILL IN]` | Renamed, cooler |
| cardBackgroundLight | #1E1E1C | surfaceSecondary | `[FILL IN]` | Renamed, cooler |
| surfaceLight | #262624 | surfaceTertiary | `[FILL IN]` | Renamed, cooler |
| border | #2E2E2B | surfaceTertiary | `[FILL IN]` | Use tertiary for borders |
| textPrimary | #F5F5F4 | textPrimary | `[FILL IN]` | Keep or adjust slightly |
| textSecondary | #A8A8A4 | textSecondary | `[FILL IN]` | Keep or adjust |
| textTertiary | #6B6B67 | textTertiary | `[FILL IN]` | Keep or adjust |
| accentBlue | #5B9BD5 | dominant | `[FILL IN]` | PRIMARY CHANGE |
| accentCyan | #6DBFBF | (deprecated) | — | Use dominant instead |
| accentTeal | #5AAF9E | accent3 | `[FILL IN]` | Keep for specific uses |
| accentMint | #8ED4B8 | (deprecated) | — | Not needed |
| accentSteel | #7A9BB8 | (deprecated) | — | Not needed |
| accentPurple | #9B8ABF | accent5 | `[FILL IN]` | Keep if using 5 accents |
| accentOrange | #D4956A | accent2 | `[FILL IN]` | Keep for warmup |
| success | #5AAF9E | success | `[FILL IN]` | Brighter green recommended |
| warning | #D4A754 | warning | `[FILL IN]` | Keep amber |
| error | #C75B5B | destructive | `[FILL IN]` | Keep red |
| rest | #5B9BD5 | (deprecated) | — | Use dominant |

---

### Component Update Strategy

| Component/File | Current Colors Used | Update Action |
|----------------|---------------------|---------------|
| **ActiveSessionView.swift** | accentBlue, success, textPrimary, cardBackground | Replace accentBlue → dominant, cardBackground → surfacePrimary |
| **SessionComponents.swift** | accentCyan, textSecondary, surfaceLight | Replace accentCyan → dominant, surfaceLight → surfaceTertiary |
| **HomeView.swift** | accentBlue, cardBackground, textPrimary | Replace accentBlue → dominant, cardBackground → surfacePrimary |
| **RestTimer** | accentBlue, warning | Replace accentBlue → dominant |
| **EndSessionSheet** | success, accentTeal | Replace accentTeal → success (if used for completion) |
| **ModuleCard** | 7 module colors | Replace with symbol-first approach (Option B) |
| **PrimaryButton** | accentBlue gradient | Replace with dominant gradient |
| **ProgressBars** | progressGradient (3 colors) | Replace with dominant-based gradient |

---

## 8. Implementation Notes (Pre-Filled)

### AppTheme.swift Changes

**Colors to Add:**
```swift
// Base
static let background = Color(hex: "______")
static let surfacePrimary = Color(hex: "______")
static let surfaceSecondary = Color(hex: "______")
static let surfaceTertiary = Color(hex: "______")

// Text
static let textPrimary = Color(hex: "______")
static let textSecondary = Color(hex: "______")
static let textTertiary = Color(hex: "______")

// Dominant
static let dominant = Color(hex: "______")
static let dominantMuted = dominant.opacity(0.15)
static let dominantSubtle = dominant.opacity(0.08)

// Accents (3-5)
static let accent1 = Color(hex: "______")
static let accent2 = Color(hex: "______")
static let accent3 = Color(hex: "______")
// Optional:
// static let accent4 = Color(hex: "______")
// static let accent5 = Color(hex: "______")

// Semantic
static let success = Color(hex: "______")
static let warning = Color(hex: "______")
static let destructive = Color(hex: "______")
```

**Colors to Deprecate:**
```swift
// Keep temporarily for migration, mark as deprecated
@available(*, deprecated, renamed: "dominant")
static let accentBlue = dominant

@available(*, deprecated, renamed: "surfacePrimary")
static let cardBackground = surfacePrimary

@available(*, deprecated, message: "Use dominant instead")
static let accentCyan = dominant

// etc...
```

**Gradients to Update:**
```swift
static let dominantGradient = LinearGradient(
    colors: [dominant, dominant.adjustedHue(by: 10)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

static let cardGradientElevated = LinearGradient(
    colors: [
        surfacePrimary.lighter(by: 0.05),
        surfacePrimary,
        surfacePrimary.darker(by: 0.05)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Remove: accentGradient, tealGradient, warmGradient
// Keep: successGradient (updated with new success color)
```

---

### Module Color Function

**Current:**
```swift
static func moduleColor(_ type: ModuleType) -> Color {
    switch type {
    case .warmup: return Color(hex: "D4956A")
    case .prehab: return accentTeal
    // etc...
    }
}
```

**Option A (Distinct Muted Colors):**
```swift
static func moduleColor(_ type: ModuleType) -> Color {
    switch type {
    case .warmup: return accent2.opacity(0.6)
    case .prehab: return accent3.opacity(0.6)
    case .explosive: return accent4.opacity(0.6)
    case .strength: return dominant
    case .cardioLong: return accent1.opacity(0.6)
    case .cardioSpeed: return accent5.opacity(0.6)
    case .recovery: return accent3.opacity(0.4)
    }
}
```

**Option B (Symbol-First, Single Color):**
```swift
static func moduleColor(_ type: ModuleType) -> Color {
    return dominant  // All modules use dominant color for icon
}

static func moduleSymbol(_ type: ModuleType) -> String {
    switch type {
    case .warmup: return "flame.fill"
    case .prehab: return "cross.case.fill"
    case .explosive: return "bolt.fill"
    case .strength: return "figure.strengthtraining.traditional"
    case .cardioLong: return "figure.run"
    case .cardioSpeed: return "figure.run.circle.fill"
    case .recovery: return "figure.mind.and.body"
    }
}
```

---

## 9. Testing Checklist

### Before Implementation
- [ ] All neutrals feel "cool" not "warm"
- [ ] Dominant color pops but doesn't overwhelm
- [ ] Accent colors are distinct from dominant
- [ ] Semantic colors are clear (green = good, red = bad, yellow = caution)

### Contrast Verification
- [ ] textPrimary on background: ≥ 7:1 (AAA)
- [ ] textSecondary on background: ≥ 4.5:1 (AA)
- [ ] textTertiary on surfaceTertiary: ≥ 3:1
- [ ] dominant on surfacePrimary (buttons): ≥ 4.5:1
- [ ] success/warning/destructive on background: ≥ 4.5:1

Use: [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)

### Real-World Testing
- [ ] View on actual iPhone (not just simulator)
- [ ] Test in bright sunlight (outdoor gym scenario)
- [ ] Test on OLED display (true blacks, color vibrancy)
- [ ] Test with Night Shift enabled
- [ ] Color blindness simulator (Sim Daltonism app)

### Before/After Screenshots
Take screenshots of these views before implementing:
- [ ] HomeView
- [ ] ActiveSessionView (current exercise)
- [ ] ModuleDetailView (module cards)
- [ ] EndSessionSheet
- [ ] RestTimer

---

## 10. Open Questions

### For You to Decide:
1. **How many accent colors?** 3, 4, or 5? (Start with 3 recommended)
2. **Module strategy?** Symbol-first or color-coded?
3. **Dominant color hue?** Cyan (blue-green) or pure blue or teal?
4. **Gradient intensity?** Current subtle level or slightly more dramatic?

### Implementation Decisions:
1. **Phased rollout?** Update colors first, then refactor component usage? Or all at once?
2. **Backward compatibility?** Keep deprecated colors temporarily or hard cutover?
3. **User preference?** Allow accent color customization eventually? (Probably no for v1)

---

## 11. Next Steps

1. **You:** Generate palette with tool, fill in hex/RGB values above
2. **You:** Choose 3-5 accent colors and assign rough purposes
3. **You:** Decide on module color strategy (A or B)
4. **We:** Review together, verify contrast ratios
5. **I:** Implement in AppTheme.swift
6. **We:** Test, iterate, refine

---

**Ready to fill in the blanks?** 🎨

Once you populate the hex values, we'll have a complete color specification to guide implementation!
