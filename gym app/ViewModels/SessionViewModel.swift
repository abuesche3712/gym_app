//
//  SessionViewModel.swift
//  gym app
//
//  ViewModel for managing workout sessions (active logging)
//  Focuses on: session lifecycle, timer management, data persistence
//  Navigation logic is delegated to SessionNavigator
//

import Foundation
import Combine
import UIKit

@MainActor
class SessionViewModel: ObservableObject {
    // Current session state
    @Published var currentSession: Session?
    @Published var isSessionActive = false

    // Navigation state (published for UI binding)
    @Published private(set) var navigator: SessionNavigator?

    // Timer state
    @Published var restTimerSeconds = 0
    @Published var restTimerTotal = 0
    @Published var isRestTimerRunning = false
    @Published var sessionStartTime: Date?
    @Published var sessionElapsedSeconds = 0

    // Rest timer background support
    private var restTimerStartTime: Date?
    private var restTimerDuration: Int = 0

    // History
    @Published var sessions: [Session] = []

    private let repository: DataRepository
    private var timerCancellable: AnyCancellable?
    private var sessionTimerCancellable: AnyCancellable?

    init(repository: DataRepository? = nil) {
        self.repository = repository ?? DataRepository.shared
        loadSessions()
    }

    func loadSessions() {
        repository.loadSessions()
        sessions = repository.sessions
    }

    // MARK: - Navigation Accessors (delegated to navigator)

    var currentModuleIndex: Int { navigator?.currentModuleIndex ?? 0 }
    var currentExerciseIndex: Int { navigator?.currentExerciseIndex ?? 0 }
    var currentSetGroupIndex: Int { navigator?.currentSetGroupIndex ?? 0 }
    var currentSetIndex: Int { navigator?.currentSetIndex ?? 0 }

    var currentModule: CompletedModule? { navigator?.currentModule }
    var currentExercise: SessionExercise? { navigator?.currentExercise }
    var currentSetGroup: CompletedSetGroup? { navigator?.currentSetGroup }
    var currentSet: SetData? { navigator?.currentSet }

    var isLastSet: Bool { navigator?.isLastSet ?? true }
    var isInSuperset: Bool { navigator?.isInSuperset ?? false }
    var shouldRestAfterSuperset: Bool { navigator?.shouldRestAfterSuperset ?? false }
    var currentSupersetExercises: [SessionExercise]? { navigator?.currentSupersetExercises }
    var supersetPosition: Int? { navigator?.supersetPosition }
    var supersetTotal: Int? { navigator?.supersetTotal }
    var overallProgress: Double { navigator?.overallProgress ?? 0 }

    // MARK: - Session Management

    func startSession(workout: Workout, modules: [Module]) {
        // Use unified accessor to handle both legacy and normalized exercise models
        var completedModules = modules.map { module in
            CompletedModule(
                moduleId: module.id,
                moduleName: module.name,
                moduleType: module.type,
                completedExercises: module.allExercisesAsLegacy().map { exercise in
                    convertExerciseToSession(exercise)
                }
            )
        }

        // Add standalone exercises as a pseudo-module if any exist
        if !workout.standaloneExercises.isEmpty {
            let standaloneModule = CompletedModule(
                moduleId: UUID(),
                moduleName: "Exercises",
                moduleType: .strength,  // Default type for standalone exercises
                completedExercises: workout.standaloneExercises
                    .sorted { $0.order < $1.order }
                    .map { convertExerciseToSession($0.exercise) }
            )
            completedModules.append(standaloneModule)
        }

        currentSession = Session(
            workoutId: workout.id,
            workoutName: workout.name,
            completedModules: completedModules
        )

        // Create navigator with the modules
        navigator = SessionNavigator(modules: completedModules)

        sessionStartTime = Date()
        isSessionActive = true

        startSessionTimer()
    }

    /// Converts an Exercise to a SessionExercise for use in an active session
    private func convertExerciseToSession(_ exercise: Exercise) -> SessionExercise {
        SessionExercise(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            exerciseType: exercise.exerciseType,
            cardioMetric: exercise.cardioMetric,
            mobilityTracking: exercise.mobilityTracking,
            distanceUnit: exercise.distanceUnit,
            supersetGroupId: exercise.supersetGroupId,
            completedSetGroups: exercise.setGroups.map { setGroup in
                CompletedSetGroup(
                    setGroupId: setGroup.id,
                    restPeriod: setGroup.restPeriod,
                    sets: (1...max(setGroup.sets, 1)).map { setNum in
                        SetData(
                            setNumber: setNum,
                            weight: setGroup.targetWeight,
                            reps: setGroup.targetReps,
                            completed: false,
                            duration: setGroup.isInterval ? setGroup.workDuration : setGroup.targetDuration,
                            distance: setGroup.targetDistance,
                            holdTime: setGroup.targetHoldTime
                        )
                    },
                    isInterval: setGroup.isInterval,
                    workDuration: setGroup.workDuration,
                    intervalRestDuration: setGroup.intervalRestDuration
                )
            },
            isBodyweight: exercise.isBodyweight,
            recoveryActivityType: exercise.recoveryActivityType
        )
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
        navigator = nil
        isSessionActive = false
    }

