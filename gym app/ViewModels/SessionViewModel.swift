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
import WidgetKit

// MARK: - Sharing Context Structs

/// Context passed through session creation to populate denormalized sharing fields
struct SessionSharingContext {
    let sessionId: UUID
    let workoutId: UUID
    let workoutName: String
    let date: Date
    let programId: UUID?
    let programName: String?
    let programWeekNumber: Int?
}

/// Context for module-level sharing fields
struct ModuleSharingContext {
    let sessionContext: SessionSharingContext
    let moduleId: UUID
    let moduleName: String
}

@MainActor
class SessionViewModel: ObservableObject {
    // Current session state
    @Published var currentSession: Session?
    @Published var isSessionActive = false

    // Original module templates for structural change detection
    private var originalModules: [Module] = []

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

    // Exercise timer state (for timing individual sets - persists when view is dismissed)
    @Published var exerciseTimerSeconds = 0
    @Published var exerciseTimerTotal = 0
    @Published var isExerciseTimerRunning = false
    @Published var exerciseTimerIsStopwatch = false  // true = counting up, false = countdown
    @Published var exerciseTimerSetId: String?  // Which set this timer is for (e.g., "0-0")
    private var exerciseTimerStartTime: Date?
    private var exerciseTimerDuration: Int = 0
    private var exerciseTimerCancellable: AnyCancellable?

    // History
    @Published var sessions: [Session] = []

    private let repository: DataRepository
    private let libraryService = LibraryService.shared
    private var timerCancellable: AnyCancellable?
    private var sessionTimerCancellable: AnyCancellable?
    private var foregroundCancellable: AnyCancellable?
    private var libraryChangeCancellable: AnyCancellable?

    // Auto-save debouncer for crash recovery (saves at most every 2 seconds)
    private let autoSaveDebouncer = Debouncer(delay: 2.0)

    // Timer constants
    private let countdownBeepThreshold = 3  // Play beep sound in last N seconds

    init(repository: DataRepository? = nil) {
        self.repository = repository ?? DataRepository.shared
        loadSessions()
        setupLibraryObserver()
    }

    func loadSessions() {
        repository.loadSessions()
        sessions = repository.sessions
    }

    /// Load all sessions (bypasses pagination - use after importing old data)
    func loadAllSessions() {
        repository.loadAllSessions()
        sessions = repository.sessions
    }

