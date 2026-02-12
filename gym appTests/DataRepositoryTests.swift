//
//  DataRepositoryTests.swift
//  gym appTests
//
//  Comprehensive unit tests for DataRepository covering Module, Workout, Session, and Program CRUD operations
//

import XCTest
@testable import gym_app

// MARK: - Test Fixtures

extension Module {
    static func fixture(
        id: UUID = UUID(),
        name: String = "Test Module",
        type: ModuleType = .strength,
        exercises: [ExerciseInstance] = [],
        notes: String? = nil,
        estimatedDuration: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync
    ) -> Module {
        Module(
            id: id,
            name: name,
            type: type,
            exercises: exercises,
            notes: notes,
            estimatedDuration: estimatedDuration,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus
        )
    }
}

extension Workout {
    static func fixture(
        id: UUID = UUID(),
        name: String = "Test Workout",
        moduleReferences: [ModuleReference] = [],
        standaloneExercises: [WorkoutExercise] = [],
        estimatedDuration: Int? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        archived: Bool = false,
        syncStatus: SyncStatus = .pendingSync
    ) -> Workout {
        Workout(
            id: id,
            name: name,
            moduleReferences: moduleReferences,
            standaloneExercises: standaloneExercises,
            estimatedDuration: estimatedDuration,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            archived: archived,
            syncStatus: syncStatus
        )
    }
}

extension Session {
    static func fixture(
        id: UUID = UUID(),
        workoutId: UUID = UUID(),
        workoutName: String = "Test Workout",
        date: Date = Date(),
        completedModules: [CompletedModule] = [],
        skippedModuleIds: [UUID] = [],
        duration: Int? = nil,
        overallFeeling: Int? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync
    ) -> Session {
        Session(
            id: id,
            workoutId: workoutId,
            workoutName: workoutName,
            date: date,
            completedModules: completedModules,
            skippedModuleIds: skippedModuleIds,
            duration: duration,
            overallFeeling: overallFeeling,
            notes: notes,
            createdAt: createdAt,
            syncStatus: syncStatus
        )
    }
}

extension Program {
    static func fixture(
        id: UUID = UUID(),
        name: String = "Test Program",
        programDescription: String? = nil,
        durationWeeks: Int = 4,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isActive: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync,
        workoutSlots: [ProgramWorkoutSlot] = [],
        progressionEnabled: Bool = false
    ) -> Program {
        Program(
            id: id,
            name: name,
            programDescription: programDescription,
            durationWeeks: durationWeeks,
            startDate: startDate,
            endDate: endDate,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus,
            workoutSlots: workoutSlots,
            progressionEnabled: progressionEnabled
        )
    }
}

