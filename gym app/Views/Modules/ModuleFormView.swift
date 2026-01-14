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

    var body: some View {
        Form {
            Section("Module Info") {
                TextField("Name", text: $name)

                Picker("Type", selection: $type) {
                    ForEach(ModuleType.allCases) { moduleType in
                        Label(moduleType.displayName, systemImage: moduleType.icon)
                            .tag(moduleType)
                    }
                }

                TextField("Estimated Duration (minutes)", text: $estimatedDuration)
                    .keyboardType(.numberPad)
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }

            if isEditing {
                Section {
                    NavigationLink("Manage Exercises") {
                        if let module = module {
                            ModuleDetailView(module: module)
                        }
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Module" : "New Module")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveModule()
                }
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
