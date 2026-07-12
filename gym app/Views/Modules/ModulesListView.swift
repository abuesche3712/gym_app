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
    @State private var navigateToModule: Module?
    @State private var editingModule: Module?
    @State private var modulePendingDelete: Module?

    // Selection mode support for share flow
    var selectionMode: ViewSelectionMode? = nil
    var onSelectForShare: ((Module) -> Void)? = nil

    private var isSelectionMode: Bool { selectionMode != nil }

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
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Custom header
                modulesHeader
                    .padding(.horizontal, AppSpacing.screenPadding)

                // Type filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        FilterPill(title: "All", isSelected: selectedType == nil) {
                            withAnimation(AppAnimation.quick) {
                                selectedType = nil
                            }
                        }

                        ForEach(ModuleType.allCases) { type in
                            FilterPill(
                                title: type.displayName,
                                isSelected: selectedType == type,
                                tint: AppColors.moduleColor(type)
                            ) {
                                withAnimation(AppAnimation.quick) {
                                    selectedType = type
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }

                // Modules list
                if filteredModules.isEmpty {
                    Group {
                        if moduleViewModel.modules.isEmpty {
                            EmptyStateView(
                                icon: "square.stack.3d.up",
                                title: "No Modules",
                                subtitle: "Create a module to organize your exercises",
                                buttonTitle: "Create Module",
                                onButtonTap: {
                                    showingAddModule = true
                                }
                            )
                        } else {
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: "No Matches",
                                subtitle: "Try a different search or filter"
                            )
                        }
                    }
                    .padding(.top, AppSpacing.xxl)
                } else {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(filteredModules) { module in
                            if isSelectionMode {
                                Button {
                                    onSelectForShare?(module)
                                } label: {
                                    ModuleListCard(module: module, showExercises: selectedType != nil, showShareIcon: true)
                                }
                                .buttonStyle(.pressable)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity
                                ))
                                .animation(AppMotion.reveal, value: filteredModules.count)
                            } else {
                                Button {
                                    editingModule = module
                                } label: {
                                    ModuleListCard(module: module, showExercises: selectedType != nil)
                                }
                                .buttonStyle(.pressable)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity
                                ))
                                .animation(AppMotion.reveal, value: filteredModules.count)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        modulePendingDelete = module
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .animation(AppMotion.reveal, value: filteredModules.count)
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search modules")
        .toolbar {
            if !isSelectionMode {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddModule = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .displaySmall(color: AppColors.dominant)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .sheet(isPresented: $showingAddModule) {
            NavigationStack {
                ModuleFormView(module: nil) { createdModule in
                    navigateToModule = createdModule
                }
            }
        }
        .navigationDestination(item: $navigateToModule) { module in
            ModuleDetailView(module: module)
        }
        .sheet(item: $editingModule) { module in
            NavigationStack {
                ModuleFormView(module: module)
            }
        }
        .confirmationDialog(
            "Delete Module",
            isPresented: Binding(
                get: { modulePendingDelete != nil },
                set: { if !$0 { modulePendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: modulePendingDelete
        ) { module in
            Button("Delete \"\(module.name)\"", role: .destructive) {
                HapticManager.shared.warning()
                moduleViewModel.deleteModule(module)
                modulePendingDelete = nil
            }
        } message: { module in
            Text("This will permanently delete \"\(module.name)\". This action cannot be undone.")
        }
        .refreshable {
            moduleViewModel.loadModules()
        }
    }

    // MARK: - Header

    private var modulesHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Title section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MODULES")
                        .elegantLabel(color: AppColors.accent3)

                    Text("Your Modules")
                        .displayMedium(color: AppColors.textPrimary)
                }

                Spacer()

                // Count badge
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up")
                        .caption(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                    Text("\(moduleViewModel.modules.count) total")
                        .subheadline(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                }
            }

            // Accent line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent3.opacity(0.6), AppColors.accent3.opacity(0.1), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
    }
}

// MARK: - Filter Pill

// MARK: - Module List Card

struct ModuleListCard: View {
    let module: Module
    var showExercises: Bool = false
    var showShareIcon: Bool = false

    private var moduleColor: Color {
        AppColors.moduleColor(module.type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: AppSpacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(moduleColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: module.type.icon)
                        .displaySmall(color: moduleColor)
                }

                // Content
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(module.name)
                            .headline(color: AppColors.textPrimary)

                        // Type badge
                        Text(module.type.displayName)
                            .caption2(color: moduleColor)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(moduleColor.opacity(0.12))
                            )
                    }

                    HStack(spacing: AppSpacing.md) {
                        Label("\(module.exercises.count) exercises", systemImage: "list.bullet")
                            .subheadline(color: AppColors.textSecondary)

                        if let duration = module.estimatedDuration {
                            Label("\(duration)m", systemImage: "clock")
                                .subheadline(color: AppColors.textSecondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: showShareIcon ? "square.and.arrow.up" : "chevron.right")
                    .subheadline(color: showShareIcon ? AppColors.dominant : AppColors.textTertiary)
            }
            .padding(AppSpacing.cardPadding)

            // Exercise list (only when filtered to specific type)
            if showExercises && !module.exercises.isEmpty {
                Divider()
                    .background(AppColors.surfaceTertiary.opacity(0.3))
                    .padding(.horizontal, AppSpacing.cardPadding)

                let resolvedExercises = module.resolvedExercises()
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(Array(resolvedExercises.prefix(5))) { exercise in
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: exercise.exerciseType.icon)
                                .caption(color: moduleColor)
                                .frame(width: 20)

                            Text(exercise.name)
                                .subheadline(color: AppColors.textSecondary)
                                .lineLimit(1)

                            Spacer()

                            if !exercise.formattedSetScheme.isEmpty {
                                Text(exercise.formattedSetScheme)
                                    .caption(color: AppColors.textTertiary)
                            }
                        }
                    }

                    if module.exercises.count > 5 {
                        Text("+\(module.exercises.count - 5) more")
                            .caption(color: moduleColor)
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.sm)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(
                    LinearGradient(
                        colors: [moduleColor.opacity(0.4), moduleColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    NavigationStack {
        ModulesListView()
    }
    .environmentObject(ModuleViewModel())
}
