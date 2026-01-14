//
//  SessionViewModel.swift
//  gym app
//
//  ViewModel for managing workout sessions (active logging)
//

import Foundation
import Combine
import UIKit

@MainActor
class SessionViewModel: ObservableObject {
    // Current session state
    @Published var currentSession: Session?
    @Published var isSessionActive = false
    @Published var currentModuleIndex = 0
    @Published var currentExerciseIndex = 0
    @Published var currentSetGroupIndex = 0
    @Published var currentSetIndex = 0

    // Timer state
    @Published var restTimerSeconds = 0
    @Published var restTimerTotal = 0
    @Published var isRestTimerRunning = false
    @Published var sessionStartTime: Date?
    @Published var sessionElapsedSeconds = 0

    // History
    @Published var sessions: [Session] = []

    private let repository: DataRepository
    private var timerCancellable: AnyCancellable?
    private var sessionTimerCancellable: AnyCancellable?

    init(repository: DataRepository = .shared) {
        self.repository = repository
        loadSessions()
    }

    func loadSessions() {
        repository.loadSessions()
        sessions = repository.sessions
    }

    // MARK: - Session Management

    func startSession(workout: Workout, modules: [Module]) {
        let completedModules = modules.map { module in
            CompletedModule(
                moduleId: module.id,
                moduleName: module.name,
                moduleType: module.type,
                completedExercises: module.exercises.map { exercise in
                    SessionExercise(
                        exerciseId: exercise.id,
                        exerciseName: exercise.name,
                        exerciseType: exercise.exerciseType,
                        cardioMetric: exercise.cardioMetric,
                        distanceUnit: exercise.distanceUnit,
                        supersetGroupId: exercise.supersetGroupId,
                        completedSetGroups: exercise.setGroups.map { setGroup in
                            CompletedSetGroup(
                                setGroupId: setGroup.id,
                                restPeriod: setGroup.restPeriod,
                                sets: (1...setGroup.sets).map { setNum in
                                    // Pre-fill with target values for convenience
                                    SetData(
                                        setNumber: setNum,
                                        weight: setGroup.targetWeight,
                                        reps: setGroup.targetReps,
                                        completed: false,
                                        duration: setGroup.targetDuration,
                                        distance: setGroup.targetDistance,
                                        holdTime: setGroup.targetHoldTime
                                    )
                                }
                            )
                        }
                    )
                }
            )
        }

        currentSession = Session(
            workoutId: workout.id,
            workoutName: workout.name,
            completedModules: completedModules
        )

        currentModuleIndex = 0
        currentExerciseIndex = 0
        currentSetGroupIndex = 0
        currentSetIndex = 0
        sessionStartTime = Date()
        isSessionActive = true

        startSessionTimer()
    }

    func endSession(feeling: Int?, notes: String?) {
        guard var session = currentSession else { return }

        session.duration = sessionElapsedSeconds / 60
        session.overallFeeling = feeling
        session.notes = notes

        repository.saveSession(session)
        loadSessions()

        stopSessionTimer()
        stopRestTimer()

        currentSession = nil
        isSessionActive = false
    }

    func cancelSession() {
        stopSessionTimer()
        stopRestTimer()
        currentSession = nil
        isSessionActive = false
    }

    // MARK: - Set Logging

    func logSet(
        weight: Double? = nil,
        reps: Int? = nil,
        rpe: Int? = nil,
        duration: Int? = nil,
        holdTime: Int? = nil,
        distance: Double? = nil,
        completed: Bool = true
    ) {
        guard var session = currentSession else { return }

        // Navigate to current set
        guard currentModuleIndex < session.completedModules.count else { return }
        var module = session.completedModules[currentModuleIndex]

        guard currentExerciseIndex < module.completedExercises.count else { return }
        var exercise = module.completedExercises[currentExerciseIndex]

        guard currentSetGroupIndex < exercise.completedSetGroups.count else { return }
        var setGroup = exercise.completedSetGroups[currentSetGroupIndex]

        guard currentSetIndex < setGroup.sets.count else { return }
        var setData = setGroup.sets[currentSetIndex]

        // Update set data
        setData.weight = weight ?? setData.weight
        setData.reps = reps ?? setData.reps
        setData.rpe = rpe
        setData.duration = duration ?? setData.duration
        setData.holdTime = holdTime ?? setData.holdTime
        setData.distance = distance
        setData.completed = completed

        // Put it all back together
        setGroup.sets[currentSetIndex] = setData
        exercise.completedSetGroups[currentSetGroupIndex] = setGroup
        module.completedExercises[currentExerciseIndex] = exercise
        session.completedModules[currentModuleIndex] = module

        currentSession = session

        // Auto-advance to next set
        advanceToNextSet()
    }

