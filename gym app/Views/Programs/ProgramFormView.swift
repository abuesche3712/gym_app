//
//  ProgramFormView.swift
//  gym app
//
//  All-in-one view for creating and editing training programs
//

import SwiftUI

struct ProgramFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var programViewModel: ProgramViewModel
    @EnvironmentObject private var workoutViewModel: WorkoutViewModel
    @EnvironmentObject private var moduleViewModel: ModuleViewModel

    let program: Program?
    var onSave: ((Program) -> Void)?

    // Program info
    @State private var name: String
    @State private var description: String
    @State private var durationWeeks: Int

    // Schedule state
    @State private var workoutSlots: [ProgramWorkoutSlot]
    @State private var moduleSlots: [ProgramSlot]

    // Progression state
    @State private var progressionEnabled: Bool
    @State private var defaultProgressionRule: ProgressionRule?

    // UI state
    @State private var showingAddSlotSheet = false
    @State private var selectedDayOfWeek: Int?
    @State private var showingActivateSheet = false
    @State private var showingDeactivateAlert = false

    private let durationOptions = [2, 4, 6, 8, 10, 12, 16]
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var isEditing: Bool { program != nil }

    private var currentProgram: Program? {
        guard let program = program else { return nil }
        return programViewModel.getProgram(id: program.id)
    }

    private var isActive: Bool {
        currentProgram?.isActive ?? false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(program: Program?, onSave: ((Program) -> Void)? = nil) {
        self.program = program
        self.onSave = onSave
        _name = State(initialValue: program?.name ?? "")
        _description = State(initialValue: program?.programDescription ?? "")
        _durationWeeks = State(initialValue: program?.durationWeeks ?? 4)
        _workoutSlots = State(initialValue: program?.workoutSlots ?? [])
        _moduleSlots = State(initialValue: program?.moduleSlots ?? [])
        _progressionEnabled = State(initialValue: program?.progressionEnabled ?? false)
        _defaultProgressionRule = State(initialValue: program?.defaultProgressionRule)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Header
                formHeader

                // Program Info Section
                programInfoSection

                // Progression Section
                progressionSection

                // Weekly Schedule Section
                weeklyScheduleSection

                // Activation Section (only for existing programs)
                if isEditing {
                    activationSection
                }

                // Progress Section (only when active)
                if isActive, let startDate = currentProgram?.startDate {
                    progressSection(startDate: startDate)
                }

                // Save/Create Button
                saveButton
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAddSlotSheet) {
            if let dayOfWeek = selectedDayOfWeek {
                InlineAddSlotSheet(
                    dayOfWeek: dayOfWeek,
                    durationWeeks: durationWeeks,
                    workoutSlots: $workoutSlots,
                    moduleSlots: $moduleSlots
                )
            }
        }
        .sheet(isPresented: $showingActivateSheet) {
            if let program = currentProgram {
                ActivateProgramSheet(program: program)
            }
        }
        .alert("Deactivate Program?", isPresented: $showingDeactivateAlert) {
            Button("Keep Schedule") {
                if let program = currentProgram {
                    programViewModel.deactivateProgram(program, removeFutureScheduled: false)
                }
            }
            Button("Remove Future Workouts", role: .destructive) {
                if let program = currentProgram {
                    programViewModel.deactivateProgram(program, removeFutureScheduled: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Would you like to keep the scheduled workouts or remove future ones?")
        }
    }

    // MARK: - Header

    private var formHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppColors.surfaceTertiary)
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                        )
                }

                Spacer()

                if isEditing && isActive {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.programAccent)
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.programAccent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(AppColors.programAccent.opacity(0.15))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "EDIT PROGRAM" : "NEW PROGRAM")
                    .elegantLabel(color: AppColors.programAccent)

                Text(isEditing ? "Edit Program" : "Create Program")
                    .font(.title)
                    .foregroundColor(AppColors.textPrimary)
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.programAccent.opacity(0.6), AppColors.programAccent.opacity(0.1), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
    }

    // MARK: - Program Info Section

    private var programInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Program Details", icon: "doc.text")

            VStack(spacing: AppSpacing.md) {
                // Name field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)

                    TextField("e.g. 8-Week Strength", text: $name)
                        .font(.body)
                        .padding(AppSpacing.md)
                        .background(AppColors.surfaceTertiary)
                        .cornerRadius(AppCorners.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                        )
                }

                // Duration picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(durationOptions, id: \.self) { weeks in
                                DurationChip(
                                    weeks: weeks,
                                    isSelected: durationWeeks == weeks
                                ) {
                                    withAnimation(AppAnimation.quick) {
                                        durationWeeks = weeks
                                    }
                                }
                            }
                        }
                    }
                }

                // Description field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (optional)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Goals, focus areas, etc.", text: $description, axis: .vertical)
                        .font(.body)
                        .lineLimit(2...4)
                        .padding(AppSpacing.md)
                        .background(AppColors.surfaceTertiary)
                        .cornerRadius(AppCorners.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 0.5)
                    )
            )
        }
    }

    // MARK: - Progression Section

    private var progressionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Auto-Progression", icon: "chart.line.uptrend.xyaxis")

            VStack(spacing: AppSpacing.md) {
                // Enable toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Auto-Progression")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)

                        Text("Automatically suggest increased weights based on previous sessions")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $progressionEnabled)
                        .labelsHidden()
                        .tint(AppColors.dominant)
                }

                // Progression rule picker (only when enabled)
                if progressionEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progression Rate")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: AppSpacing.sm) {
                            progressionRuleButton(
                                title: "Conservative",
                                subtitle: "+2.5%, 5lb steps",
                                rule: .conservative,
                                isSelected: isRuleSelected(.conservative)
                            )

                            progressionRuleButton(
                                title: "Moderate",
                                subtitle: "+5%, 5lb steps",
                                rule: .moderate,
                                isSelected: isRuleSelected(.moderate)
                            )

                            progressionRuleButton(
                                title: "Fine-Grained",
                                subtitle: "+2.5%, 2.5lb steps",
                                rule: .fineGrained,
                                isSelected: isRuleSelected(.fineGrained)
                            )
                        }
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 0.5)
                    )
            )
        }
    }

    private func isRuleSelected(_ rule: ProgressionRule) -> Bool {
        guard let currentRule = defaultProgressionRule else { return false }
        return currentRule.percentageIncrease == rule.percentageIncrease &&
               currentRule.roundingIncrement == rule.roundingIncrement
    }

    private func progressionRuleButton(title: String, subtitle: String, rule: ProgressionRule, isSelected: Bool) -> some View {
        Button {
            withAnimation(AppAnimation.quick) {
                defaultProgressionRule = rule
            }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isSelected ? AppColors.dominant : AppColors.surfaceTertiary)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Schedule Section

    private var weeklyScheduleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Weekly Schedule", icon: "calendar")

            VStack(spacing: AppSpacing.sm) {
                Text("Tap + to add a workout or module to each day")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)

                // Day headers
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { day in
                        Text(dayNames[day])
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Day cells
                HStack(alignment: .top, spacing: 4) {
                    ForEach(0..<7, id: \.self) { day in
                        InlineDayCell(
                            dayOfWeek: day,
                            workoutSlots: workoutSlots.filter { $0.dayOfWeek == day },
                            moduleSlots: moduleSlots.filter { $0.dayOfWeek == day },
                            onTap: {
                                selectedDayOfWeek = day
                                showingAddSlotSheet = true
                            },
                            onWorkoutSlotRemove: { slotId in
                                workoutSlots.removeAll { $0.id == slotId }
                            },
                            onModuleSlotRemove: { slotId in
                                moduleSlots.removeAll { $0.id == slotId }
                            }
                        )
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 0.5)
                    )
            )

            // Schedule summary
            if !workoutSlots.isEmpty || !moduleSlots.isEmpty {
                scheduleSummary
            }
        }
    }

    private var scheduleSummary: some View {
        HStack(spacing: AppSpacing.lg) {
            if !workoutSlots.isEmpty {
                Label("\(workoutSlots.filter { $0.scheduleType == .weekly }.count) workouts/week", systemImage: "figure.run")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            if !moduleSlots.isEmpty {
                Label("\(moduleSlots.filter { $0.scheduleType == .weekly }.count) modules/week", systemImage: "square.stack.3d.up")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            let activeDays = Set((workoutSlots.map { $0.dayOfWeek }) + (moduleSlots.map { $0.dayOfWeek })).count
            Text("\(activeDays) active days")
                .font(.caption)
                .foregroundColor(AppColors.dominant)
        }
        .padding(.horizontal, AppSpacing.sm)
    }

    // MARK: - Activation Section

    private var activationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Program Status", icon: "play.circle")

            VStack(spacing: AppSpacing.md) {
                if isActive {
                    // Deactivate button
                    Button {
                        showingDeactivateAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle")
                                .font(.body)
                            Text("Deactivate Program")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppColors.error.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppCorners.medium)
                                        .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                } else {
                    // Activate button
                    Button {
                        // Save first, then activate
                        saveProgram()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingActivateSheet = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.body)
                            Text("Activate Program")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(workoutSlots.isEmpty && moduleSlots.isEmpty ? AppColors.textTertiary : AppColors.programAccent)
                        )
                    }
                    .disabled(workoutSlots.isEmpty && moduleSlots.isEmpty)

                    if workoutSlots.isEmpty && moduleSlots.isEmpty {
                        Text("Add workouts or modules to the schedule before activating")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(isActive ? AppColors.programAccent.opacity(0.3) : AppColors.surfaceTertiary.opacity(0.5), lineWidth: isActive ? 1 : 0.5)
                    )
            )
        }
    }

    // MARK: - Progress Section

    private func progressSection(startDate: Date) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Progress", icon: "chart.line.uptrend.xyaxis")

            VStack(spacing: AppSpacing.md) {
                let progress = programProgress(startDate: startDate)
                let currentWeek = Int(progress * Double(durationWeeks)) + 1
                let weeksRemaining = durationWeeks - currentWeek + 1

                HStack {
                    Text("Week \(min(currentWeek, durationWeeks)) of \(durationWeeks)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text("\(max(weeksRemaining, 0)) weeks remaining")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                AnimatedProgressBar(
                    progress: progress,
                    gradient: AppGradients.programGradient,
                    height: 8
                )

                HStack {
                    Text("Started \(startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)

                    Spacer()

                    if let endDate = currentProgram?.endDate {
                        Text("Ends \(endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .gradientCard(accent: AppColors.programAccent, padding: 0)
        }
    }

    private func programProgress(startDate: Date) -> Double {
        let totalDays = Double(durationWeeks * 7)
        let elapsed = Date().timeIntervalSince(startDate) / (24 * 60 * 60)
        return min(max(elapsed / totalDays, 0), 1)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveProgram()
            dismiss()
        } label: {
            Text(isEditing ? "Save Changes" : "Create Program")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(canSave ? AppColors.dominant : AppColors.textTertiary)
                )
        }
        .disabled(!canSave)
        .padding(.top, AppSpacing.md)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.programAccent)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
        }
    }

    private func saveProgram() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        if isEditing, var updatedProgram = currentProgram {
            updatedProgram.name = trimmedName
            updatedProgram.programDescription = trimmedDescription.isEmpty ? nil : trimmedDescription

            let durationChanged = updatedProgram.durationWeeks != durationWeeks
            updatedProgram.durationWeeks = durationWeeks
            updatedProgram.workoutSlots = workoutSlots
            updatedProgram.moduleSlots = moduleSlots
            updatedProgram.progressionEnabled = progressionEnabled
            updatedProgram.defaultProgressionRule = defaultProgressionRule

            // Recalculate end date if active and duration changed
            if updatedProgram.isActive, let startDate = updatedProgram.startDate, durationChanged {
                updatedProgram.endDate = Calendar.current.date(byAdding: .weekOfYear, value: durationWeeks, to: startDate)
            }

            programViewModel.saveProgram(updatedProgram)

            // If active, update the schedule
            if updatedProgram.isActive {
                programViewModel.updateActiveProgramSchedule(updatedProgram)
            }

            onSave?(updatedProgram)
        } else {
            var newProgram = programViewModel.createProgram(
                name: trimmedName,
                durationWeeks: durationWeeks,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription
            )

            // Add slots to the new program
            for slot in workoutSlots {
                newProgram.addSlot(slot)
            }
            for slot in moduleSlots {
                newProgram.addModuleSlot(slot)
            }

            // Set progression settings
            newProgram.progressionEnabled = progressionEnabled
            newProgram.defaultProgressionRule = defaultProgressionRule

            programViewModel.saveProgram(newProgram)
            onSave?(newProgram)
        }
    }
}

