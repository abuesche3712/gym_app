//
//  EquipmentLibraryView.swift
//  gym app
//
//  Equipment library management - extracted from ExerciseLibraryView
//

import SwiftUI

// MARK: - Equipment Library View

struct EquipmentLibraryView: View {
    @StateObject private var libraryService = LibraryService.shared
    @State private var searchText = ""
    @State private var selectedSource: EquipmentSource = .all
    @State private var showingAddEquipment = false
    @State private var equipmentToView: ImplementEntity? = nil

    enum EquipmentSource {
        case all, provided, custom
    }

    private var providedEquipment: [ImplementEntity] {
        libraryService.implements.filter { !$0.isCustom }
    }

    private var customEquipment: [ImplementEntity] {
        libraryService.implements.filter { $0.isCustom }
    }

    private var filteredEquipment: [ImplementEntity] {
        var equipment: [ImplementEntity]

        switch selectedSource {
        case .all:
            equipment = libraryService.implements
        case .provided:
            equipment = providedEquipment
        case .custom:
            equipment = customEquipment
        }

        if !searchText.isEmpty {
            equipment = equipment.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return equipment.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textTertiary)
                    TextField("Search equipment", text: $searchText)
                        .font(.body)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfacePrimary)
                )

                // Stats - clickable source filters
                HStack(spacing: AppSpacing.sm) {
                    EquipmentSourceFilterPill(
                        value: "\(providedEquipment.count)",
                        label: "Provided",
                        isSelected: selectedSource == .provided,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSource = selectedSource == .provided ? .all : .provided
                            }
                        }
                    )
                    EquipmentSourceFilterPill(
                        value: "\(customEquipment.count)",
                        label: "Custom",
                        isSelected: selectedSource == .custom,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSource = selectedSource == .custom ? .all : .custom
                            }
                        }
                    )
                    EquipmentStatPill(
                        value: "\(filteredEquipment.count)",
                        label: "Showing"
                    )
                }

                // Equipment list
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(filteredEquipment, id: \.id) { equipment in
                        EquipmentLibraryRow(
                            equipment: equipment,
                            onTap: {
                                equipmentToView = equipment
                            },
                            onDelete: equipment.isCustom ? {
                                deleteEquipment(equipment)
                            } : nil
                        )
                    }
                }

                if filteredEquipment.isEmpty {
                    ContentUnavailableView(
                        "No Equipment",
                        systemImage: "dumbbell",
                        description: Text(searchText.isEmpty ? "Add custom equipment to get started" : "No equipment matches your search")
                    )
                    .padding(.top, AppSpacing.xl)
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Equipment Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddEquipment = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(AppColors.dominant)
                }
            }
        }
        .sheet(isPresented: $showingAddEquipment) {
            AddEquipmentSheet()
        }
        .sheet(item: $equipmentToView) { equipment in
            EquipmentDetailSheet(equipment: equipment)
        }
    }

    private func deleteEquipment(_ equipment: ImplementEntity) {
        let context = PersistenceController.shared.container.viewContext
        context.delete(equipment)
        PersistenceController.shared.save()
        libraryService.loadData()
    }
}

// MARK: - Equipment Stat Pill

private struct EquipmentStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .displaySmall(color: AppColors.textPrimary)
                .fontWeight(.bold)
            Text(label)
                .caption(color: AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
        )
    }
}

// MARK: - Equipment Source Filter Pill

private struct EquipmentSourceFilterPill: View {
    let value: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Equipment Row

private struct EquipmentLibraryRow: View {
    let equipment: ImplementEntity
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Icon
                Image(systemName: iconForEquipment(equipment.name))
                    .font(.title2)
                    .foregroundColor(AppColors.dominant)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(equipment.name)
                            .font(.body.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)

