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
                            ForEach(filteredModules) { module in
                                NavigationLink(destination: ModuleDetailView(module: module)) {
                                    ModuleListCard(module: module)
                                }
                                .buttonStyle(.plain)
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
                    }
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Modules")
            .searchable(text: $searchText, prompt: "Search modules")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddModule = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.accentBlue)
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
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var color: Color = AppColors.accentBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.2) : AppColors.cardBackground)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? color.opacity(0.5) : AppColors.border.opacity(0.5), lineWidth: 1)
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

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.moduleColor(module.type).opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: module.type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.moduleColor(module.type))
            }

            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(module.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: AppSpacing.sm) {
                    // Type badge
                    Text(module.type.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.moduleColor(module.type))
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(AppColors.moduleColor(module.type).opacity(0.15))
                        )

                    // Exercise count
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10))
                        Text("\(module.exercises.count)")
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                    // Duration
                    if let duration = module.estimatedDuration {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(duration)m")
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.moduleColor(module.type).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ModulesListView()
        .environmentObject(ModuleViewModel())
}