    /// Set up observer for library changes to propagate to active sessions
    private func setupLibraryObserver() {
        // Listen specifically to implement changes (not muscle groups)
        libraryChangeCancellable = libraryService.$implements
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    // Only propagate changes if there's an active session
                    guard self.isSessionActive,
                          let session = self.currentSession else { return }

                    // Check if any exercise in the current session uses implements
                    let hasImplements = session.completedModules.contains { module in
                        module.completedExercises.contains { exercise in
                            !exercise.implementIds.isEmpty
                        }
                    }

                    // If exercises use implements, trigger view update
                    // This forces computed properties (implementStringMeasurable, usesBox, etc.)
                    // to re-evaluate with fresh library data
                    if hasImplements {
                        self.objectWillChange.send()
                    }
                }
            }
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
        return SupersetHelper.isLastInSuperset(itemIndex: currentExerciseIndex, in: module.completedExercises, for: supersetId)
    }

    var currentSupersetExercises: [SessionExercise]? {
        guard let module = currentModule, let exercise = currentExercise else { return nil }
        return SupersetHelper.itemsInSuperset(of: exercise, in: module.completedExercises)
    }

    var supersetPosition: Int? {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else { return nil }
        return SupersetHelper.displayPosition(of: currentExerciseIndex, in: module.completedExercises, for: supersetId)
    }

    var supersetTotal: Int? { currentSupersetExercises?.count }

    // MARK: - Session Management

    /// Start a new workout session
    /// - Parameters:
    ///   - workout: The workout template to start
    ///   - modules: The modules to include in this session
    ///   - scheduledWorkout: Optional scheduled workout for program context
    func startSession(workout: Workout, modules: [Module], scheduledWorkout: ScheduledWorkout? = nil) {
        // Generate session ID and date upfront for context propagation
        let sessionId = UUID()
        let sessionDate = Date()

        // Look up program info if this session is from a scheduled program workout
        var programName: String? = nil
        var programWeekNumber: Int? = nil
        if let programId = scheduledWorkout?.programId,
           let program = repository.getProgram(id: programId) {
            programName = program.name
            // Calculate week number from program start date
            if let startDate = program.startDate {
                let calendar = Calendar.current
                let weeks = calendar.dateComponents([.weekOfYear], from: startDate, to: sessionDate).weekOfYear ?? 0
                programWeekNumber = weeks + 1  // 1-indexed week number
            }
        }

        // Create sharing context for all nested entities
        let context = SessionSharingContext(
            sessionId: sessionId,
            workoutId: workout.id,
            workoutName: workout.name,
            date: sessionDate,
            programId: scheduledWorkout?.programId,
            programName: programName,
            programWeekNumber: programWeekNumber
        )

        // Resolve exercises through ExerciseResolver and convert to session format
        var completedModules = modules.map { module in
            let moduleContext = ModuleSharingContext(
                sessionContext: context,
                moduleId: module.id,
                moduleName: module.name
            )
            return CompletedModule(
                moduleId: module.id,
                moduleName: module.name,
                moduleType: module.type,
                completedExercises: module.resolvedExercises().map { resolved in
                    convertResolvedExerciseToSession(resolved, context: moduleContext)
                },
                sessionId: sessionId,
                workoutId: workout.id,
                workoutName: workout.name,
                date: sessionDate
            )
        }

        // Add standalone exercises as a pseudo-module if any exist
        if !workout.standaloneExercises.isEmpty {
            let resolver = ExerciseResolver.shared
            let standaloneModuleId = UUID()
            let standaloneContext = ModuleSharingContext(
                sessionContext: context,
                moduleId: standaloneModuleId,
                moduleName: "Exercises"
            )
            let standaloneModule = CompletedModule(
                id: standaloneModuleId,
                moduleId: standaloneModuleId,
                moduleName: "Exercises",
                moduleType: .strength,  // Default type for standalone exercises
                completedExercises: workout.standaloneExercises
                    .sorted { $0.order < $1.order }
                    .map { convertResolvedExerciseToSession(resolver.resolve($0.exercise), context: standaloneContext) },
                sessionId: sessionId,
                workoutId: workout.id,
                workoutName: workout.name,
                date: sessionDate
            )
            completedModules.append(standaloneModule)
        }

        // Calculate and apply progression suggestions if program has progression enabled
        if let programId = scheduledWorkout?.programId,
           let program = repository.getProgram(id: programId),
           program.progressionEnabled {

            // Get all exercises from all modules
            let allExercises = completedModules.flatMap { $0.completedExercises }

            // Get session history for this workout (already sorted by date descending)
            let workoutHistory = sessions.filter { $0.workoutId == workout.id }

            // Calculate suggestions
            let progressionService = ProgressionService()
            let suggestions = progressionService.calculateSuggestions(
                for: allExercises,
                workoutId: workout.id,
                program: program,
                sessionHistory: workoutHistory
            )

            // Apply suggestions to exercises
            for moduleIdx in completedModules.indices {
                for exerciseIdx in completedModules[moduleIdx].completedExercises.indices {
                    let exerciseId = completedModules[moduleIdx].completedExercises[exerciseIdx].id
                    if let suggestion = suggestions[exerciseId] {
                        completedModules[moduleIdx].completedExercises[exerciseIdx].progressionSuggestion = suggestion
                    }
                }
            }
        }

        currentSession = Session(
            id: sessionId,
            workoutId: workout.id,
            workoutName: workout.name,
            date: sessionDate,
            completedModules: completedModules,
            programId: scheduledWorkout?.programId,
            programName: context.programName,
            programWeekNumber: context.programWeekNumber
        )

        // Create navigator with the modules
        navigator = SessionNavigator(modules: completedModules)

        // Store original modules for structural change detection at session end
        originalModules = modules

        sessionStartTime = sessionDate
        isSessionActive = true

        startSessionTimer()

        // Save in-progress session immediately for crash/background recovery
        autoSaveInProgressSession()
    }

    // MARK: - Session Recovery

    /// Check if there's a recoverable in-progress session
    func checkForRecoverableSession() -> Session? {
        return repository.loadInProgressSession()
    }

    /// Get info about recoverable session without fully loading it
    func getRecoverableSessionInfo() -> (workoutName: String, startTime: Date, lastUpdated: Date)? {
        return repository.getInProgressSessionInfo()
    }

    /// Resume a previously saved in-progress session
    func resumeSession(_ session: Session) {
        currentSession = session
        navigator = SessionNavigator(modules: session.completedModules)
        sessionStartTime = session.date
        isSessionActive = true

        // Calculate elapsed time since the original session started
        sessionElapsedSeconds = Int(Date().timeIntervalSince(session.date))

        // Restore original modules for structural change detection
        if let workout = repository.getWorkout(id: session.workoutId) {
            originalModules = workout.moduleReferences.compactMap { repository.getModule(id: $0.moduleId) }
        } else {
            originalModules = []
        }

        startSessionTimer()

        // Navigate to first incomplete set
        findAndNavigateToFirstIncompleteSet()
    }

    /// Discard a saved in-progress session
    func discardRecoverableSession() {
        repository.clearInProgressSession()
    }

    // MARK: - Freestyle Session

    /// Start an empty freestyle session where exercises are added on-the-fly
    func startFreestyleSession(name: String? = nil) {
        let session = QuickLogService.shared.createFreestyleSession(name: name)
        currentSession = session
        navigator = SessionNavigator(modules: session.completedModules)
        sessionStartTime = session.date
        isSessionActive = true

        startSessionTimer()

        // Save in-progress session for crash recovery
        autoSaveInProgressSession()
    }

    /// Add an exercise to the active freestyle session
    func addExerciseToFreestyle(
        exerciseName: String,
        exerciseType: ExerciseType,
        implementIds: Set<UUID> = [],
        isBodyweight: Bool = false,
        distanceUnit: DistanceUnit = .miles
    ) {
        guard var session = currentSession, session.isFreestyle else { return }

        QuickLogService.shared.addExercise(
            to: &session,
            exerciseName: exerciseName,
            exerciseType: exerciseType,
            implementIds: implementIds,
            isBodyweight: isBodyweight,
            distanceUnit: distanceUnit
        )

        self.currentSession = session

        // Rebuild navigator to include new exercise
        self.navigator = SessionNavigator(modules: session.completedModules)

        // Navigate to the newly added exercise (last exercise in its module type)
        let moduleType = QuickLogService.shared.moduleTypeForExercise(exerciseType)
        if let module = session.completedModules.first(where: { $0.moduleType == moduleType }),
           let moduleIndex = session.completedModules.firstIndex(where: { $0.id == module.id }),
           let exercise = module.completedExercises.last,
           let exerciseIndex = module.completedExercises.firstIndex(where: { $0.id == exercise.id }) {
            navigator?.setPosition(
                moduleIndex: moduleIndex,
                exerciseIndex: exerciseIndex,
                setGroupIndex: 0,
                setIndex: 0
            )
        }

        autoSaveInProgressSession()
    }

    /// Remove an exercise from the active freestyle session (only if no sets completed)
    func removeExerciseFromFreestyle(moduleId: UUID, exerciseId: UUID) {
        guard var session = currentSession, session.isFreestyle else { return }

        // Check if exercise has any completed sets
        if let module = session.completedModules.first(where: { $0.id == moduleId }),
           let exercise = module.completedExercises.first(where: { $0.id == exerciseId }) {
            let hasCompletedSets = exercise.completedSetGroups.contains { group in
                group.sets.contains { $0.completed }
            }
            if hasCompletedSets { return } // Don't remove exercises with logged data
        }

        QuickLogService.shared.removeExercise(from: &session, moduleId: moduleId, exerciseId: exerciseId)

        self.currentSession = session
        self.navigator = SessionNavigator(modules: session.completedModules)

        autoSaveInProgressSession()
    }

    /// Finds the first incomplete set and navigates to it
    private func findAndNavigateToFirstIncompleteSet() {
        guard let session = currentSession else { return }

        for (mIdx, module) in session.completedModules.enumerated() {
            for (eIdx, exercise) in module.completedExercises.enumerated() {
                for (sgIdx, setGroup) in exercise.completedSetGroups.enumerated() {
                    for (sIdx, set) in setGroup.sets.enumerated() {
                        if !set.completed {
                            navigator?.setPosition(
                                moduleIndex: mIdx,
                                exerciseIndex: eIdx,
                                setGroupIndex: sgIdx,
                                setIndex: sIdx
                            )
                            return
                        }
                    }
                }
            }
        }
    }

    /// Converts a ResolvedExercise to a SessionExercise for use in an active session
    /// Re-syncs equipment from current template to pick up any library changes
    private func convertResolvedExerciseToSession(_ resolved: ResolvedExercise, context: ModuleSharingContext) -> SessionExercise {
        // Re-sync implementIds from current template if available (picks up library changes)
        let currentImplementIds: Set<UUID>
        let currentIsBodyweight: Bool
        let currentTracksAddedWeight: Bool
        if let templateId = resolved.templateId,
           let currentTemplate = ExerciseResolver.shared.getTemplate(id: templateId) {
            currentImplementIds = currentTemplate.implementIds
            currentIsBodyweight = currentTemplate.isBodyweight
            currentTracksAddedWeight = resolved.tracksAddedWeight  // Use instance value (configurable)
        } else {
            // Fall back to instance data if template not found
            currentImplementIds = resolved.implementIds
            currentIsBodyweight = resolved.isBodyweight
            currentTracksAddedWeight = resolved.tracksAddedWeight
        }

        // Use the distance unit from the first set group if specified, otherwise fall back to exercise default
        let effectiveDistanceUnit: DistanceUnit = resolved.setGroups
            .compactMap { $0.targetDistanceUnit }
            .first ?? resolved.distanceUnit

        return SessionExercise(
            exerciseId: resolved.id,
            exerciseName: resolved.name,
            exerciseType: resolved.exerciseType,
            cardioMetric: resolved.cardioMetric,
            mobilityTracking: resolved.mobilityTracking,
            distanceUnit: effectiveDistanceUnit,
            supersetGroupId: resolved.supersetGroupId,
            completedSetGroups: resolved.setGroups.map { setGroup in
                let setsData: [SetData]
                if resolved.isUnilateral {
                    // For unilateral, create left and right for each set number
                    setsData = (1...setGroup.sets).flatMap { setNum -> [SetData] in
                        [
                            SetData(
                                setNumber: setNum,
                                weight: setGroup.targetWeight,
                                reps: setGroup.targetReps,
                                completed: false,
                                duration: setGroup.isInterval ? setGroup.workDuration : setGroup.targetDuration,
                                distance: setGroup.targetDistance,
                                holdTime: setGroup.targetHoldTime,
                                side: .left,
                                sessionId: context.sessionContext.sessionId,
                                exerciseId: resolved.id,
                                exerciseName: resolved.name,
                                workoutName: context.sessionContext.workoutName,
                                date: context.sessionContext.date
                            ),
                            SetData(
                                setNumber: setNum,
                                weight: setGroup.targetWeight,
                                reps: setGroup.targetReps,
                                completed: false,
                                duration: setGroup.isInterval ? setGroup.workDuration : setGroup.targetDuration,
                                distance: setGroup.targetDistance,
                                holdTime: setGroup.targetHoldTime,
                                side: .right,
                                sessionId: context.sessionContext.sessionId,
                                exerciseId: resolved.id,
                                exerciseName: resolved.name,
                                workoutName: context.sessionContext.workoutName,
                                date: context.sessionContext.date
                            )
                        ]
                    }
                } else {
                    // Normal bilateral sets
                    setsData = (1...setGroup.sets).map { setNum in
                        SetData(
                            setNumber: setNum,
                            weight: setGroup.targetWeight,
                            reps: setGroup.targetReps,
                            completed: false,
                            duration: setGroup.isInterval ? setGroup.workDuration : setGroup.targetDuration,
                            distance: setGroup.targetDistance,
                            holdTime: setGroup.targetHoldTime,
                            sessionId: context.sessionContext.sessionId,
                            exerciseId: resolved.id,
                            exerciseName: resolved.name,
                            workoutName: context.sessionContext.workoutName,
                            date: context.sessionContext.date
                        )
                    }
                }

                return CompletedSetGroup(
                    setGroupId: setGroup.id,
                    restPeriod: setGroup.restPeriod,
                    sets: setsData,
                    isInterval: setGroup.isInterval,
                    workDuration: setGroup.workDuration,
                    intervalRestDuration: setGroup.intervalRestDuration,
                    isAMRAP: setGroup.isAMRAP,
                    amrapTimeLimit: setGroup.amrapTimeLimit,
                    isUnilateral: resolved.isUnilateral,  // Read from exercise level
                    trackRPE: setGroup.trackRPE,
                    implementMeasurables: setGroup.implementMeasurables
                )
            },
            isBodyweight: currentIsBodyweight,
            tracksAddedWeight: currentTracksAddedWeight,
            recoveryActivityType: resolved.recoveryActivityType,
            implementIds: currentImplementIds,
            primaryMuscles: resolved.primaryMuscles,
            secondaryMuscles: resolved.secondaryMuscles,
            sourceExerciseInstanceId: resolved.instance.id,  // Track source for structural change detection
            sessionId: context.sessionContext.sessionId,
            moduleId: context.moduleId,
            moduleName: context.moduleName,
            workoutId: context.sessionContext.workoutId,
            workoutName: context.sessionContext.workoutName,
            date: context.sessionContext.date
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

        // Clear in-progress session (no longer needed)
        autoSaveDebouncer.cancel()
        repository.clearInProgressSession()

        currentSession = nil
        navigator = nil
        originalModules = []
        isSessionActive = false

        // Update widget to show completed status
        NotificationCenter.default.post(name: .sessionCompleted, object: nil)
    }

    func cancelSession() {
        stopSessionTimer()
        stopRestTimer()

        // Clear in-progress session
        autoSaveDebouncer.cancel()
        repository.clearInProgressSession()

        currentSession = nil
        navigator = nil
        originalModules = []
        isSessionActive = false
    }

    // MARK: - Structural Change Detection

    /// Detect structural changes made during this session compared to original templates
    func detectStructuralChanges() -> [StructuralChange] {
        guard let session = currentSession else { return [] }
        return WorkoutDiffService.shared.detectChanges(
            session: session,
            originalModules: originalModules
        )
    }

    /// Commit selected structural changes back to module templates
    func commitStructuralChanges(_ selectedChanges: [StructuralChange]) {
        guard !selectedChanges.isEmpty else { return }

        // Get current modules from repository
        let moduleIds = Set(selectedChanges.map { $0.moduleId })
        let modules = moduleIds.compactMap { repository.getModule(id: $0) }

        // Apply changes
        WorkoutDiffService.shared.commitChanges(
            selectedChanges,
            to: modules,
            repository: repository
        )
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

        // Auto-save for crash recovery
        autoSaveInProgressSession()

        // Auto-advance to next set
        advanceToNextSet()
    }

    // MARK: - Auto-Save for Crash Recovery

    private func autoSaveInProgressSession() {
        guard let session = currentSession else { return }
        autoSaveDebouncer.debounce { [weak self] in
            self?.repository.saveInProgressSession(session)
        }
    }

    /// Trigger auto-save when the session is modified externally (e.g., from EditExerciseSheet)
    /// Call this after directly modifying currentSession from views
    func triggerAutoSave() {
        autoSaveInProgressSession()
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

        // Update distance unit in current session
        session.completedModules[moduleIndex].completedExercises[exerciseIndex].distanceUnit = unit
        currentSession = session

        // Persist to module so it remembers for next session
        let exerciseId = session.completedModules[moduleIndex].completedExercises[exerciseIndex].exerciseId
        if let workout = repository.getWorkout(id: session.workoutId) {
            // Find and update the exercise instance in the module
            for moduleRef in workout.moduleReferences {
                if var module = repository.getModule(id: moduleRef.moduleId) {
                    if let eIndex = module.exercises.firstIndex(where: { $0.id == exerciseId }) {
                        module.exercises[eIndex].distanceUnit = unit
                        repository.saveModule(module)
                        Logger.debug("Updated exercise distance unit to \(unit.rawValue) in module")
                        break
                    }
                }
            }
        }

        // Auto-save for crash recovery
        autoSaveInProgressSession()
    }

    /// Update the progression recommendation for an exercise during the active session
    func updateExerciseProgression(moduleIndex: Int, exerciseIndex: Int, recommendation: ProgressionRecommendation?) {
        guard var session = currentSession,
              moduleIndex < session.completedModules.count,
              exerciseIndex < session.completedModules[moduleIndex].completedExercises.count else { return }

        session.completedModules[moduleIndex].completedExercises[exerciseIndex].progressionRecommendation = recommendation
        currentSession = session

        // Auto-save for crash recovery
        autoSaveInProgressSession()
    }

    /// Delete an exercise from a module during the active session
    func deleteExercise(moduleIndex: Int, exerciseIndex: Int) {
        guard var session = currentSession,
              moduleIndex < session.completedModules.count,
              exerciseIndex < session.completedModules[moduleIndex].completedExercises.count,
              session.completedModules[moduleIndex].completedExercises.count > 1 else { return }

        // Calculate the new exercise index before deletion
        var newExerciseIndex = currentExerciseIndex
        if moduleIndex == currentModuleIndex {
            if exerciseIndex == currentExerciseIndex {
                // Deleting current exercise - stay at same index or move back if at end
                let newCount = session.completedModules[moduleIndex].completedExercises.count - 1
                newExerciseIndex = min(exerciseIndex, newCount - 1)
                newExerciseIndex = max(0, newExerciseIndex)
            } else if exerciseIndex < currentExerciseIndex {
                // Deleting exercise before current - adjust index
                newExerciseIndex = currentExerciseIndex - 1
            }
        }

        session.completedModules[moduleIndex].completedExercises.remove(at: exerciseIndex)
        currentSession = session

        // Recreate navigator with updated modules and adjusted position
        navigator = SessionNavigator(
            modules: session.completedModules,
            moduleIndex: currentModuleIndex,
            exerciseIndex: newExerciseIndex,
            setGroupIndex: currentSetGroupIndex,
            setIndex: currentSetIndex
        )
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

        // Use Combine for foreground notification (properly cleaned up)
        setupForegroundObserver()
    }

    private func updateRestTimer() {
        guard let startTime = restTimerStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let remaining = restTimerDuration - elapsed

        if remaining > 0 {
            restTimerSeconds = remaining
        } else {
            restTimerSeconds = 0
            // Play sound and haptic feedback when timer completes
            HapticManager.shared.restTimerComplete()
            stopRestTimer()
        }
    }

    func stopRestTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        isRestTimerRunning = false
        restTimerSeconds = 0
        restTimerTotal = 0
        restTimerStartTime = nil
        restTimerDuration = 0

        // Only cancel foreground observer if session timer is also stopped
        if sessionTimerCancellable == nil {
            foregroundCancellable?.cancel()
            foregroundCancellable = nil
        }

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

        // Use Combine for foreground notification
        setupForegroundObserver()
    }

    private func updateElapsedTime() {
        guard let startTime = sessionStartTime else { return }
        sessionElapsedSeconds = Int(Date().timeIntervalSince(startTime))
    }

    private func stopSessionTimer() {
        sessionTimerCancellable?.cancel()
        sessionTimerCancellable = nil

        // Only cancel foreground observer if rest timer is also stopped
        if timerCancellable == nil {
            foregroundCancellable?.cancel()
            foregroundCancellable = nil
        }
    }

    /// Sets up foreground observer using Combine (only once, shared by both timers)
    private func setupForegroundObserver() {
        // Only set up if not already observing
        guard foregroundCancellable == nil else { return }

        foregroundCancellable = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateRestTimer()
                self?.updateElapsedTime()
                self?.updateExerciseTimer()
            }
    }

    // MARK: - Exercise Timer (for timing individual sets)

    /// Start a countdown timer for a set (e.g., isometric hold)
    func startExerciseTimer(seconds: Int, setId: String) {
        exerciseTimerDuration = seconds
        exerciseTimerTotal = seconds
        exerciseTimerStartTime = Date()
        exerciseTimerSetId = setId
        exerciseTimerIsStopwatch = false
        isExerciseTimerRunning = true
        updateExerciseTimer()

        exerciseTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateExerciseTimer()
            }

        setupForegroundObserver()
        HapticManager.shared.impact()
    }

    /// Start a stopwatch timer for a set (e.g., cardio distance run)
    func startExerciseStopwatch(setId: String) {
        exerciseTimerStartTime = Date()
        exerciseTimerSetId = setId
        exerciseTimerIsStopwatch = true
        exerciseTimerSeconds = 0
        isExerciseTimerRunning = true

        exerciseTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateExerciseTimer()
            }

        setupForegroundObserver()
        HapticManager.shared.impact()
    }

    private func updateExerciseTimer() {
        guard let startTime = exerciseTimerStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))

        if exerciseTimerIsStopwatch {
            // Stopwatch mode - counting up
            exerciseTimerSeconds = elapsed
        } else {
            // Countdown mode
            let remaining = exerciseTimerDuration - elapsed
            if remaining > 0 {
                // Sound and haptic for countdown
                if remaining <= countdownBeepThreshold && exerciseTimerSeconds != remaining {
                    HapticManager.shared.countdownBeep()
                }
                exerciseTimerSeconds = remaining
            } else {
                exerciseTimerSeconds = 0
                stopExerciseTimer(completed: true)
            }
        }
    }

    /// Stop the exercise timer and return the elapsed time
    func stopExerciseTimer(completed: Bool = false) -> Int {
        exerciseTimerCancellable?.cancel()
        exerciseTimerCancellable = nil

        let result: Int
        if exerciseTimerIsStopwatch {
            result = exerciseTimerSeconds
        } else {
            // For countdown, return elapsed time (total - remaining)
            result = completed ? exerciseTimerTotal : (exerciseTimerTotal - exerciseTimerSeconds)
        }

        if completed {
            HapticManager.shared.timerComplete()
        }

        isExerciseTimerRunning = false
        exerciseTimerSetId = nil
        exerciseTimerStartTime = nil
        exerciseTimerDuration = 0

        // Only cancel foreground observer if no other timers are running
        if timerCancellable == nil && sessionTimerCancellable == nil {
            foregroundCancellable?.cancel()
            foregroundCancellable = nil
        }

        return result
    }

    /// Get the current exercise timer display value
    var exerciseTimerDisplaySeconds: Int {
        exerciseTimerSeconds
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

        // Update widget if the deleted session was from today
        if Calendar.current.isDateInToday(session.date) {
            // Check if there are any other sessions today
            let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.date) }
            if todaySessions.isEmpty {
                // No sessions today - clear widget completed state
                WidgetDataService.writeTodayWorkout(.noWorkout)
            } else if let latestToday = todaySessions.first {
                // Show the most recent remaining session
                let widgetData = TodayWorkoutData(
                    workoutName: latestToday.displayName,
                    moduleNames: latestToday.completedModules.map { $0.moduleName },
                    isRestDay: false,
                    isCompleted: true,
                    lastUpdated: Date()
                )
                WidgetDataService.writeTodayWorkout(widgetData)
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "TodayWorkoutWidget")
        }
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

    // Get last session data for an exercise within the same workout (for showing previous performance)
    // Only returns data from the same workout - never shows data from other workouts
    func getLastSessionData(for exerciseName: String, workoutId: UUID? = nil) -> SessionExercise? {
        // Get the target workout ID (current session's workout if not specified)
        let targetWorkoutId = workoutId ?? currentSession?.workoutId
        let currentSessionId = currentSession?.id

        // Only look for exercise in sessions of the SAME workout (excluding current session)
        // Sessions are sorted by date descending (most recent first)
        guard let targetId = targetWorkoutId else { return nil }

        for session in sessions {
            // Skip the current session - we want PREVIOUS session data
            if session.id == currentSessionId { continue }

            // Only consider sessions from the same workout
            if session.workoutId == targetId {
                for module in session.completedModules {
                    // Only return if the exercise has completed sets with actual data
                    if let exercise = module.completedExercises.first(where: {
                        $0.exerciseName == exerciseName &&
                        $0.completedSetGroups.contains { setGroup in
                            setGroup.sets.contains { set in
                                set.completed && set.hasAnyMetricData
                            }
                        }
                    }) {
                        return exercise
                    }
                }
            }
        }

        // No fallback - if this workout has never been done before, return nil
        return nil
    }
}
