//
//  ModuleFormView.swift
//  gym app
//
//  Form for creating/editing a module
//

import SwiftUI

struct ModuleFormView: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss

    let module: Module?
    var onCreated: ((Module) -> Void)?

    @State private var name: String = ""
    @State private var type: ModuleType = .strength
    @State private var notes: String = ""
    @State private var estimatedDuration: String = ""

    private var isEditing: Bool { module != nil }

    private var moduleColor: Color {
        AppColors.moduleColor(type)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Module Info Section
                FormSection(title: "Module Info", icon: "square.stack.3d.up", iconColor: moduleColor) {
                    FormTextField(label: "Name", text: $name, icon: "textformat", placeholder: "e.g., Upper Body Push")
                    FormDivider()
                    typePickerRow
                    FormDivider()
                    FormTextField(label: "Duration", text: $estimatedDuration, icon: "clock", placeholder: "minutes", keyboardType: .numberPad)
                }

                // Notes Section
                FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .scrollContentBackground(.hidden)
                }

                // Manage Exercises (edit mode only)
                if isEditing {
                    FormSection(title: "Exercises", icon: "list.bullet", iconColor: moduleColor) {
                        NavigationLink {
                            if let module = module {
                                ModuleDetailView(module: module)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "dumbbell")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.textTertiary)
                                    .frame(width: 24)

                                Text("Manage Exercises")
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                if let module = module {
                                    Text("\(module.exercises.count)")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.cardBackground)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(isEditing ? "Edit Module" : "New Module")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppColors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveModule()
                }
                .fontWeight(.semibold)
                .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textTertiary : AppColors.accentBlue)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let module = module {
                name = module.name
                type = module.type
                notes = module.notes ?? ""
                if let duration = module.estimatedDuration {
                    estimatedDuration = "\(duration)"
                }
            }
        }
    }

    private var typePickerRow: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "tag")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)

            Text("Type")
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Picker("", selection: $type) {
                ForEach(ModuleType.allCases) { moduleType in
                    Label(moduleType.displayName, systemImage: moduleType.icon)
                        .tag(moduleType)
                }
            }
            .tint(moduleColor)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.cardBackground)
    }

    private func saveModule() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let duration = Int(estimatedDuration)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        if var existingModule = module {
            // Update existing module
            existingModule.name = trimmedName
            existingModule.type = type
            existingModule.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingModule.estimatedDuration = duration
            existingModule.updatedAt = Date()
            moduleViewModel.saveModule(existingModule)
            dismiss()
        } else {
            // Create new module
            let newModule = Module(
                name: trimmedName,
                type: type,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                estimatedDuration: duration
            )
            moduleViewModel.saveModule(newModule)
            dismiss()

            // Navigate to the new module for editing
            if onCreated != nil {
                onCreated?(newModule)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ModuleFormView(module: nil)
            .environmentObject(ModuleViewModel())
    }
}
