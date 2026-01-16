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
                    DayCell(
                        dayOfWeek: day,
                        slots: slotsForDay(day),
                        onTap: {
                            onDayTapped(day)
                        },
                        onSlotRemove: onSlotRemove
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func slotsForDay(_ day: Int) -> [ProgramWorkoutSlot] {
        program.workoutSlots
            .filter { $0.dayOfWeek == day && $0.scheduleType == .weekly }
            .sorted { $0.order < $1.order }
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
                .foregroundColor(.accentColor)
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

#Preview {
    ProgramWeeklyGridView(
        program: Program(
            name: "Test Program",
            durationWeeks: 8
        ),
        onDayTapped: { _ in },
        onSlotRemove: { _ in }
    )
    .padding()
}
