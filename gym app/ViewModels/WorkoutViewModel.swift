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
    @Published var selectedWorkout: Workout?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: DataRepository

    init(repository: DataRepository = .shared) {
        self.repository = repository
        loadWorkouts()
    }

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
}