extension ExerciseInstance {
    static func fixture(
        id: UUID = UUID(),
        name: String = "Test Exercise",
        exerciseType: ExerciseType = .strength,
        setGroups: [SetGroup] = [SetGroup(sets: 3, targetReps: 10)],
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> ExerciseInstance {
        ExerciseInstance(
            id: id,
            name: name,
            exerciseType: exerciseType,
            setGroups: setGroups,
            order: order,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension CompletedModule {
    static func fixture(
        id: UUID = UUID(),
        moduleId: UUID = UUID(),
        moduleName: String = "Test Module",
        moduleType: ModuleType = .strength,
        completedExercises: [SessionExercise] = [],
        skipped: Bool = false,
        notes: String? = nil
    ) -> CompletedModule {
        CompletedModule(
            id: id,
            moduleId: moduleId,
            moduleName: moduleName,
            moduleType: moduleType,
            completedExercises: completedExercises,
            skipped: skipped,
            notes: notes
        )
    }
}

extension SessionExercise {
    static func fixture(
        id: UUID = UUID(),
        exerciseId: UUID = UUID(),
        exerciseName: String = "Test Exercise",
        exerciseType: ExerciseType = .strength,
        completedSetGroups: [CompletedSetGroup] = [],
        notes: String? = nil
    ) -> SessionExercise {
        SessionExercise(
            id: id,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            exerciseType: exerciseType,
            completedSetGroups: completedSetGroups,
            notes: notes
        )
    }
}

extension CompletedSetGroup {
    static func fixture(
        id: UUID = UUID(),
        setGroupId: UUID = UUID(),
        restPeriod: Int? = nil,
        sets: [SetData] = []
    ) -> CompletedSetGroup {
        CompletedSetGroup(
            id: id,
            setGroupId: setGroupId,
            restPeriod: restPeriod,
            sets: sets
        )
    }
}

extension SetData {
    static func fixture(
        id: UUID = UUID(),
        setNumber: Int = 1,
        weight: Double? = 100,
        reps: Int? = 10,
        completed: Bool = true
    ) -> SetData {
        SetData(
            id: id,
            setNumber: setNumber,
            weight: weight,
            reps: reps,
            completed: completed
        )
    }
}

// MARK: - Module Repository Tests

@MainActor
final class ModuleRepositoryTests: XCTestCase {
    var persistence: PersistenceController!
    var moduleRepo: ModuleRepository!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        moduleRepo = ModuleRepository(persistence: persistence)
    }

    override func tearDown() {
        moduleRepo = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveModuleLocally_createsNewModule() throws {
        // Given
        let module = Module.fixture(name: "Strength Training", type: .strength)

        // When
        moduleRepo.save(module)
        let loaded = moduleRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Strength Training")
        XCTAssertEqual(loaded.first?.type, .strength)
        XCTAssertEqual(loaded.first?.id, module.id)
    }

    func testSaveModuleLocally_updatesExistingModule() throws {
        // Given
        let moduleId = UUID()
        var module = Module.fixture(id: moduleId, name: "Original Name")
        moduleRepo.save(module)

        // When
        module.name = "Updated Name"
        module.notes = "Added notes"
        moduleRepo.save(module)
        let loaded = moduleRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Updated Name")
        XCTAssertEqual(loaded.first?.notes, "Added notes")
    }

    func testSaveModule_preservesExerciseInstances() throws {
        // Given
        let exercise1 = ExerciseInstance.fixture(name: "Squat", order: 0)
        let exercise2 = ExerciseInstance.fixture(name: "Deadlift", order: 1)
        let module = Module.fixture(name: "Leg Day", exercises: [exercise1, exercise2])

        // When
        moduleRepo.save(module)
        let loaded = moduleRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.first?.exercises.count, 2)
        XCTAssertEqual(loaded.first?.exercises[0].name, "Squat")
        XCTAssertEqual(loaded.first?.exercises[1].name, "Deadlift")
    }

    // MARK: - Delete Tests

    func testDeleteModule_removesFromLocalStorage() throws {
        // Given
        let module = Module.fixture(name: "To Delete")
        moduleRepo.save(module)
        XCTAssertEqual(moduleRepo.loadAll().count, 1)

        // When
        moduleRepo.delete(module)

        // Then
        XCTAssertEqual(moduleRepo.loadAll().count, 0)
    }

    // MARK: - Load Tests

    func testLoadModules_returnsSortedByName() throws {
        // Given
        moduleRepo.save(Module.fixture(name: "Zzz Module"))
        moduleRepo.save(Module.fixture(name: "Aaa Module"))
        moduleRepo.save(Module.fixture(name: "Mmm Module"))

        // When
        let loaded = moduleRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].name, "Aaa Module")
        XCTAssertEqual(loaded[1].name, "Mmm Module")
        XCTAssertEqual(loaded[2].name, "Zzz Module")
    }

    // MARK: - Round-trip Tests

    func testModuleConversion_roundTripPreservesData() throws {
        // Given
        let originalExercise = ExerciseInstance(
            id: UUID(),
            name: "Bench Press",
            exerciseType: .strength,
            setGroups: [
                SetGroup(sets: 4, targetReps: 8, targetWeight: 100),
                SetGroup(sets: 2, targetReps: 12, targetWeight: 80)
            ],
            order: 0,
            notes: "Focus on form"
        )
        let originalModule = Module(
            id: UUID(),
            name: "Upper Body",
            type: .strength,
            exercises: [originalExercise],
            notes: "Monday workout",
            estimatedDuration: 60
        )

        // When
        moduleRepo.save(originalModule)
        let loaded = moduleRepo.find(id: originalModule.id)

        // Then
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, originalModule.id)
        XCTAssertEqual(loaded?.name, originalModule.name)
        XCTAssertEqual(loaded?.type, originalModule.type)
        XCTAssertEqual(loaded?.notes, originalModule.notes)
        XCTAssertEqual(loaded?.estimatedDuration, originalModule.estimatedDuration)
        XCTAssertEqual(loaded?.exercises.count, 1)
        XCTAssertEqual(loaded?.exercises.first?.name, "Bench Press")
        XCTAssertEqual(loaded?.exercises.first?.setGroups.count, 2)
        XCTAssertEqual(loaded?.exercises.first?.setGroups[0].sets, 4)
        XCTAssertEqual(loaded?.exercises.first?.setGroups[0].targetReps, 8)
        XCTAssertEqual(loaded?.exercises.first?.setGroups[0].targetWeight, 100)
    }
}

