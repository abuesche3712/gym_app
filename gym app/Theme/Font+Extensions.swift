//
//  Font+Extensions.swift
//  gym app
//
//  Typography system using SwiftUI semantic text styles with enhancements
//  for monospaced numbers, rounded display text, and elegant labels
//

import SwiftUI

// MARK: - Font Variants

extension Font {

    // MARK: - Display (Big numbers, workout titles - Rounded for confident feel)

    /// Large display text - rounded, bold (e.g., workout summaries, big stats)
    static var displayLarge: Font {
        .system(.largeTitle, design: .rounded, weight: .bold)
    }

    /// Medium display text - rounded, bold (e.g., module counts, session time)
    static var displayMedium: Font {
        .system(.title, design: .rounded, weight: .bold)
    }

    /// Small display text - rounded, semibold (e.g., set numbers)
    static var displaySmall: Font {
        .system(.title2, design: .rounded, weight: .semibold)
    }

    // MARK: - Monospaced (Numbers that change - prevents layout shift)

    /// Large monospaced numbers (e.g., rest timer, session duration)
    static var monoLarge: Font {
        .system(.largeTitle, design: .monospaced, weight: .medium)
    }

    /// Medium monospaced numbers (e.g., weight, reps during set)
    static var monoMedium: Font {
        .system(.title3, design: .monospaced, weight: .medium)
    }

    /// Small monospaced numbers (e.g., set indicators, compact stats)
    static var monoSmall: Font {
        .system(.body, design: .monospaced, weight: .medium)
    }

    /// Caption monospaced (e.g., tiny counters, badges)
    static var monoCaption: Font {
        .system(.caption, design: .monospaced, weight: .semibold)
    }
}

// MARK: - Text Style Modifiers

extension View {

    // MARK: - Display Styles (Rounded, bold - for big moments)

    /// Large display style - rounded, bold
    /// Use for: Workout summaries, completion screens, big stats
    func displayLarge(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.displayLarge)
            .foregroundColor(color)
    }

    /// Medium display style - rounded, bold
    /// Use for: Section titles, module counts, timers
    func displayMedium(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.displayMedium)
            .foregroundColor(color)
    }

    /// Small display style - rounded, semibold
    /// Use for: Card headers, subsection titles
    func displaySmall(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.displaySmall)
            .foregroundColor(color)
    }

    // MARK: - Monospaced Styles (Numbers that change)

    /// Large monospaced numbers - prevents layout shift
    /// Use for: Rest timers, session duration, countdown
    func monoLarge(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.monoLarge)
            .foregroundColor(color)
            .monospacedDigit()
    }

    /// Medium monospaced numbers
    /// Use for: Weight inputs, rep counts, active set data
    func monoMedium(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.monoMedium)
            .foregroundColor(color)
            .monospacedDigit()
    }

    /// Small monospaced numbers
    /// Use for: Set indicators, small counters
    func monoSmall(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.monoSmall)
            .foregroundColor(color)
            .monospacedDigit()
    }

    /// Caption monospaced
    /// Use for: Tiny badges, compact numbers
    func monoCaption(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.monoCaption)
            .foregroundColor(color)
            .monospacedDigit()
    }

    // MARK: - Label Styles (Uppercase + tracking - like "TODAY" in header)

    /// Elegant uppercase label - semibold, tracked
    /// Use for: Section headers, screen labels, category tags
    /// Example: "TODAY", "WORKOUT BUILDER", "ACTIVE PROGRAM"
    func elegantLabel(color: Color = AppColors.textSecondary, tracking: CGFloat = 1.5) -> some View {
        self
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(tracking)
            .foregroundColor(color)
    }

    /// Small caps label - for tiny headers
    /// Use for: Form section labels, metadata
    func smallCapsLabel(color: Color = AppColors.textTertiary, tracking: CGFloat = 1.2) -> some View {
        self
            .font(.caption2.weight(.medium))
            .textCase(.uppercase)
            .tracking(tracking)
            .foregroundColor(color)
    }

    /// Stat label - uppercase, tracked, tiny
    /// Use for: Stat descriptions ("completed", "scheduled", "volume")
    func statLabel(color: Color = AppColors.textSecondary, tracking: CGFloat = 1.2) -> some View {
        self
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .tracking(tracking)
            .foregroundColor(color)
    }

    // MARK: - Standard Text Styles (Semantic + color convenience)

    /// Headline text
    func headline(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.headline)
            .foregroundColor(color)
    }

    /// Subheadline text
    func subheadline(color: Color = AppColors.textSecondary) -> some View {
        self
            .font(.subheadline)
            .foregroundColor(color)
    }

    /// Body text
    func body(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.body)
            .foregroundColor(color)
    }

    /// Callout text
    func callout(color: Color = AppColors.textSecondary) -> some View {
        self
            .font(.callout)
            .foregroundColor(color)
    }

    /// Caption text
    func caption(color: Color = AppColors.textSecondary) -> some View {
        self
            .font(.caption)
            .foregroundColor(color)
    }

    /// Tiny caption text
    func caption2(color: Color = AppColors.textTertiary) -> some View {
        self
            .font(.caption2)
            .foregroundColor(color)
    }
}

