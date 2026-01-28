//
//  ProgramWeeklyGridView.swift
//  gym app
//
//  Weekly grid view showing workout slots for each day
//

import SwiftUI

struct ProgramWeeklyGridView: View {
    let program: Program
    let onDayTapped: (Int) -> Void
    let onSlotRemove: (UUID) -> Void
    let onModuleSlotRemove: (UUID) -> Void

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    Text(dayNames[day])
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)

            // Day cells
            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    UnifiedDayCell(
                        dayOfWeek: day,
                        slots: program.allSlotsForDay(day),
                        onTap: {
                            onDayTapped(day)
                        },
                        onSlotRemove: { slotId in
                            // Check if it's a legacy slot or unified slot
                            if program.workoutSlots.contains(where: { $0.id == slotId }) {
                                onSlotRemove(slotId)
                            } else {
                                onModuleSlotRemove(slotId)
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let dayOfWeek: Int
    let slots: [ProgramWorkoutSlot]
    let onTap: () -> Void
    let onSlotRemove: (UUID) -> Void

    var body: some View {
        VStack(spacing: 4) {
            if slots.isEmpty {
                emptyDayContent
            } else {
                slotsList
            }

            // Always show add button
            addButton
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var emptyDayContent: some View {
        Text("Rest")
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var slotsList: some View {
        VStack(spacing: 2) {
            ForEach(slots) { slot in
                SlotChip(
                    slot: slot,
                    onRemove: {
                        onSlotRemove(slot.id)
                    }
                )
            }
        }
        .padding(4)
    }

    private var addButton: some View {
        Button {
            onTap()
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.caption)
                .foregroundColor(AppColors.programAccent)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }
}

// MARK: - Slot Chip

struct SlotChip: View {
    let slot: ProgramWorkoutSlot
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Text(abbreviatedName(slot.workoutName))
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(slotColor)
        .foregroundColor(.white)
        .cornerRadius(4)
    }

    private var slotColor: Color {
        // Generate a consistent color based on workout name
        let hash = slot.workoutName.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }

    private func abbreviatedName(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            // Take first letter of each word
            return words.prefix(3).map { String($0.prefix(1)) }.joined()
        } else if name.count > 6 {
            return String(name.prefix(5)) + "..."
        }
        return name
    }
}

// MARK: - Unified Day Cell (supports both workouts and modules)

struct UnifiedDayCell: View {
    let dayOfWeek: Int
    let slots: [ProgramSlot]
    let onTap: () -> Void
    let onSlotRemove: (UUID) -> Void

    var body: some View {
        VStack(spacing: 4) {
            if slots.isEmpty {
                emptyDayContent
            } else {
                slotsList
            }

            // Always show add button
            addButton
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var emptyDayContent: some View {
        Text("Rest")
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var slotsList: some View {
        VStack(spacing: 2) {
            ForEach(slots) { slot in
                UnifiedSlotChip(
                    slot: slot,
                    onRemove: {
                        onSlotRemove(slot.id)
                    }
                )
            }
        }
        .padding(4)
    }

    private var addButton: some View {
        Button {
            onTap()
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.caption)
                .foregroundColor(AppColors.programAccent)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }
}

// MARK: - Unified Slot Chip (supports both workouts and modules)

struct UnifiedSlotChip: View {
    let slot: ProgramSlot
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            // Module type icon for modules
            if let moduleType = slot.content.moduleType {
                Image(systemName: moduleType.icon)
                    .font(.system(size: 7))
            }

            Text(abbreviatedName(slot.displayName))
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(slotColor)
        .foregroundColor(.white)
        .cornerRadius(4)
    }

    private var slotColor: Color {
        // Use module type color for modules, hash-based color for workouts
        if let moduleType = slot.content.moduleType {
            return moduleType.color
        }
        // Generate a consistent color based on name
        let hash = slot.displayName.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }

    private func abbreviatedName(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            // Take first letter of each word
            return words.prefix(3).map { String($0.prefix(1)) }.joined()
        } else if name.count > 6 {
            return String(name.prefix(5)) + "..."
        }
        return name
    }
}

#Preview {
    ProgramWeeklyGridView(
        program: Program(
            name: "Test Program",
            durationWeeks: 8
        ),
        onDayTapped: { _ in },
        onSlotRemove: { _ in },
        onModuleSlotRemove: { _ in }
    )
    .padding()
}