// MARK: - Workout Repository Tests

@MainActor
final class WorkoutRepositoryTests: XCTestCase {
    var persistence: PersistenceController!
    var workoutRepo: WorkoutRepository!
    var moduleRepo: ModuleRepository!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        workoutRepo = WorkoutRepository(persistence: persistence)
        moduleRepo = ModuleRepository(persistence: persistence)
    }

    override func tearDown() {
        workoutRepo = nil
        moduleRepo = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveWorkout_createsNewWorkout() throws {
        // Given
        let workout = Workout.fixture(name: "Push Day", estimatedDuration: 60)

        // When
        workoutRepo.save(workout)
        let loaded = workoutRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Push Day")
        XCTAssertEqual(loaded.first?.estimatedDuration, 60)
    }

    func testSaveWorkout_preservesModuleReferences() throws {
        // Given
        let module1 = Module.fixture(name: "Warmup", type: .warmup)
        let module2 = Module.fixture(name: "Main Work", type: .strength)
        moduleRepo.save(module1)
        moduleRepo.save(module2)

        let moduleRefs = [
            ModuleReference(moduleId: module1.id, order: 0),
            ModuleReference(moduleId: module2.id, order: 1)
        ]
        let workout = Workout.fixture(name: "Full Workout", moduleReferences: moduleRefs)

        // When
        workoutRepo.save(workout)
        let loaded = workoutRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.first?.moduleReferences.count, 2)
        XCTAssertEqual(loaded.first?.moduleReferences[0].moduleId, module1.id)
        XCTAssertEqual(loaded.first?.moduleReferences[1].moduleId, module2.id)
    }

    func testSaveWorkout_preservesStandaloneExercises() throws {
        // Given
        let exercise = ExerciseInstance.fixture(name: "Pull-ups", order: 0)
        let workoutExercise = WorkoutExercise(exercise: exercise, order: 0)
        let workout = Workout.fixture(
            name: "Extra Work",
            standaloneExercises: [workoutExercise]
        )

        // When
        workoutRepo.save(workout)
        let loaded = workoutRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.first?.standaloneExercises.count, 1)
        XCTAssertEqual(loaded.first?.standaloneExercises.first?.exercise.name, "Pull-ups")
    }

    // MARK: - Delete Tests

    func testDeleteWorkout_removesFromStorage() throws {
        // Given
        let workout = Workout.fixture(name: "To Delete")
        workoutRepo.save(workout)
        XCTAssertEqual(workoutRepo.loadAll().count, 1)

        // When
        workoutRepo.delete(workout)

        // Then
        XCTAssertEqual(workoutRepo.loadAll().count, 0)
    }

    // MARK: - Round-trip Tests

    func testWorkoutConversion_roundTripPreservesData() throws {
        // Given
        let exercise = ExerciseInstance.fixture(name: "Barbell Row")
        let workoutExercise = WorkoutExercise(exercise: exercise, order: 0, notes: "Strict form")
        let original = Workout(
            id: UUID(),
            name: "Back Day",
            standaloneExercises: [workoutExercise],
            estimatedDuration: 45,
            notes: "Focus on contraction",
            archived: false
        )

        // When
        workoutRepo.save(original)
        let loaded = workoutRepo.find(id: original.id)

        // Then
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "Back Day")
        XCTAssertEqual(loaded?.estimatedDuration, 45)
        XCTAssertEqual(loaded?.notes, "Focus on contraction")
        XCTAssertEqual(loaded?.standaloneExercises.first?.notes, "Strict form")
    }
}

