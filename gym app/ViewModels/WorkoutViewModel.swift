//
//  WorkoutViewModel.swift
//  gym app
//
//  ViewModel for managing workouts
//

import Foundation
import Combine

@MainActor
class WorkoutViewModel: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var scheduledWorkouts: [ScheduledWorkout] = []
    @Published var selectedWorkout: Workout?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: DataRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private let scheduledWorkoutsKey = "scheduledWorkouts"
    private let deletedScheduledWorkoutIdsKey = "deletedScheduledWorkoutIds"
    private var cancellables = Set<AnyCancellable>()

    // Track deleted scheduled workout IDs to prevent re-sync
    private var deletedScheduledWorkoutIds: Set<UUID> {
        get {
            let ids = UserDefaults.standard.array(forKey: deletedScheduledWorkoutIdsKey) as? [String] ?? []
            return Set(ids.compactMap { UUID(uuidString: $0) })
        }
        set {
            let ids = newValue.map { $0.uuidString }
            UserDefaults.standard.set(ids, forKey: deletedScheduledWorkoutIdsKey)
        }
    }

    init(repository: DataRepository? = nil) {
        self.repository = repository ?? DataRepository.shared
        loadWorkouts()
        loadScheduledWorkouts()
        setupSyncNotifications()
    }

    // MARK: - Sync Notifications

    private func setupSyncNotifications() {
        // Listen for scheduled workouts synced from cloud
        NotificationCenter.default.publisher(for: .scheduledWorkoutsSyncedFromCloud)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let cloudScheduled = notification.object as? [ScheduledWorkout] {
                    self?.mergeScheduledWorkoutsFromCloud(cloudScheduled)
                }
            }
            .store(in: &cancellables)

        // Listen for request to push scheduled workouts to cloud
        NotificationCenter.default.publisher(for: .requestScheduledWorkoutsForSync)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.pushScheduledWorkoutsToCloud()
                }
            }
            .store(in: &cancellables)
    }

    private func mergeScheduledWorkoutsFromCloud(_ cloudScheduled: [ScheduledWorkout]) {
        for cloudItem in cloudScheduled {
            // Skip if this scheduled workout was deleted locally
            if deletedScheduledWorkoutIds.contains(cloudItem.id) {
                Logger.verbose("Skipping '\(cloudItem.workoutName)' - was deleted locally")
                continue
            }

            if let localIndex = scheduledWorkouts.firstIndex(where: { $0.id == cloudItem.id }) {
                // Update if cloud is newer (compare by createdAt since we don't have updatedAt)
                if cloudItem.createdAt > scheduledWorkouts[localIndex].createdAt {
                    scheduledWorkouts[localIndex] = cloudItem
                }
            } else {
                // New from cloud
                scheduledWorkouts.append(cloudItem)
            }
        }
        saveScheduledWorkouts()
    }

    private func pushScheduledWorkoutsToCloud() async {
        guard authService.isAuthenticated else { return }

        for scheduled in scheduledWorkouts {
            do {
                try await firestoreService.saveScheduledWorkout(scheduled)
            } catch {
                Logger.error(error, context: "syncScheduledWorkout")
            }
        }
    }

    private func syncScheduledWorkoutToCloud(_ scheduled: ScheduledWorkout) {
        guard authService.isAuthenticated else { return }
        Task {
            do {
                try await firestoreService.saveScheduledWorkout(scheduled)
            } catch {
                Logger.error(error, context: "syncScheduledWorkoutToCloud")
            }
        }
    }

    private func queueScheduledWorkoutDeletionForCloud(_ scheduled: ScheduledWorkout) {
        guard authService.isAuthenticated else { return }
        SyncManager.shared.queueScheduledWorkout(scheduled, action: .delete)
        Logger.debug("Queued scheduled workout deletion for cloud sync")
    }

    // MARK: - Workout Operations

    func loadWorkouts() {
        isLoading = true
        repository.loadWorkouts()
        workouts = repository.workouts
        isLoading = false
    }

    func saveWorkout(_ workout: Workout) {
        repository.saveWorkout(workout)
        loadWorkouts()
    }

    func deleteWorkout(_ workout: Workout) {
        repository.deleteWorkout(workout)
        loadWorkouts()
    }

    func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            deleteWorkout(workouts[index])
        }
    }

    func createNewWorkout(name: String) -> Workout {
        Workout(name: name)
    }

    func getWorkout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    func archiveWorkout(_ workout: Workout) {
        var updated = workout
        updated.archived = true
        updated.updatedAt = Date()
        saveWorkout(updated)
    }

    // Get modules for a workout
    func getModulesForWorkout(_ workout: Workout, allModules: [Module]) -> [Module] {
        workout.moduleReferences
            .sorted { $0.order < $1.order }
            .compactMap { ref in
                allModules.first { $0.id == ref.moduleId }
            }
    }

    // Calculate estimated duration based on modules
    func calculateEstimatedDuration(_ workout: Workout, allModules: [Module]) -> Int {
        let modules = getModulesForWorkout(workout, allModules: allModules)
        return modules.compactMap { $0.estimatedDuration }.reduce(0, +)
    }

    // MARK: - Scheduled Workout Operations

    func loadScheduledWorkouts() {
        guard let data = UserDefaults.standard.data(forKey: scheduledWorkoutsKey) else {
            scheduledWorkouts = []
            return
        }

        do {
            scheduledWorkouts = try JSONDecoder().decode([ScheduledWorkout].self, from: data)
        } catch {
            Logger.error(error, context: "loadScheduledWorkouts")
            scheduledWorkouts = []
        }
    }

    private func saveScheduledWorkouts() {
        do {
            let data = try JSONEncoder().encode(scheduledWorkouts)
            UserDefaults.standard.set(data, forKey: scheduledWorkoutsKey)
        } catch {
            Logger.error(error, context: "saveScheduledWorkouts")
        }
    }

    func scheduleWorkout(_ workout: Workout, for date: Date, programId: UUID? = nil, programSlotId: UUID? = nil) {
        let scheduled = ScheduledWorkout(
            workoutId: workout.id,
            workoutName: workout.name,
            scheduledDate: date,
            programId: programId,
            programSlotId: programSlotId
        )
        scheduledWorkouts.append(scheduled)
        saveScheduledWorkouts()
        syncScheduledWorkoutToCloud(scheduled)
    }

    /// Add a scheduled workout directly (used by ProgramViewModel)
    func addScheduledWorkout(_ scheduled: ScheduledWorkout) {
        scheduledWorkouts.append(scheduled)
        saveScheduledWorkouts()
        syncScheduledWorkoutToCloud(scheduled)
    }

    func scheduleRestDay(for date: Date) {
        let scheduled = ScheduledWorkout(scheduledDate: date)
        scheduledWorkouts.append(scheduled)
        saveScheduledWorkouts()
        syncScheduledWorkoutToCloud(scheduled)
    }

    func unscheduleWorkout(_ scheduledWorkout: ScheduledWorkout) {
        scheduledWorkouts.removeAll { $0.id == scheduledWorkout.id }
        saveScheduledWorkouts()

        // Track this deletion to prevent re-sync from cloud
        var deleted = deletedScheduledWorkoutIds
        deleted.insert(scheduledWorkout.id)
        deletedScheduledWorkoutIds = deleted
        Logger.verbose("Tracked deletion of '\(scheduledWorkout.workoutName)'")

        queueScheduledWorkoutDeletionForCloud(scheduledWorkout)
    }

    /// Remove all scheduled workouts for a program
    /// If futureOnly is true, only removes workouts scheduled for today or later
    func removeScheduledWorkoutsForProgram(_ programId: UUID, futureOnly: Bool) {
        let today = Calendar.current.startOfDay(for: Date())

        let toRemove = scheduledWorkouts.filter { scheduled in
            guard scheduled.programId == programId else { return false }
            if futureOnly {
                return scheduled.scheduledDate >= today
            }
            return true
        }

        scheduledWorkouts.removeAll { scheduled in
            toRemove.contains { $0.id == scheduled.id }
        }
        saveScheduledWorkouts()

        // Track deletions to prevent re-sync from cloud
        var deleted = deletedScheduledWorkoutIds
        for scheduled in toRemove {
            deleted.insert(scheduled.id)
        }
        deletedScheduledWorkoutIds = deleted
        Logger.verbose("Tracked \(toRemove.count) scheduled workout deletions for program")

        // Queue deletions for cloud sync
        if authService.isAuthenticated {
            for scheduled in toRemove {
                SyncManager.shared.queueScheduledWorkout(scheduled, action: .delete)
            }
            Logger.debug("Queued \(toRemove.count) scheduled workout deletions for cloud sync")
        }
    }

    /// Get scheduled workouts for a specific program
    func getScheduledWorkouts(for programId: UUID) -> [ScheduledWorkout] {
        scheduledWorkouts.filter { $0.programId == programId }
    }

    func updateScheduledWorkout(_ scheduledWorkout: ScheduledWorkout) {
        if let index = scheduledWorkouts.firstIndex(where: { $0.id == scheduledWorkout.id }) {
            scheduledWorkouts[index] = scheduledWorkout
            saveScheduledWorkouts()
            syncScheduledWorkoutToCloud(scheduledWorkout)
        }
    }

    func markScheduledWorkoutCompleted(_ scheduledWorkout: ScheduledWorkout, sessionId: UUID) {
        var updated = scheduledWorkout
        updated.completedSessionId = sessionId
        updateScheduledWorkout(updated)
    }

    /// Mark any scheduled workouts for this workout on the session date as completed
    func markScheduledWorkoutsCompleted(workoutId: UUID, sessionId: UUID, sessionDate: Date) {
        let matchingScheduled = scheduledWorkouts.filter { scheduled in
            scheduled.workoutId == workoutId &&
            scheduled.completedSessionId == nil &&
            Calendar.current.isDate(scheduled.scheduledDate, inSameDayAs: sessionDate)
        }

        for scheduled in matchingScheduled {
            markScheduledWorkoutCompleted(scheduled, sessionId: sessionId)
        }
    }

    /// Get scheduled workouts for a specific date
    func getScheduledWorkouts(for date: Date) -> [ScheduledWorkout] {
        scheduledWorkouts.filter { $0.isScheduledFor(date: date) }
    }

    /// Get today's primary scheduled item (first non-completed workout or rest day)
    func getTodaySchedule() -> ScheduledWorkout? {
        let today = Date()
        let todayScheduled = getScheduledWorkouts(for: today)

        // Return first non-completed item (workout or rest)
        return todayScheduled.first { scheduled in
            if scheduled.isRestDay {
                return true  // Rest days are always "active"
            }
            return scheduled.completedSessionId == nil
        }
    }

    /// Check if today has a rest day scheduled
    func isTodayRestDay() -> Bool {
        getScheduledWorkouts(for: Date()).contains { $0.isRestDay }
    }

    /// Get scheduled workouts for a date range
    func getScheduledWorkouts(from startDate: Date, to endDate: Date) -> [ScheduledWorkout] {
        scheduledWorkouts.filter { scheduled in
            scheduled.scheduledDate >= startDate && scheduled.scheduledDate <= endDate
        }
    }

    /// Get the week containing a date (Sunday to Saturday)
    func getWeekDates(for date: Date) -> [Date] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysFromSunday = weekday - 1

        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromSunday, to: date) else {
            return []
        }

        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
}