                        if equipment.isCustom {
                            Text("Custom")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(AppColors.accent1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppColors.accent1.opacity(0.12))
                                )
                        }
                    }

                    // Show measurables summary
                    Text(measurablesSummary)
                        .caption(color: AppColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .caption(color: AppColors.textTertiary)
                    .fontWeight(.semibold)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.surfacePrimary)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var measurablesSummary: String {
        let measurables = equipment.measurableArray
        if measurables.isEmpty {
            return "No measurables"
        }

        var seen: Set<String> = []
        var parts: [String] = []

        for m in measurables {
            if !seen.contains(m.name) {
                seen.insert(m.name)
                if m.isStringBased {
                    parts.append(m.name)
                } else {
                    let units = measurables.filter { $0.name == m.name }.map { $0.unit }.joined(separator: "/")
                    parts.append("\(m.name) (\(units))")
                }
            }
        }

        return parts.joined(separator: " • ")
    }

    private func iconForEquipment(_ name: String) -> String {
        EquipmentIconMapper.icon(for: name)
    }
}

// MARK: - Equipment Icon Mapper

enum EquipmentIconMapper {
    static func icon(for name: String) -> String {
        switch name.lowercased() {
        case "barbell": return "figure.strengthtraining.traditional"
        case "dumbbell": return "dumbbell.fill"
        case "cable": return "cable.connector"
        case "machine": return "gearshape.fill"
        case "kettlebell": return "figure.strengthtraining.functional"
        case "box": return "cube.fill"
        case "band": return "circle.dotted"
        case "bodyweight": return "figure.stand"
        default: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Equipment Detail Sheet

private struct EquipmentDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var libraryService = LibraryService.shared
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared

    let equipment: ImplementEntity

    @State private var measurables: [MeasurableData]
    @State private var showingAddMeasurable = false

    struct MeasurableData: Identifiable {
        let id: UUID
        var name: String
        var units: [String]
        var isStringBased: Bool
    }

    /// All exercises that use this equipment (not tracked in simplified model)
    private var exercisesUsingEquipment: [ExerciseTemplate] {
        // Equipment-exercise linking has been simplified
        return []
    }

    init(equipment: ImplementEntity) {
        self.equipment = equipment

        var grouped: [String: MeasurableData] = [:]
        for m in equipment.measurableArray {
            if var existing = grouped[m.name] {
                if !m.unit.isEmpty && !existing.units.contains(m.unit) {
                    existing.units.append(m.unit)
                    grouped[m.name] = existing
                }
            } else {
                grouped[m.name] = MeasurableData(
                    id: m.id,
                    name: m.name,
                    units: m.unit.isEmpty ? [] : [m.unit],
                    isStringBased: m.isStringBased
                )
            }
        }
        _measurables = State(initialValue: Array(grouped.values).sorted { $0.name < $1.name })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: EquipmentIconMapper.icon(for: equipment.name))
                            .font(.largeTitle)
                            .foregroundColor(AppColors.dominant)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(equipment.name)
                                .font(.title2.bold())

                            if equipment.isCustom {
                                Text("Custom Equipment")
                                    .font(.caption)
                                    .foregroundColor(AppColors.accent1)
                            } else {
                                Text("Provided Equipment")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    if measurables.isEmpty {
                        Text("No measurables defined")
                            .foregroundColor(AppColors.textTertiary)
                    } else {
                        ForEach(measurables) { measurable in
                            EquipmentMeasurableRow(measurable: measurable)
                        }
                    }

                    if equipment.isCustom {
                        Button {
                            showingAddMeasurable = true
                        } label: {
                            Label("Add Measurable", systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text("Measurables")
                } footer: {
                    Text("Measurables define what you track when using this equipment (e.g., weight, height, color)")
                }

                // Used in Exercises section
                Section {
                    if exercisesUsingEquipment.isEmpty {
                        Text("No exercises use this equipment")
                            .foregroundColor(AppColors.textTertiary)
                    } else {
                        ForEach(exercisesUsingEquipment) { exercise in
                            HStack(spacing: AppSpacing.sm) {
                                Circle()
                                    .fill(exerciseTypeColor(exercise.exerciseType))
                                    .frame(width: 8, height: 8)

                                Text(exercise.name)
                                    .font(.body)
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                Text(exercise.exerciseType.displayName)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Used in Exercises")
                        Spacer()
                        Text("\(exercisesUsingEquipment.count)")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Equipment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.dominant)
                }
            }
            .sheet(isPresented: $showingAddMeasurable) {
                AddMeasurableToEquipmentSheet(equipment: equipment) {
                    libraryService.loadData()
                    dismiss()
                }
            }
        }
    }

    private func exerciseTypeColor(_ type: ExerciseType) -> Color {
        switch type {
        case .strength: return AppColors.dominant
        case .cardio: return AppColors.warning
        case .mobility: return AppColors.accent1
        case .isometric: return AppColors.dominant
        case .explosive: return Color(hex: "FF8C42")
        case .recovery: return AppColors.accent1
        }
    }
}

// MARK: - Equipment Measurable Row

private struct EquipmentMeasurableRow: View {
    let measurable: EquipmentDetailSheet.MeasurableData

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(measurable.name)
                    .font(.body.weight(.medium))

                if measurable.isStringBased {
                    Text("Text-based (e.g., color, resistance level)")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                } else if !measurable.units.isEmpty {
                    HStack(spacing: 4) {
                        Text("Units:")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)

                        ForEach(measurable.units, id: \.self) { unit in
                            Text(unit)
                                .font(.caption.weight(.medium))
                                .foregroundColor(AppColors.dominant)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppColors.dominant.opacity(0.1))
                                )
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: measurable.isStringBased ? "textformat" : "number")
                .foregroundColor(AppColors.textTertiary)
        }
    }
}

// MARK: - Add Equipment Sheet

private struct AddEquipmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var libraryService = LibraryService.shared