// MARK: - Duration Chip

private struct DurationChip: View {
    let weeks: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(weeks) weeks")
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.programAccent.opacity(0.2) : AppColors.surfaceTertiary)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? AppColors.programAccent.opacity(0.5) : AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? AppColors.programAccent : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline Day Cell

private struct InlineDayCell: View {
    let dayOfWeek: Int
    let workoutSlots: [ProgramWorkoutSlot]
    let moduleSlots: [ProgramSlot]
    let onTap: () -> Void
    let onWorkoutSlotRemove: (UUID) -> Void
    let onModuleSlotRemove: (UUID) -> Void

    private var isEmpty: Bool {
        workoutSlots.isEmpty && moduleSlots.isEmpty
    }

    var body: some View {
        VStack(spacing: 4) {
            if isEmpty {
                Text("Rest")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 2) {
                    ForEach(workoutSlots) { slot in
                        InlineSlotChip(
                            name: slot.workoutName,
                            color: slotColor(for: slot.workoutName),
                            icon: nil,
                            onRemove: { onWorkoutSlotRemove(slot.id) }
                        )
                    }

                    ForEach(moduleSlots) { slot in
                        InlineSlotChip(
                            name: slot.displayName,
                            color: slot.content.moduleType?.color ?? AppColors.accent3,
                            icon: slot.content.moduleType?.icon,
                            onRemove: { onModuleSlotRemove(slot.id) }
                        )
                    }
                }
                .padding(4)
            }

            Button(action: onTap) {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.programAccent)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(AppColors.surfaceTertiary)
        .cornerRadius(AppCorners.small)
    }