// MARK: - Session Repository Tests

@MainActor
final class SessionRepositoryTests: XCTestCase {
    var persistence: PersistenceController!
    var sessionRepo: SessionRepository!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        sessionRepo = SessionRepository(persistence: persistence)
    }

    override func tearDown() {
        sessionRepo = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveSession_createsNewSession() throws {
        // Given
        let session = Session.fixture(
            workoutName: "Morning Workout",
            duration: 45,
            overallFeeling: 4
        )

        // When
        sessionRepo.save(session)
        let loaded = sessionRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.workoutName, "Morning Workout")
        XCTAssertEqual(loaded.first?.duration, 45)
        XCTAssertEqual(loaded.first?.overallFeeling, 4)
    }

    func testSaveSession_preservesCompletedModules() throws {
        // Given
        let setData = SetData.fixture(setNumber: 1, weight: 100, reps: 8)
        let completedSetGroup = CompletedSetGroup.fixture(sets: [setData])
        let sessionExercise = SessionExercise.fixture(
            exerciseName: "Squat",
            completedSetGroups: [completedSetGroup]
        )
        let completedModule = CompletedModule.fixture(
            moduleName: "Strength Work",
            completedExercises: [sessionExercise]
        )
        let session = Session.fixture(completedModules: [completedModule])

        // When
        sessionRepo.save(session)
        let loaded = sessionRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.first?.completedModules.count, 1)
        XCTAssertEqual(loaded.first?.completedModules.first?.moduleName, "Strength Work")
        XCTAssertEqual(loaded.first?.completedModules.first?.completedExercises.count, 1)
        XCTAssertEqual(loaded.first?.completedModules.first?.completedExercises.first?.exerciseName, "Squat")
        XCTAssertEqual(loaded.first?.completedModules.first?.completedExercises.first?.completedSetGroups.first?.sets.first?.weight, 100)
    }

    // MARK: - Delete Tests

    func testDeleteSession_removesFromStorage() throws {
        // Given
        let session = Session.fixture(workoutName: "To Delete")
        sessionRepo.save(session)
        XCTAssertEqual(sessionRepo.loadAll().count, 1)

        // When
        sessionRepo.delete(session)

        // Then
        XCTAssertEqual(sessionRepo.loadAll().count, 0)
    }

    // MARK: - Load Tests

    func testLoadSessions_returnsSortedByDateDescending() throws {
        // Given
        let oldDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        sessionRepo.save(Session.fixture(workoutName: "Old Session", date: oldDate))
        sessionRepo.save(Session.fixture(workoutName: "Recent Session", date: recentDate))
        sessionRepo.save(Session.fixture(workoutName: "Today Session", date: Date()))

        // When
        let loaded = sessionRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].workoutName, "Today Session")
        XCTAssertEqual(loaded[1].workoutName, "Recent Session")
        XCTAssertEqual(loaded[2].workoutName, "Old Session")
    }

    // MARK: - Pagination Tests

    func testLoadRecent_loadsOnlyRecentSessions() throws {
        // Given - Create sessions older than 90 days
        let oldDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let recentDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        sessionRepo.save(Session.fixture(workoutName: "Old Session", date: oldDate))
        sessionRepo.save(Session.fixture(workoutName: "Recent Session", date: recentDate))

        // When
        let recent = sessionRepo.loadRecent()

        // Then
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.workoutName, "Recent Session")
        XCTAssertTrue(sessionRepo.hasMore)
    }

    func testLoadMore_loadsPaginatedSessions() throws {
        // Given - Create sessions with dates spanning multiple pages
        for i in 0..<50 {
            let date = Calendar.current.date(byAdding: .day, value: -i * 3, to: Date())!
            sessionRepo.save(Session.fixture(workoutName: "Session \(i)", date: date))
        }

        // When - Load recent first
        var sessions = sessionRepo.loadRecent()
        let initialCount = sessions.count

        // Then load more
        _ = sessionRepo.loadMore(currentSessions: &sessions)

        // Then
        XCTAssertGreaterThan(sessions.count, initialCount)
    }

    // MARK: - In-Progress Session Tests

    func testSaveInProgressSession_persistsForRecovery() throws {
        // Given
        let inProgressSession = Session.fixture(
            workoutName: "In Progress Workout",
            duration: 30
        )

        // When
        sessionRepo.saveInProgress(inProgressSession)
        let recovered = sessionRepo.loadInProgress()

        // Then
        XCTAssertNotNil(recovered)
        XCTAssertEqual(recovered?.workoutName, "In Progress Workout")
    }

    func testClearInProgressSession_removesRecoveryData() throws {
        // Given
        let session = Session.fixture(workoutName: "To Clear")
        sessionRepo.saveInProgress(session)
        XCTAssertNotNil(sessionRepo.loadInProgress())

        // When
        sessionRepo.clearInProgress()

        // Then
        XCTAssertNil(sessionRepo.loadInProgress())
    }

    func testGetInProgressInfo_returnsMetadata() throws {
        // Given
        let startTime = Date()
        var session = Session.fixture(workoutName: "Current Workout", date: startTime)
        session.createdAt = startTime
        sessionRepo.saveInProgress(session)

        // When
        let info = sessionRepo.getInProgressInfo()

        // Then
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.workoutName, "Current Workout")
    }
}

