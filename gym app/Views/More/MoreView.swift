//
//  MoreView.swift
//  gym app
//
//  More options including Settings and History
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                // History Section
                Section {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        MoreRowView(
                            icon: "clock.arrow.circlepath",
                            iconColor: AppColors.dominant,
                            title: "History",
                            subtitle: "View past workouts"
                        )
                    }
                }

                // Settings Section
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        MoreRowView(
                            icon: "gearshape.fill",
                            iconColor: .gray,
                            title: "Settings",
                            subtitle: "App preferences"
                        )
                    }

                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        MoreRowView(
                            icon: "books.vertical.fill",
                            iconColor: AppColors.accent3,
                            title: "Exercise Library",
                            subtitle: "Browse all exercises"
                        )
                    }

                    NavigationLink {
                        EquipmentLibraryView()
                    } label: {
                        MoreRowView(
                            icon: "dumbbell.fill",
                            iconColor: AppColors.accent2,
                            title: "Equipment Library",
                            subtitle: "Manage your equipment"
                        )
                    }
                } header: {
                    Text("Settings & Libraries")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                            .body()
                        Spacer()
                        Text("1.0.0")
                            .body(color: AppColors.textSecondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("More")
        }
    }
}

// MARK: - More Row View

struct MoreRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .displaySmall(color: iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .body()

                Text(subtitle)
                    .caption()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MoreView()
}