    private func slotColor(for name: String) -> Color {
        let hash = name.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
}

// MARK: - Inline Slot Chip

private struct InlineSlotChip: View {
    let name: String
    let color: Color
    let icon: String?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }

            Text(abbreviatedName(name))
                .font(.caption2.weight(.medium))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color)
        .foregroundColor(.white)
        .cornerRadius(4)
    }

    private func abbreviatedName(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return words.prefix(3).map { String($0.prefix(1)) }.joined()
        } else if name.count > 6 {
            return String(name.prefix(5)) + "..."
        }
        return name
    }
}

// MARK: - Inline Add Slot Sheet

private struct InlineAddSlotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutViewModel: WorkoutViewModel
    @EnvironmentObject private var moduleViewModel: ModuleViewModel

    let dayOfWeek: Int
    let durationWeeks: Int
    @Binding var workoutSlots: [ProgramWorkoutSlot]
    @Binding var moduleSlots: [ProgramSlot]

    @State private var contentType: SlotContentType = .workout
    @State private var selectedWorkout: Workout?
    @State private var selectedModule: Module?
    @State private var scheduleType: SlotScheduleType = .weekly
    @State private var specificWeek: Int = 1

    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private var availableWorkouts: [Workout] {
        workoutViewModel.workouts.filter { !$0.archived }
    }

    private var availableModules: [Module] {
        moduleViewModel.modules
    }

    private var canAdd: Bool {
        switch contentType {
        case .workout:
            return selectedWorkout != nil
        case .module:
            return selectedModule != nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Day indicator
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(AppColors.programAccent)
                        Text(dayNames[dayOfWeek])
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.programAccent.opacity(0.1))
                    )

                    // Content type picker
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Add")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: AppSpacing.sm) {
                            TypeButton(
                                title: "Workout",
                                icon: "figure.run",
                                isSelected: contentType == .workout,
                                color: AppColors.dominant
                            ) {
                                contentType = .workout
                                selectedModule = nil
                            }

                            TypeButton(
                                title: "Module",
                                icon: "square.stack.3d.up",
                                isSelected: contentType == .module,
                                color: AppColors.accent3
                            ) {
                                contentType = .module
                                selectedWorkout = nil
                            }
                        }
                    }

                    // Schedule type
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Frequency")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: AppSpacing.sm) {
                            FrequencyButton(
                                title: "Every Week",
                                isSelected: scheduleType == .weekly
                            ) {
                                scheduleType = .weekly
                            }

                            FrequencyButton(
                                title: "Specific Week",
                                isSelected: scheduleType == .specificWeek
                            ) {
                                scheduleType = .specificWeek
                            }
                        }

                        if scheduleType == .specificWeek {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(1...durationWeeks, id: \.self) { week in
                                        WeekChip(
                                            week: week,
                                            isSelected: specificWeek == week
                                        ) {
                                            specificWeek = week
                                        }
                                    }
                                }
                            }
                            .padding(.top, AppSpacing.xs)
                        }
                    }

                    // Content selection
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Select \(contentType.rawValue)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)

                        if contentType == .workout {
                            workoutSelectionList
                        } else {
                            moduleSelectionList
                        }
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Add to Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSlot()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }

    private var workoutSelectionList: some View {
        VStack(spacing: AppSpacing.sm) {
            if availableWorkouts.isEmpty {
                emptyState(message: "No workouts created yet")
            } else {
                ForEach(availableWorkouts) { workout in
                    SelectionRow(
                        title: workout.name,
                        subtitle: "\(workout.moduleReferences.count) modules",
                        icon: "figure.run",
                        color: AppColors.dominant,
                        isSelected: selectedWorkout?.id == workout.id
                    ) {
                        selectedWorkout = workout
                    }
                }
            }
        }
    }

    private var moduleSelectionList: some View {
        VStack(spacing: AppSpacing.sm) {
            if availableModules.isEmpty {
                emptyState(message: "No modules created yet")
            } else {
                ForEach(availableModules) { module in
                    SelectionRow(
                        title: module.name,
                        subtitle: "\(module.exerciseCount) exercises",
                        icon: module.type.icon,
                        color: module.type.color,
                        isSelected: selectedModule?.id == module.id
                    ) {
                        selectedModule = module
                    }
                }
            }
        }
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(AppColors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xl)
    }

    private func addSlot() {
        switch contentType {
        case .workout:
            guard let workout = selectedWorkout else { return }
            let slot = ProgramWorkoutSlot(
                workoutId: workout.id,
                workoutName: workout.name,
                scheduleType: scheduleType,
                dayOfWeek: dayOfWeek,
                weekNumber: scheduleType == .specificWeek ? specificWeek : nil
            )
            workoutSlots.append(slot)
        case .module:
            guard let module = selectedModule else { return }
            let slot = ProgramSlot(
                content: .module(id: module.id, name: module.name, type: module.type),
                scheduleType: scheduleType,
                dayOfWeek: dayOfWeek,
                weekNumber: scheduleType == .specificWeek ? specificWeek : nil
            )
            moduleSlots.append(slot)
        }
        dismiss()
    }
}

// MARK: - Helper Views

private struct TypeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? color : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isSelected ? color.opacity(0.15) : AppColors.surfaceTertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .stroke(isSelected ? color.opacity(0.4) : AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FrequencyButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? AppColors.programAccent : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(isSelected ? AppColors.programAccent.opacity(0.15) : AppColors.surfaceTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .stroke(isSelected ? AppColors.programAccent.opacity(0.4) : AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct WeekChip: View {
    let week: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Week \(week)")
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? AppColors.programAccent : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.programAccent.opacity(0.2) : AppColors.surfaceTertiary)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? AppColors.programAccent.opacity(0.5) : AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SelectionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textPrimary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.programAccent)
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isSelected ? AppColors.programAccent.opacity(0.1) : AppColors.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .stroke(isSelected ? AppColors.programAccent.opacity(0.4) : AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let workoutVM = WorkoutViewModel()
    return NavigationStack {
        ProgramFormView(program: nil)
    }
    .environmentObject(ProgramViewModel(workoutViewModel: workoutVM))
    .environmentObject(workoutVM)
    .environmentObject(ModuleViewModel())
}
