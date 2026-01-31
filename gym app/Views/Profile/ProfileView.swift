//
//  ProfileView.swift
//  gym app
//
//  Displays the user's profile with today's workout badge and settings
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var profileRepository: ProfileRepository
    @ObservedObject var dataRepository: DataRepository
    @State private var showingEditProfile = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Profile Header
                    profileHeader

                    // Today's Workout Badge (if completed today)
                    if let todaysWorkout = todaysCompletedWorkout {
                        TodaysWorkoutBadge(session: todaysWorkout)
                    }

                    // Stats Summary
                    statsSection

                    // Quick Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                ProfileEditView(profileRepository: profileRepository)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: AppSpacing.md) {
            // Avatar placeholder
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay {
                    Text(avatarInitials)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }

            // Name and username
            VStack(spacing: AppSpacing.xs) {
                if let displayName = profileRepository.currentProfile?.displayName,
                   !displayName.isEmpty {
                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                if let username = profileRepository.currentProfile?.username,
                   !username.isEmpty {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Bio
            if let bio = profileRepository.currentProfile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Edit button
            Button {
                showingEditProfile = true
            } label: {
                Text("Edit Profile")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical)
    }

    private var avatarInitials: String {
        if let displayName = profileRepository.currentProfile?.displayName,
           !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        } else if let username = profileRepository.currentProfile?.username,
                  !username.isEmpty {
            return String(username.prefix(2)).uppercased()
        }
        return "?"
    }

    // MARK: - Today's Workout

    private var todaysCompletedWorkout: Session? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return dataRepository.sessions.first { session in
            calendar.isDate(session.date, inSameDayAs: today)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Stats")
                .font(.headline)

            HStack(spacing: AppSpacing.md) {
                statCard(
                    title: "Workouts",
                    value: "\(dataRepository.sessions.count)",
                    icon: "dumbbell"
                )

                statCard(
                    title: "This Week",
                    value: "\(workoutsThisWeek)",
                    icon: "calendar"
                )

                statCard(
                    title: "Streak",
                    value: "\(currentStreak)",
                    icon: "flame"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return dataRepository.sessions.filter { $0.date >= startOfWeek }.count
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()

        // Check if we worked out today
        let hasWorkoutToday = dataRepository.sessions.contains { session in
            calendar.isDate(session.date, inSameDayAs: checkDate)
        }

        if !hasWorkoutToday {
            // Start checking from yesterday
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Count consecutive days
        while true {
            let hasWorkout = dataRepository.sessions.contains { session in
                calendar.isDate(session.date, inSameDayAs: checkDate)
            }

            if hasWorkout {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }

            // Safety limit
            if streak > 365 { break }
        }

        return streak
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Quick Actions")
                .font(.headline)

            VStack(spacing: AppSpacing.xs) {
                actionRow(
                    title: "Workout History",
                    icon: "clock.arrow.circlepath",
                    destination: AnyView(Text("History"))
                )

                actionRow(
                    title: "Personal Records",
                    icon: "trophy",
                    destination: AnyView(Text("PRs"))
                )

                actionRow(
                    title: "Export Data",
                    icon: "square.and.arrow.up",
                    destination: AnyView(Text("Export"))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionRow(title: String, icon: String, destination: AnyView) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(Color.accentColor)

                Text(title)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today's Workout Badge

struct TodaysWorkoutBadge: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Today's Workout")
                    .font(.headline)
            }

            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(session.workoutName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: AppSpacing.sm) {
                        if let duration = session.duration {
                            Label(formatDuration(duration), systemImage: "clock")
                        }
                        if session.completedModules.count > 0 {
                            Label("\(totalExercises) exercises", systemImage: "figure.strengthtraining.traditional")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Feeling indicator if recorded
                if let feeling = session.overallFeeling, feeling > 0 {
                    VStack {
                        Text(feelingEmoji)
                            .font(.title2)
                        Text("Feeling")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
    }

    private var totalExercises: Int {
        session.completedModules.reduce(0) { $0 + $1.completedExercises.count }
    }

    private var feelingEmoji: String {
        guard let feeling = session.overallFeeling else { return "-" }
        switch feeling {
        case 1: return "1"
        case 2: return "2"
        case 3: return "3"
        case 4: return "4"
        case 5: return "5"
        default: return "-"
        }
    }
}

#Preview {
    ProfileView(
        profileRepository: ProfileRepository(persistence: .preview),
        dataRepository: DataRepository.shared
    )
}
