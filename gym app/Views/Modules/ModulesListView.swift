//
//  ModulesListView.swift
//  gym app
//
//  List of all modules organized by type
//

import SwiftUI

struct ModulesListView: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddModule = false
    @State private var searchText = ""
    @State private var selectedType: ModuleType?
    @State private var navigateToModule: Module?

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
                                    color: AppColors.moduleColor(type)
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
                        EmptyStateView(
                            icon: "square.stack.3d.up",
                            title: "No Modules",
                            message: "Create a module to organize your exercises",
                            buttonTitle: "Create Module"
                        ) {
                            showingAddModule = true
                        }
                        .padding(.top, AppSpacing.xxl)
                    } else {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(Array(filteredModules.enumerated()), id: \.element.id) { index, module in
                                NavigationLink(destination: ModuleDetailView(module: module)) {
                                    ModuleListCard(module: module, showExercises: selectedType != nil)
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity
                                ))
                                .animation(
                                    .spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * 0.04),
                                    value: filteredModules.count
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        moduleViewModel.deleteModule(module)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .animation(.easeInOut(duration: 0.3), value: filteredModules.count)
                    }
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search modules")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddModule = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.dominant)
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
            .refreshable {
                moduleViewModel.loadModules()
            }
        }
    }

    // MARK: - Header

    private var modulesHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Navigation row with circular back and plus buttons
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(AppColors.accent1)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppColors.accent1.opacity(0.1))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.accent1.opacity(0.2), lineWidth: 1)
                        )
                }

                Spacer()

                Button {
                    showingAddModule = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundColor(AppColors.accent1)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppColors.accent1.opacity(0.1))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.accent1.opacity(0.2), lineWidth: 1)
                        )
                }
            }

            // Title section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MODULES")
                        .elegantLabel(color: AppColors.accent1)

                    Text("Your Modules")
                        .font(.title)
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                // Count badge
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.caption.weight(.medium))
                    Text("\(moduleViewModel.modules.count) total")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(AppColors.textSecondary)
            }

            // Accent line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent1.opacity(0.6), AppColors.accent1.opacity(0.1), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var color: Color = AppColors.dominant
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.2) : AppColors.surfacePrimary)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? color.opacity(0.5) : AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? color : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Module List Card

struct ModuleListCard: View {
    let module: Module
    var showExercises: Bool = false

    private var moduleColor: Color {
        AppColors.moduleColor(module.type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: AppSpacing.md) {
                // Icon with gradient background (matches BuilderCard style)
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [moduleColor.opacity(0.12), moduleColor.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(moduleColor.opacity(0.15), lineWidth: 0.5)
                        )

                    Image(systemName: module.type.icon)
                        .font(.title3)
                        .foregroundColor(moduleColor.opacity(0.8))
                }

                // Content
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(module.name)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        // Type badge
                        Text(module.type.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(moduleColor.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(moduleColor.opacity(0.08))
                            )
                    }

                    HStack(spacing: AppSpacing.md) {
                        Label("\(module.exercises.count) exercises", systemImage: "list.bullet")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        if let duration = module.estimatedDuration {
                            Label("\(duration)m", systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textTertiary)
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
                                .font(.caption)
                                .foregroundColor(moduleColor)
                                .frame(width: 20)

                            Text(exercise.name)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)

                            Spacer()

                            if !exercise.formattedSetScheme.isEmpty {
                                Text(exercise.formattedSetScheme)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }

                    if module.exercises.count > 5 {
                        Text("+\(module.exercises.count - 5) more")
                            .font(.caption)
                            .foregroundColor(moduleColor)
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.sm)
            }
        }
        .gradientCard(accent: moduleColor, padding: 0)
    }
}

#Preview {
    ModulesListView()
        .environmentObject(ModuleViewModel())
}
