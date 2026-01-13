//
//  ModulesListView.swift
//  gym app
//
//  List of all modules organized by type
//

import SwiftUI

struct ModulesListView: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @State private var showingAddModule = false
    @State private var searchText = ""
    @State private var selectedType: ModuleType?

    var filteredModules: [Module] {
        var modules = moduleViewModel.modules

        if let type = selectedType {
            modules = modules.filter { $0.type == type }
        }

        if !searchText.isEmpty {
            modules = modules.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return modules
    }

    var body: some View {
        NavigationStack {
            List {
                // Type filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(title: "All", isSelected: selectedType == nil) {
                            selectedType = nil
                        }

                        ForEach(ModuleType.allCases) { type in
                            FilterPill(
                                title: type.displayName,
                                isSelected: selectedType == type,
                                color: Color(type.color)
                            ) {
                                selectedType = type
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if filteredModules.isEmpty {
                    ContentUnavailableView(
                        "No Modules",
                        systemImage: "square.stack.3d.up",
                        description: Text("Create a module to organize your exercises")
                    )
                } else {
                    ForEach(filteredModules) { module in
                        NavigationLink(destination: ModuleDetailView(module: module)) {
                            ModuleRow(module: module)
                        }
                    }
                    .onDelete { offsets in
                        let modulesToDelete = offsets.map { filteredModules[$0] }
                        for module in modulesToDelete {
                            moduleViewModel.deleteModule(module)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Modules")
            .searchable(text: $searchText, prompt: "Search modules")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddModule = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddModule) {
                NavigationStack {
                    ModuleFormView(module: nil)
                }
            }
            .refreshable {
                moduleViewModel.loadModules()
            }
        }
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color.opacity(0.2) : Color(.systemGray5))
                .foregroundStyle(isSelected ? color : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ModuleRow: View {
    let module: Module

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: module.type.icon)
                .font(.title2)
                .foregroundStyle(Color(module.type.color))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(module.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(module.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(module.type.color).opacity(0.2))
                        .clipShape(Capsule())

                    Text("\(module.exercises.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let duration = module.estimatedDuration {
                        Text("\(duration) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ModulesListView()
        .environmentObject(ModuleViewModel())
}
