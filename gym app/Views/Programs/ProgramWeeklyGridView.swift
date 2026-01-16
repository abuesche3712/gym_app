//
//  ProgramWeeklyGridView.swift
//  gym app
//
//  Weekly grid view showing workout slots for each day
//

import SwiftUI

struct ProgramWeeklyGridView: View {
    let program: Program
    @Binding var editMode: EditMode
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
                        isEditing: editMode == .active,
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
    let isEditing: Bool
    let onTap: () -> Void
    let onSlotRemove: (UUID) -> Void

    var body: some View {
        VStack(spacing: 4) {
            if slots.isEmpty {
                emptyDayContent
            } else {
                slotsList
            }

            if isEditing {
                addButton
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var emptyDayContent: some View {
        VStack {
            if isEditing {
                Text("Rest")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                onTap()
            }
        }
    }

    private var slotsList: some View {
        VStack(spacing: 2) {
            ForEach(slots) { slot in
                SlotChip(
                    slot: slot,
                    isEditing: isEditing,
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
    let isEditing: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Text(abbreviatedName(slot.workoutName))
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)

            if isEditing {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
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

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var editMode: EditMode = .inactive

        var body: some View {
            let program = Program(
                name: "Test Program",
                durationWeeks: 8
            )

            VStack {
                Toggle("Edit Mode", isOn: Binding(
                    get: { editMode == .active },
                    set: { editMode = $0 ? .active : .inactive }
                ))
                .padding()

                ProgramWeeklyGridView(
                    program: program,
                    editMode: $editMode,
                    onDayTapped: { day in
                        print("Tapped day: \(day)")
                    },
                    onSlotRemove: { id in
                        print("Remove slot: \(id)")
                    }
                )
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
