//
//  Components.swift
//  gym app
//
//  Reusable UI components
//

import SwiftUI

// MARK: - View Selection Mode

/// Selection mode for list views when used in sharing/selection contexts
enum ViewSelectionMode {
    case forSharing  // Single selection, dismiss on tap
}

// MARK: - Filter Pill

/// Shared selectable capsule chip used across filter rows (Modules, History, etc).
/// A few call sites need to reproduce a slightly different highlight treatment they
/// had before consolidation, so the fill/stroke opacity, selected text color, and
/// horizontal padding are overridable while defaulting to the most common look.
struct FilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    var tint: Color = AppColors.dominant
    var selectedTextColor: Color? = nil
    var selectedFillOpacity: Double = 0.2
    var selectedStrokeOpacity: Double = 0.5
    var horizontalPadding: CGFloat = AppSpacing.lg
    /// Fixed weight for the title regardless of selection state. When nil, the
    /// title is `.semibold` while selected and `.regular` otherwise.
    var fixedFontWeight: Font.Weight? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }

                Text(title)
                    .subheadline(color: isSelected ? (selectedTextColor ?? tint) : AppColors.textSecondary)
                    .fontWeight(fixedFontWeight ?? (isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, AppSpacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? tint.opacity(selectedFillOpacity) : AppColors.surfacePrimary)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? tint.opacity(selectedStrokeOpacity) : AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Stat Pill

/// Shared vertical value/label stat chip. Supports an optional icon, and an
/// optional selected/action pair so it can also serve as a source filter
/// (e.g. "Provided" / "Custom" counts that double as filter buttons).
/// `showSelectionStroke` reproduces a highlight ring one call site had before
/// consolidation; it is off by default to match the plain (non-stroked) look.
struct StatPill: View {
    let value: String
    let label: String
    var icon: String? = nil
    var isSelected: Bool = false
    var showSelectionStroke: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(.pressable)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : AppColors.dominant)
            }
            Text(value)
                .displaySmall(color: isSelected ? .white : AppColors.textPrimary)
                .fontWeight(.bold)
            Text(label)
                .caption(color: isSelected ? .white.opacity(0.8) : AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(isSelected ? AppColors.dominant : AppColors.surfacePrimary)
        )
        .overlay {
            if showSelectionStroke {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(isSelected ? AppColors.dominant : Color.clear, lineWidth: 2)
            }
        }
    }
}

// MARK: - Unified Card Style

struct UnifiedCardStyle: ViewModifier {
    var padding: CGFloat = AppSpacing.cardPadding
    var stroke: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
            )
            .overlay {
                if stroke {
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                }
            }
    }
}

extension View {
    /// The single canonical card treatment: large corner radius, `surfacePrimary` fill,
    /// optional hairline `surfaceTertiary` stroke. `padding: 0` lets call sites that
    /// already apply their own (differently-valued, or interleaved with other modifiers)
    /// padding keep doing so while still sharing the fill/stroke.
    func unifiedCard(padding: CGFloat = AppSpacing.cardPadding, stroke: Bool = true) -> some View {
        self.modifier(UnifiedCardStyle(padding: padding, stroke: stroke))
    }
}

// MARK: - Section Header

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

// MARK: - Time Picker View

struct TimePickerView: View {
    @Binding var totalSeconds: Int
    var maxMinutes: Int = 10
    var maxHours: Int = 0  // Set > 0 to show hours picker (for cardio)
    var label: String = "Time"
    var compact: Bool = false
    var secondsStep: Int = 5  // Step size for seconds (1 for fine control, 5 for quick selection)

    private var showHours: Bool { maxHours > 0 }

    private var hours: Binding<Int> {
        Binding(
            get: { totalSeconds / 3600 },
            set: { totalSeconds = $0 * 3600 + (totalSeconds % 3600) }
        )
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { showHours ? (totalSeconds % 3600) / 60 : totalSeconds / 60 },
            set: {
                if showHours {
                    totalSeconds = (totalSeconds / 3600) * 3600 + $0 * 60 + (totalSeconds % 60)
                } else {
                    totalSeconds = $0 * 60 + (totalSeconds % 60)
                }
            }
        )
    }

    private var seconds: Binding<Int> {
        Binding(
            get: { totalSeconds % 60 },
            set: {
                if showHours {
                    totalSeconds = (totalSeconds / 3600) * 3600 + ((totalSeconds % 3600) / 60) * 60 + $0
                } else {
                    totalSeconds = (totalSeconds / 60) * 60 + $0
                }
            }
        )
    }

    private var secondsRange: [Int] {
        Array(stride(from: 0, through: 59, by: secondsStep))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if !compact {
                Text(label.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
            }

            HStack(spacing: 0) {
                if showHours {
                    // Hours picker
                    Picker("Hours", selection: hours) {
                        ForEach(0...maxHours, id: \.self) { hr in
                            Text("\(hr)").tag(hr)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 50)
                    .clipped()

                    Text("hr")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 25)
                }

                // Minutes picker
                Picker("Minutes", selection: minutes) {
                    ForEach(0..<(showHours ? 60 : maxMinutes + 1), id: \.self) { min in
                        Text(showHours ? String(format: "%02d", min) : "\(min)").tag(min)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: showHours ? 50 : 60)
                .clipped()

                Text("min")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: showHours ? 28 : 30)

                // Seconds picker
                Picker("Seconds", selection: seconds) {
                    ForEach(secondsRange, id: \.self) { sec in
                        Text(String(format: "%02d", sec)).tag(sec)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: showHours ? 50 : 60)
                .clipped()

                Text("sec")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: showHours ? 28 : 30)
            }
            .frame(height: compact ? 100 : 120)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.surfaceTertiary)
            )
        }
    }
}

// MARK: - Compact Time Picker (for inline use)

struct CompactTimePicker: View {
    @Binding var totalSeconds: Int
    var maxMinutes: Int = 10

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(formatDurationVerbose(totalSeconds))
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            Stepper("", value: $totalSeconds, in: 0...(maxMinutes * 60), step: 15)
                .labelsHidden()
        }
    }
}
