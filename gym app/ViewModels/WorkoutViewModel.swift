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
    private let scheduledWorkoutsKey = "scheduledWorkouts"

    init(repository: DataRepository = .shared) {
        self.repository = repository
        loadWorkouts()
        loadScheduledWorkouts()
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
            print("Error loading scheduled workouts: \(error)")
            scheduledWorkouts = []
        }
    }

    private func saveScheduledWorkouts() {
        do {
            let data = try JSONEncoder().encode(scheduledWorkouts)
            UserDefaults.standard.set(data, forKey: scheduledWorkoutsKey)
        } catch {
            print("Error saving scheduled workouts: \(error)")
        }
    }

    func scheduleWorkout(_ workout: Workout, for date: Date) {
        let scheduled = ScheduledWorkout(
            workoutId: workout.id,
            workoutName: workout.name,
            scheduledDate: date
        )
        scheduledWorkouts.append(scheduled)
        saveScheduledWorkouts()
    }

    func scheduleRestDay(for date: Date) {
        let scheduled = ScheduledWorkout(scheduledDate: date)
        scheduledWorkouts.append(scheduled)
        saveScheduledWorkouts()
    }

    func unscheduleWorkout(_ scheduledWorkout: ScheduledWorkout) {
        scheduledWorkouts.removeAll { $0.id == scheduledWorkout.id }
        saveScheduledWorkouts()
    }

    func updateScheduledWorkout(_ scheduledWorkout: ScheduledWorkout) {
        if let index = scheduledWorkouts.firstIndex(where: { $0.id == scheduledWorkout.id }) {
            scheduledWorkouts[index] = scheduledWorkout
            saveScheduledWorkouts()
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