// MARK: - Card Style Modifier

/// Reusable flat card styling: padding + rounded background + border stroke
/// Used by feed attachment cards, content cards, form sections, etc.
struct FlatCardStyle: ViewModifier {
    var fill: Color = AppColors.surfacePrimary
    var cornerRadius: CGFloat = AppCorners.large
    var strokeColor: Color = AppColors.surfaceTertiary.opacity(0.5)
    var strokeWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
    }
}

extension View {
    func flatCardStyle(
        fill: Color = AppColors.surfacePrimary,
        cornerRadius: CGFloat = AppCorners.large,
        strokeColor: Color = AppColors.surfaceTertiary.opacity(0.5),
        strokeWidth: CGFloat = 1
    ) -> some View {
        modifier(FlatCardStyle(fill: fill, cornerRadius: cornerRadius, strokeColor: strokeColor, strokeWidth: strokeWidth))
    }
}

// MARK: - Typography Guidelines

/*

 TYPOGRAPHY SYSTEM GUIDELINES
 ═══════════════════════════════════════════════════════════════

 ## When to Use Each Style

 ### Display Styles (Rounded, Bold)
 - displayLarge: Workout completion screens, final stats, celebration moments
 - displayMedium: Module titles, session timers, big numbers
 - displaySmall: Card headers, subsection titles

 ### Monospaced Styles (Numbers that Change)
 - monoLarge: Rest timers, session duration (prevents jump when digits change)
 - monoMedium: Weight/reps during active set, live counters
 - monoSmall: Set numbers, small live stats
 - monoCaption: Tiny badges with numbers

 ### Label Styles (Uppercase + Tracked)
 - elegantLabel: Main section headers ("TODAY", "TRAINING HUB")
 - smallCapsLabel: Form sections, metadata labels
 - statLabel: Stat descriptions ("COMPLETED", "VOLUME")

 ### Standard Styles
 - headline: Exercise names, important text
 - subheadline: Secondary info, descriptions
 - body: Default text, paragraphs
 - callout: Hints, supplementary info
 - caption: Meta info, timestamps
 - caption2: Tiny support text

 ## Migration Examples

 ### Before (inline):
 ```swift
 Text("135")
     .font(.system(size: 32, weight: .medium, design: .monospaced))
     .foregroundColor(AppColors.textPrimary)
 ```

 ### After (modular):
 ```swift
 Text("135")
     .monoLarge()
 ```

 ### Before (inline):
 ```swift
 Text("TODAY")
     .font(.caption.weight(.semibold))
     .textCase(.uppercase)
     .tracking(1.5)
     .foregroundColor(AppColors.dominant)
 ```

 ### After (modular):
 ```swift
 Text("TODAY")
     .elegantLabel(color: AppColors.dominant)
 ```

 ### Before (inline):
 ```swift
 Text(workout.name)
     .font(.headline)
     .foregroundColor(AppColors.textPrimary)
 ```

 ### After (modular):
 ```swift
 Text(workout.name)
     .headline()
 ```

 ## Benefits

 1. **Consistency**: Same style applied everywhere = cohesive feel
 2. **Accessibility**: Uses semantic text styles = respects Dynamic Type
 3. **Maintainability**: Change once, updates everywhere
 4. **Layout Stability**: Monospaced prevents timer/counter jumping
 5. **Personality**: Rounded display adds confident, friendly feel
 6. **Elegance**: Tracked labels add premium, refined aesthetic

 */
