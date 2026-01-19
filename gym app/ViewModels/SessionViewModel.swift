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

    // MARK: - Navigation Accessors
    // Note: These read from the live currentSession using navigator's indices,
    // not from the navigator's stale module copy.

    var currentModuleIndex: Int { navigator?.currentModuleIndex ?? 0 }
    var currentExerciseIndex: Int { navigator?.currentExerciseIndex ?? 0 }
    var currentSetGroupIndex: Int { navigator?.currentSetGroupIndex ?? 0 }
    var currentSetIndex: Int { navigator?.currentSetIndex ?? 0 }

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
        guard currentModuleIndex == lastModuleIndex, lastModuleIndex >= 0 else { return false }

        let module = session.completedModules[currentModuleIndex]
        let lastExerciseIndex = module.completedExercises.count - 1
        guard currentExerciseIndex == lastExerciseIndex, lastExerciseIndex >= 0 else { return false }

        let exercise = module.completedExercises[currentExerciseIndex]
        let lastSetGroupIndex = exercise.completedSetGroups.count - 1
        guard currentSetGroupIndex == lastSetGroupIndex, lastSetGroupIndex >= 0 else { return false }

        let setGroup = exercise.completedSetGroups[currentSetGroupIndex]
        return currentSetIndex == setGroup.sets.count - 1
    }

    var isInSuperset: Bool { currentExercise?.supersetGroupId != nil }

    var shouldRestAfterSuperset: Bool {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else { return false }

        let supersetIndices = module.completedExercises.enumerated()
            .filter { $0.element.supersetGroupId == supersetId }
            .map { $0.offset }

        guard let currentSupersetPosition = supersetIndices.firstIndex(of: currentExerciseIndex) else {
            return false
        }
        return currentSupersetPosition == supersetIndices.count - 1
    }

    var currentSupersetExercises: [SessionExercise]? {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else { return nil }
        return module.completedExercises.filter { $0.supersetGroupId == supersetId }
    }

    var supersetPosition: Int? {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else { return nil }

        let supersetIndices = module.completedExercises.enumerated()
            .filter { $0.element.supersetGroupId == supersetId }
            .map { $0.offset }

        guard let position = supersetIndices.firstIndex(of: currentExerciseIndex) else {
            return nil
        }
        return position + 1
    }

    var supersetTotal: Int? { currentSupersetExercises?.count }

    var overallProgress: Double {
        guard let session = currentSession else { return 0 }
        let modules = session.completedModules

        let totalSets = modules.reduce(0) { moduleSum, module in
            moduleSum + module.completedExercises.reduce(0) { exerciseSum, exercise in
                exerciseSum + exercise.completedSetGroups.reduce(0) { setGroupSum, setGroup in
                    setGroupSum + setGroup.sets.count
                }
            }
        }

        guard totalSets > 0 else { return 0 }

        var completedSets = 0

        for i in 0..<currentModuleIndex {
            for exercise in modules[i].completedExercises {
                for setGroup in exercise.completedSetGroups {
                    completedSets += setGroup.sets.count
                }
            }
        }

        if let module = currentModule {
            for i in 0..<currentExerciseIndex {
                for setGroup in module.completedExercises[i].completedSetGroups {
                    completedSets += setGroup.sets.count
                }
            }

            if let exercise = currentExercise {
                for i in 0..<currentSetGroupIndex {
                    completedSets += exercise.completedSetGroups[i].sets.count
                }
                completedSets += currentSetIndex
            }
        }

        return Double(completedSets) / Double(totalSets)
    }

    // MARK: - Session Management

    func startSession(workout: Workout, modules: [Module]) {
        // Resolve exercises through ExerciseResolver and convert to session format
        var completedModules = modules.map { module in
            CompletedModule(
                moduleId: module.id,
                moduleName: module.name,
                moduleType: module.type,
                completedExercises: module.resolvedExercises().map { resolved in
                    convertResolvedExerciseToSession(resolved)
                }
            )
        }

        // Add standalone exercises as a pseudo-module if any exist
        if !workout.standaloneExercises.isEmpty {
            let resolver = ExerciseResolver.shared
            let standaloneModule = CompletedModule(
                moduleId: UUID(),
                moduleName: "Exercises",
                moduleType: .strength,  // Default type for standalone exercises
                completedExercises: workout.standaloneExercises
                    .sorted { $0.order < $1.order }
                    .map { convertResolvedExerciseToSession(resolver.resolve($0.exercise)) }
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

    /// Converts a ResolvedExercise to a SessionExercise for use in an active session
    private func convertResolvedExerciseToSession(_ resolved: ResolvedExercise) -> SessionExercise {
        SessionExercise(
            exerciseId: resolved.id,
            exerciseName: resolved.name,
            exerciseType: resolved.exerciseType,
            cardioMetric: resolved.cardioMetric,
            mobilityTracking: resolved.mobilityTracking,
            distanceUnit: resolved.distanceUnit,
            supersetGroupId: resolved.supersetGroupId,
            completedSetGroups: resolved.setGroups.map { setGroup in
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
            isBodyweight: resolved.isBodyweight,
            recoveryActivityType: resolved.recoveryActivityType,
            primaryMuscles: resolved.primaryMuscles,
            secondaryMuscles: resolved.secondaryMuscles
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

    /// Update an existing session (for editing completed sessions)
    func updateSession(_ session: Session) {
        repository.saveSession(session)
        loadSessions()
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