    func advanceToNextSet() {
        guard let session = currentSession else { return }
        let module = session.completedModules[currentModuleIndex]
        let exercise = module.completedExercises[currentExerciseIndex]
        let setGroup = exercise.completedSetGroups[currentSetGroupIndex]

        // Check if this exercise is in a superset
        if let supersetId = exercise.supersetGroupId {
            // Find all exercises in this superset
            let supersetIndices = module.completedExercises.enumerated()
                .filter { $0.element.supersetGroupId == supersetId }
                .map { $0.offset }

            guard let currentSupersetPosition = supersetIndices.firstIndex(of: currentExerciseIndex) else {
                // Fallback to normal flow if something is wrong
                advanceNormally(module: module, exercise: exercise, setGroup: setGroup, session: session)
                return
            }

            let isLastInSuperset = currentSupersetPosition == supersetIndices.count - 1

            if isLastInSuperset {
                // We've done all exercises in the superset for this set
                // Check if there are more sets
                if currentSetIndex < setGroup.sets.count - 1 {
                    // Go back to first exercise in superset, next set number
                    currentExerciseIndex = supersetIndices[0]
                    currentSetIndex += 1
                } else {
                    // Superset round complete, move to next set group or next non-superset exercise
                    moveToNextAfterSuperset(module: module, supersetIndices: supersetIndices, session: session)
                }
            } else {
                // Move to next exercise in superset, same set number
                currentExerciseIndex = supersetIndices[currentSupersetPosition + 1]
                // Keep same setGroupIndex and setIndex
            }
        } else {
            // Normal (non-superset) flow
            advanceNormally(module: module, exercise: exercise, setGroup: setGroup, session: session)
        }
    }