    func cancelSession() {
        stopSessionTimer()
        stopRestTimer()
        currentSession = nil
        navigator = nil
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
        guard var session = currentSession,
              let nav = navigator else { return }

        // Navigate to current set using navigator's indices
        guard nav.currentModuleIndex < session.completedModules.count else { return }
        var module = session.completedModules[nav.currentModuleIndex]

        guard nav.currentExerciseIndex < module.completedExercises.count else { return }
        var exercise = module.completedExercises[nav.currentExerciseIndex]

        guard nav.currentSetGroupIndex < exercise.completedSetGroups.count else { return }
        var setGroup = exercise.completedSetGroups[nav.currentSetGroupIndex]

        guard nav.currentSetIndex < setGroup.sets.count else { return }
        var setData = setGroup.sets[nav.currentSetIndex]

        // Update set data
        setData.weight = weight ?? setData.weight
        setData.reps = reps ?? setData.reps
        setData.rpe = rpe
        setData.duration = duration ?? setData.duration
        setData.holdTime = holdTime ?? setData.holdTime
        setData.distance = distance
        setData.completed = completed

        // Put it all back together
        setGroup.sets[nav.currentSetIndex] = setData
        exercise.completedSetGroups[nav.currentSetGroupIndex] = setGroup
        module.completedExercises[nav.currentExerciseIndex] = exercise
        session.completedModules[nav.currentModuleIndex] = module

        currentSession = session

        // Auto-advance to next set
        advanceToNextSet()
    }

    // MARK: - Navigation (delegated to navigator)

    func advanceToNextSet() {
        navigator?.advanceToNextSet()
        // Trigger UI update by reassigning (struct is value type)
        objectWillChange.send()
    }

    func skipExercise() {
        navigator?.skipExercise()
        objectWillChange.send()
    }

    func skipModule() {
        guard var session = currentSession else { return }

        if let skippedModuleId = navigator?.skipModule() {
            // Track the skipped module in the session
            session.skippedModuleIds.append(skippedModuleId)
            currentSession = session
        }
        objectWillChange.send()
    }

    /// Goes to the previous exercise
    func goToPreviousExercise() {
        navigator?.goToPreviousExercise()
        objectWillChange.send()
    }

    /// Goes to the next exercise (skipping remaining sets)
    func goToNextExercise() {
        navigator?.goToNextExercise()
        objectWillChange.send()
    }

    /// Goes to the next module (skipping remaining exercises)
    func goToNextModule() {
        navigator?.goToNextModule()
        objectWillChange.send()
    }

    /// Moves to a specific exercise within the current module
    func moveToExercise(_ index: Int) {
        navigator?.moveToExercise(index)
        objectWillChange.send()
    }

    /// Jumps to a specific set within the current exercise
    func jumpToSet(setGroupIndex: Int, setIndex: Int) {
        navigator?.jumpToSet(setGroupIndex: setGroupIndex, setIndex: setIndex)
        objectWillChange.send()
    }

    /// Sets position directly (for complex navigation)
    func setPosition(
        moduleIndex: Int? = nil,
        exerciseIndex: Int? = nil,
        setGroupIndex: Int? = nil,
        setIndex: Int? = nil
    ) {
        navigator?.setPosition(
            moduleIndex: moduleIndex,
            exerciseIndex: exerciseIndex,
            setGroupIndex: setGroupIndex,
            setIndex: setIndex
        )
        objectWillChange.send()
    }

    /// Update the distance unit for an exercise during the active session
    func updateExerciseDistanceUnit(moduleIndex: Int, exerciseIndex: Int, unit: DistanceUnit) {
        guard var session = currentSession,
              moduleIndex < session.completedModules.count,
              exerciseIndex < session.completedModules[moduleIndex].completedExercises.count else { return }

        session.completedModules[moduleIndex].completedExercises[exerciseIndex].distanceUnit = unit
        currentSession = session
    }

    /// Refreshes the navigator with the current session's modules while preserving position.
    /// Call this after modifying currentSession (e.g., adding/removing sets) so the navigator
    /// reflects the updated structure.
    func refreshNavigator() {
        guard let session = currentSession else { return }

        // Preserve current position
        let moduleIndex = navigator?.currentModuleIndex ?? 0
        let exerciseIndex = navigator?.currentExerciseIndex ?? 0
        let setGroupIndex = navigator?.currentSetGroupIndex ?? 0
        let setIndex = navigator?.currentSetIndex ?? 0

        // Recreate navigator with updated modules
        navigator = SessionNavigator(
            modules: session.completedModules,
            moduleIndex: moduleIndex,
            exerciseIndex: exerciseIndex,
            setGroupIndex: setGroupIndex,
            setIndex: setIndex
        )

        objectWillChange.send()
    }

    // MARK: - Timer Management

    func startRestTimer(seconds: Int) {
        restTimerDuration = seconds
        restTimerTotal = seconds
        restTimerStartTime = Date()
        isRestTimerRunning = true
        updateRestTimer()

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateRestTimer()
            }

        // Listen for foreground to update timer
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateRestTimer()
            }
        }
    }

    private func updateRestTimer() {
        guard let startTime = restTimerStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let remaining = restTimerDuration - elapsed

        if remaining > 0 {
            restTimerSeconds = remaining
        } else {
            restTimerSeconds = 0
            stopRestTimer()
        }
    }

    func stopRestTimer() {
        timerCancellable?.cancel()
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        isRestTimerRunning = false
        restTimerSeconds = 0
        restTimerTotal = 0
        restTimerStartTime = nil
        restTimerDuration = 0

        // Auto-advance to next exercise if all sets of current exercise are completed
        if let exercise = currentExercise, allSetsCompleted(exercise) {
            goToNextExercise()
        }
    }

    /// Check if all sets of an exercise are completed
    private func allSetsCompleted(_ exercise: SessionExercise) -> Bool {
        exercise.completedSetGroups.allSatisfy { group in
            group.sets.allSatisfy { $0.completed }
        }
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
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
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