// MARK: - Program Repository Tests

@MainActor
final class ProgramRepositoryTests: XCTestCase {
    var persistence: PersistenceController!
    var programRepo: ProgramRepository!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        programRepo = ProgramRepository(persistence: persistence)
    }

    override func tearDown() {
        programRepo = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveProgram_createsNewProgram() throws {
        // Given
        let program = Program.fixture(
            name: "Strength Block",
            durationWeeks: 8,
            progressionEnabled: true
        )

        // When
        programRepo.save(program)
        let loaded = programRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Strength Block")
        XCTAssertEqual(loaded.first?.durationWeeks, 8)
        XCTAssertEqual(loaded.first?.progressionEnabled, true)
    }

    func testSaveProgram_preservesWorkoutSlots() throws {
        // Given
        let workoutId = UUID()
        let slot = ProgramWorkoutSlot.weekly(
            workoutId: workoutId,
            workoutName: "Push Day",
            dayOfWeek: 1  // Monday
        )
        let program = Program.fixture(
            name: "Weekly Program",
            workoutSlots: [slot]
        )

        // When
        programRepo.save(program)
        let loaded = programRepo.loadAll()

        // Then
        XCTAssertEqual(loaded.first?.workoutSlots.count, 1)
        XCTAssertEqual(loaded.first?.workoutSlots.first?.workoutId, workoutId)
        XCTAssertEqual(loaded.first?.workoutSlots.first?.workoutName, "Push Day")
        XCTAssertEqual(loaded.first?.workoutSlots.first?.dayOfWeek, 1)
    }

    // MARK: - Delete Tests

    func testDeleteProgram_removesFromStorage() throws {
        // Given
        let program = Program.fixture(name: "To Delete")
        programRepo.save(program)
        XCTAssertEqual(programRepo.loadAll().count, 1)

        // When
        programRepo.delete(program)

        // Then
        XCTAssertEqual(programRepo.loadAll().count, 0)
    }

    // MARK: - Active Program Tests

    func testActiveProgram_onlyOneCanBeActive() throws {
        // Given
        var program1 = Program.fixture(name: "Program 1", isActive: true)
        var program2 = Program.fixture(name: "Program 2", isActive: false)

        programRepo.save(program1)
        programRepo.save(program2)

        // When - Set program2 as active
        program2.isActive = true
        programRepo.save(program2)

        // Manually deactivate program1 (simulating what the app would do)
        program1.isActive = false
        programRepo.save(program1)

        // Then
        let loaded = programRepo.loadAll()
        let activePrograms = loaded.filter { $0.isActive }

        XCTAssertEqual(activePrograms.count, 1)
        XCTAssertEqual(activePrograms.first?.name, "Program 2")
    }

    func testFindActiveProgram_returnsActiveProgram() throws {
        // Given
        programRepo.save(Program.fixture(name: "Inactive 1", isActive: false))
        programRepo.save(Program.fixture(name: "Active Program", isActive: true))
        programRepo.save(Program.fixture(name: "Inactive 2", isActive: false))

        // When
        let active = programRepo.loadAll().first { $0.isActive }

        // Then
        XCTAssertNotNil(active)
        XCTAssertEqual(active?.name, "Active Program")
    }

    // MARK: - Round-trip Tests

    func testProgramConversion_roundTripPreservesData() throws {
        // Given
        let workoutId = UUID()
        let slot = ProgramWorkoutSlot(
            workoutId: workoutId,
            workoutName: "Monday Workout",
            scheduleType: .weekly,
            dayOfWeek: 1,
            order: 0,
            notes: "Start week strong"
        )
        let original = Program(
            id: UUID(),
            name: "12-Week Program",
            programDescription: "Progressive overload program",
            durationWeeks: 12,
            startDate: Date(),
            isActive: true,
            workoutSlots: [slot],
            progressionEnabled: true
        )

        // When
        programRepo.save(original)
        let loaded = programRepo.find(id: original.id)

        // Then
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "12-Week Program")
        XCTAssertEqual(loaded?.programDescription, "Progressive overload program")
        XCTAssertEqual(loaded?.durationWeeks, 12)
        XCTAssertEqual(loaded?.isActive, true)
        XCTAssertEqual(loaded?.progressionEnabled, true)
        XCTAssertEqual(loaded?.workoutSlots.count, 1)
        XCTAssertEqual(loaded?.workoutSlots.first?.notes, "Start week strong")
    }

    func testProgramConversion_roundTripPreservesExerciseProgressionStates() throws {
        // Given
        let exerciseId = UUID()
        let state = ExerciseProgressionState(
            lastPrescribedWeight: 135,
            lastPrescribedReps: 8,
            successStreak: 2,
            failStreak: 0,
            recentOutcomes: [.progress, .stay],
            confidence: 0.8,
            lastUpdatedAt: Date()
        )
        let original = Program(
            id: UUID(),
            name: "Stateful Program",
            progressionEnabled: true,
            progressionPolicy: .adaptive,
            progressionEnabledExercises: Set([exerciseId]),
            exerciseProgressionStates: [exerciseId: state]
        )

        // When
        programRepo.save(original)
        let loaded = programRepo.find(id: original.id)
        let loadedState = loaded?.exerciseProgressionStates[exerciseId]

        // Then
        XCTAssertNotNil(loaded)
        XCTAssertNotNil(loadedState)
        XCTAssertEqual(loadedState?.lastPrescribedWeight, 135)
        XCTAssertEqual(loadedState?.lastPrescribedReps, 8)
        XCTAssertEqual(loadedState?.successStreak, 2)
        XCTAssertEqual(loadedState?.failStreak, 0)
        XCTAssertEqual(loadedState?.recentOutcomes, [.progress, .stay])
        XCTAssertEqual(loadedState?.confidence, 0.8)
    }

    func testSetProgressionEnabled_disablingClearsOverrideAndState() {
        // Given
        let exerciseId = UUID()
        var program = Program.fixture(progressionEnabled: true)
        program.setProgressionEnabled(true, for: exerciseId)
        program.setProgressionOverride(.moderate, for: exerciseId)
        program.setProgressionState(
            ExerciseProgressionState(successStreak: 2, confidence: 0.8),
            for: exerciseId
        )

        // When
        program.setProgressionEnabled(false, for: exerciseId)

        // Then
        XCTAssertFalse(program.progressionEnabledExercises.contains(exerciseId))
        XCTAssertNil(program.exerciseProgressionOverrides[exerciseId])
        XCTAssertNil(program.exerciseProgressionStates[exerciseId])
    }
}