    private func advanceNormally(module: CompletedModule, exercise: SessionExercise, setGroup: CompletedSetGroup, session: Session) {
        if currentSetIndex < setGroup.sets.count - 1 {
            // Next set in current set group
            currentSetIndex += 1
        } else if currentSetGroupIndex < exercise.completedSetGroups.count - 1 {
            // Next set group
            currentSetGroupIndex += 1
            currentSetIndex = 0
        } else if currentExerciseIndex < module.completedExercises.count - 1 {
            // Next exercise
            currentExerciseIndex += 1
            currentSetGroupIndex = 0
            currentSetIndex = 0
        } else if currentModuleIndex < session.completedModules.count - 1 {
            // Next module
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
        // else: end of workout
    }

    private func moveToNextAfterSuperset(module: CompletedModule, supersetIndices: [Int], session: Session) {
        // Find the first exercise index after the superset
        let maxSupersetIndex = supersetIndices.max() ?? currentExerciseIndex

        if maxSupersetIndex < module.completedExercises.count - 1 {
            // Move to next exercise after superset
            currentExerciseIndex = maxSupersetIndex + 1
            currentSetGroupIndex = 0
            currentSetIndex = 0
        } else if currentModuleIndex < session.completedModules.count - 1 {
            // Move to next module
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
        // else: end of workout
    }

    /// Returns true if we just finished the last exercise in a superset round (time to rest)
    var shouldRestAfterSuperset: Bool {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else {
            return false
        }

        let supersetIndices = module.completedExercises.enumerated()
            .filter { $0.element.supersetGroupId == supersetId }
            .map { $0.offset }

        guard let currentSupersetPosition = supersetIndices.firstIndex(of: currentExerciseIndex) else {
            return false
        }

        // We should rest if we're at the last exercise in the superset
        return currentSupersetPosition == supersetIndices.count - 1
    }

    /// Gets all exercises in the current superset (for display purposes)
    var currentSupersetExercises: [SessionExercise]? {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else {
            return nil
        }

        return module.completedExercises.filter { $0.supersetGroupId == supersetId }
    }

    /// Current position within the superset (1-based for display)
    var supersetPosition: Int? {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else {
            return nil
        }

        let supersetIndices = module.completedExercises.enumerated()
            .filter { $0.element.supersetGroupId == supersetId }
            .map { $0.offset }

        guard let position = supersetIndices.firstIndex(of: currentExerciseIndex) else {
            return nil
        }

        return position + 1
    }

    /// Total exercises in current superset
    var supersetTotal: Int? {
        currentSupersetExercises?.count
    }

    func skipExercise() {
        guard let session = currentSession else { return }
        let module = session.completedModules[currentModuleIndex]

        if currentExerciseIndex < module.completedExercises.count - 1 {
            currentExerciseIndex += 1
            currentSetGroupIndex = 0
            currentSetIndex = 0
        } else if currentModuleIndex < session.completedModules.count - 1 {
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
    }

    func skipModule() {
        guard var session = currentSession else { return }

        // Mark current module as skipped
        session.skippedModuleIds.append(session.completedModules[currentModuleIndex].moduleId)
        currentSession = session

        if currentModuleIndex < session.completedModules.count - 1 {
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
    }

    // MARK: - Current Position Accessors

    var currentModule: CompletedModule? {
        guard let session = currentSession,
              currentModuleIndex < session.completedModules.count else { return nil }
        return session.completedModules[currentModuleIndex]
    }

    var currentExercise: SessionExercise? {
        guard let module = currentModule,
              currentExerciseIndex < module.completedExercises.count else { return nil }
        return module.completedExercises[currentExerciseIndex]
    }

    var currentSetGroup: CompletedSetGroup? {
        guard let exercise = currentExercise,
              currentSetGroupIndex < exercise.completedSetGroups.count else { return nil }
        return exercise.completedSetGroups[currentSetGroupIndex]
    }

    var currentSet: SetData? {
        guard let setGroup = currentSetGroup,
              currentSetIndex < setGroup.sets.count else { return nil }
        return setGroup.sets[currentSetIndex]
    }

    var isLastSet: Bool {
        guard let session = currentSession else { return true }
        let lastModuleIndex = session.completedModules.count - 1
        guard currentModuleIndex == lastModuleIndex else { return false }

        let module = session.completedModules[currentModuleIndex]
        let lastExerciseIndex = module.completedExercises.count - 1
        guard currentExerciseIndex == lastExerciseIndex else { return false }

        let exercise = module.completedExercises[currentExerciseIndex]
        let lastSetGroupIndex = exercise.completedSetGroups.count - 1
        guard currentSetGroupIndex == lastSetGroupIndex else { return false }

        let setGroup = exercise.completedSetGroups[currentSetGroupIndex]
        return currentSetIndex == setGroup.sets.count - 1
    }

    // MARK: - Timer Management

    func startRestTimer(seconds: Int) {
        restTimerSeconds = seconds
        restTimerTotal = seconds
        isRestTimerRunning = true

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.restTimerSeconds > 0 {
                    self.restTimerSeconds -= 1
                } else {
                    self.stopRestTimer()
                }
            }
    }

    func stopRestTimer() {
        timerCancellable?.cancel()
        isRestTimerRunning = false
        restTimerSeconds = 0
        restTimerTotal = 0
    }

    private func startSessionTimer() {
        updateElapsedTime()

        sessionTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateElapsedTime()
            }

        // Also update when app returns to foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }

    private func updateElapsedTime() {
        guard let startTime = sessionStartTime else { return }
        sessionElapsedSeconds = Int(Date().timeIntervalSince(startTime))
    }

    private func stopSessionTimer() {
        sessionTimerCancellable?.cancel()
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    // MARK: - History

    func getSessionsForWorkout(_ workoutId: UUID) -> [Session] {
        sessions.filter { $0.workoutId == workoutId }
    }

    func getRecentSessions(limit: Int = 10) -> [Session] {
        Array(sessions.prefix(limit))
    }

    func deleteSession(_ session: Session) {
        repository.deleteSession(session)
        loadSessions()
    }

    func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            deleteSession(sessions[index])
        }
    }

    // Get last session data for an exercise (for showing previous performance)
    func getLastSessionData(for exerciseName: String) -> SessionExercise? {
        for session in sessions {
            for module in session.completedModules {
                if let exercise = module.completedExercises.first(where: { $0.exerciseName == exerciseName }) {
                    return exercise
                }
            }
        }
        return nil
    }
}