    @State private var name = ""
    @State private var measurables: [NewEquipmentMeasurable] = []
    @State private var showingAddMeasurable = false

    struct NewEquipmentMeasurable: Identifiable {
        let id = UUID()
        var name: String
        var units: [String]
        var isStringBased: Bool
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Equipment Name") {
                    TextField("e.g., Trap Bar, Landmine, TRX", text: $name)
                }

                Section {
                    if measurables.isEmpty {
                        Text("No measurables added")
                            .foregroundColor(AppColors.textTertiary)
                    } else {
                        ForEach(measurables) { measurable in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(measurable.name)
                                        .font(.body.weight(.medium))
                                    if measurable.isStringBased {
                                        Text("Text-based")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textTertiary)
                                    } else {
                                        Text("Units: \(measurable.units.joined(separator: ", "))")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .onDelete { indexSet in
                            measurables.remove(atOffsets: indexSet)
                        }
                    }

                    Button {
                        showingAddMeasurable = true
                    } label: {
                        Label("Add Measurable", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Measurables")
                } footer: {
                    Text("Define what you want to track when using this equipment")
                }
            }
            .navigationTitle("Add Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEquipment()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingAddMeasurable) {
                NewEquipmentMeasurableSheet { measurable in
                    measurables.append(measurable)
                }
            }
        }
    }

    private func saveEquipment() {
        let context = PersistenceController.shared.container.viewContext

        let equipment = ImplementEntity(context: context)
        equipment.id = UUID()
        equipment.name = name.trimmingCharacters(in: .whitespaces)
        equipment.isCustom = true

        for m in measurables {
            if m.isStringBased {
                let measurable = MeasurableEntity(context: context)
                measurable.id = UUID()
                measurable.name = m.name
                measurable.unit = ""
                measurable.isStringBased = true
                measurable.hasDefaultValue = false
                measurable.implement = equipment
            } else {
                for unit in m.units {
                    let measurable = MeasurableEntity(context: context)
                    measurable.id = UUID()
                    measurable.name = m.name
                    measurable.unit = unit
                    measurable.isStringBased = false
                    measurable.hasDefaultValue = false
                    measurable.implement = equipment
                }
            }
        }

        PersistenceController.shared.save()
        libraryService.loadData()
        dismiss()
    }
}

// MARK: - New Equipment Measurable Sheet

private struct NewEquipmentMeasurableSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (AddEquipmentSheet.NewEquipmentMeasurable) -> Void

    @State private var name = ""
    @State private var isStringBased = false
    @State private var units: [String] = [""]

    private let commonMeasurables = [
        ("Weight", ["lbs", "kg"]),
        ("Height", ["in", "cm"]),
        ("Length", ["in", "cm", "ft"]),
        ("Resistance", ["lbs", "kg"]),
        ("Incline", ["°", "%"]),
        ("Speed", ["mph", "km/h"]),
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (isStringBased || units.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurable Name") {
                    TextField("e.g., Weight, Height, Color", text: $name)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonMeasurables, id: \.0) { measurable in
                                Button {
                                    name = measurable.0
                                    isStringBased = false
                                    units = measurable.1
                                } label: {
                                    Text(measurable.0)
                                        .font(.caption)
                                        .foregroundColor(name == measurable.0 ? .white : AppColors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(name == measurable.0 ? AppColors.dominant : AppColors.surfaceTertiary)
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                name = "Color"
                                isStringBased = true
                                units = []
                            } label: {
                                Text("Color")
                                    .font(.caption)
                                    .foregroundColor(name == "Color" && isStringBased ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(name == "Color" && isStringBased ? AppColors.dominant : AppColors.surfaceTertiary)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section("Type") {
                    Picker("Type", selection: $isStringBased) {
                        Text("Numeric").tag(false)
                        Text("Text-based").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                if !isStringBased {
                    Section {
                        ForEach(units.indices, id: \.self) { index in
                            HStack {
                                TextField("Unit (e.g., lbs, in)", text: $units[index])
                                if units.count > 1 {
                                    Button {
                                        units.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(AppColors.error)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button {
                            units.append("")
                        } label: {
                            Label("Add Unit", systemImage: "plus.circle")
                        }
                    } header: {
                        Text("Units")
                    } footer: {
                        Text("Add multiple units if you want to track in different measurement systems (e.g., lbs and kg)")
                    }
                }
            }
            .navigationTitle("Add Measurable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let filteredUnits = units.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        onSave(AddEquipmentSheet.NewEquipmentMeasurable(
                            name: name.trimmingCharacters(in: .whitespaces),
                            units: filteredUnits,
                            isStringBased: isStringBased
                        ))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Add Measurable to Existing Equipment Sheet

private struct AddMeasurableToEquipmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let equipment: ImplementEntity
    let onSave: () -> Void

    @State private var name = ""
    @State private var isStringBased = false
    @State private var units: [String] = [""]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (isStringBased || units.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurable Name") {
                    TextField("e.g., Weight, Height, Color", text: $name)
                }

                Section("Type") {
                    Picker("Type", selection: $isStringBased) {
                        Text("Numeric").tag(false)
                        Text("Text-based").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                if !isStringBased {
                    Section("Units") {
                        ForEach(units.indices, id: \.self) { index in
                            HStack {
                                TextField("Unit (e.g., lbs, in)", text: $units[index])
                                if units.count > 1 {
                                    Button {
                                        units.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(AppColors.error)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button {
                            units.append("")
                        } label: {
                            Label("Add Unit", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Add Measurable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMeasurable()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func saveMeasurable() {
        let context = PersistenceController.shared.container.viewContext

        if isStringBased {
            let measurable = MeasurableEntity(context: context)
            measurable.id = UUID()
            measurable.name = name.trimmingCharacters(in: .whitespaces)
            measurable.unit = ""
            measurable.isStringBased = true
            measurable.hasDefaultValue = false
            measurable.implement = equipment
        } else {
            let filteredUnits = units.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            for unit in filteredUnits {
                let measurable = MeasurableEntity(context: context)
                measurable.id = UUID()
                measurable.name = name.trimmingCharacters(in: .whitespaces)
                measurable.unit = unit
                measurable.isStringBased = false
                measurable.hasDefaultValue = false
                measurable.implement = equipment
            }
        }

        PersistenceController.shared.save()
        onSave()
    }
}

#Preview {
    NavigationStack {
        EquipmentLibraryView()
    }
}