// MARK: - Integration Tests (Multiple Repositories)

@MainActor
final class DataRepositoryIntegrationTests: XCTestCase {
    var persistence: PersistenceController!
    var moduleRepo: ModuleRepository!
    var workoutRepo: WorkoutRepository!
    var sessionRepo: SessionRepository!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        moduleRepo = ModuleRepository(persistence: persistence)
        workoutRepo = WorkoutRepository(persistence: persistence)
        sessionRepo = SessionRepository(persistence: persistence)
    }

    override func tearDown() {
        moduleRepo = nil
        workoutRepo = nil
        sessionRepo = nil
        persistence = nil
        super.tearDown()
    }

    func testModuleWorkoutSession_fullWorkflow() throws {
        // Given - Create a module
        let exercise = ExerciseInstance.fixture(name: "Barbell Squat")
        let module = Module.fixture(name: "Leg Strength", exercises: [exercise])
        moduleRepo.save(module)

        // Create a workout referencing the module
        let moduleRef = ModuleReference(moduleId: module.id, order: 0)
        let workout = Workout.fixture(name: "Leg Day", moduleReferences: [moduleRef])
        workoutRepo.save(workout)

        // Create a session for the workout
        let setData = SetData.fixture(weight: 135, reps: 8)
        let completedSetGroup = CompletedSetGroup.fixture(sets: [setData])
        let sessionExercise = SessionExercise.fixture(
            exerciseName: "Barbell Squat",
            completedSetGroups: [completedSetGroup]
        )
        let completedModule = CompletedModule.fixture(
            moduleId: module.id,
            moduleName: "Leg Strength",
            completedExercises: [sessionExercise]
        )
        let session = Session.fixture(
            workoutId: workout.id,
            workoutName: "Leg Day",
            completedModules: [completedModule]
        )
        sessionRepo.save(session)

        // Then - Verify the full chain
        let loadedModules = moduleRepo.loadAll()
        let loadedWorkouts = workoutRepo.loadAll()
        let loadedSessions = sessionRepo.loadAll()

        XCTAssertEqual(loadedModules.count, 1)
        XCTAssertEqual(loadedWorkouts.count, 1)
        XCTAssertEqual(loadedSessions.count, 1)

        // Verify workout references module
        XCTAssertEqual(loadedWorkouts.first?.moduleReferences.first?.moduleId, module.id)

        // Verify session references workout
        XCTAssertEqual(loadedSessions.first?.workoutId, workout.id)

        // Verify session captured module data
        XCTAssertEqual(loadedSessions.first?.completedModules.first?.moduleId, module.id)
        XCTAssertEqual(loadedSessions.first?.completedModules.first?.completedExercises.first?.exerciseName, "Barbell Squat")
    }

    func testDeleteModule_workoutReferenceRemains() throws {
        // Given - Module referenced by workout
        let module = Module.fixture(name: "To Delete Module")
        moduleRepo.save(module)

        let moduleRef = ModuleReference(moduleId: module.id, order: 0)
        let workout = Workout.fixture(name: "References Deleted", moduleReferences: [moduleRef])
        workoutRepo.save(workout)

        // When - Delete the module
        moduleRepo.delete(module)

        // Then - Workout still exists with reference (orphaned reference is OK - UI handles this)
        let loadedWorkouts = workoutRepo.loadAll()
        XCTAssertEqual(loadedWorkouts.count, 1)
        XCTAssertEqual(loadedWorkouts.first?.moduleReferences.first?.moduleId, module.id)
    }
}
