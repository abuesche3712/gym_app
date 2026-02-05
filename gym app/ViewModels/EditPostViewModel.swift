//
//  EditPostViewModel.swift
//  gym app
//
//  ViewModel for editing existing posts
//

import Foundation

@MainActor
class EditPostViewModel: ObservableObject {
    @Published var caption: String
    @Published var isSaving = false
    @Published var error: Error?

    // For session posts - user-selected highlight IDs
    @Published var selectedExerciseIds: Set<UUID> = []
    @Published var selectedSetIds: [UUID: Set<UUID>] = [:]  // exerciseId -> setIds

    private let originalPost: Post
    private let postRepo: PostRepository

    // Decoded session bundle for session posts
    private(set) var sessionBundle: SessionShareBundle?
    private(set) var session: Session?

    /// The original highlight IDs from the post (for detecting changes)
    private var originalExerciseIds: Set<UUID> = []
    private var originalSetIds: [UUID: Set<UUID>] = [:]

    var hasChanges: Bool {
        if caption != (originalPost.caption ?? "") {
            return true
        }
        // For session posts, check if highlights changed
        if sessionBundle != nil {
            if selectedExerciseIds != originalExerciseIds {
                return true
            }
            if selectedSetIds != originalSetIds {
                return true
            }
        }
        return false
    }

    /// Whether this is a session post that supports highlight editing
    var isSessionPost: Bool {
        if case .session = originalPost.content {
            return true
        }
        return false
    }

    init(post: Post, postRepo: PostRepository = PostRepository()) {
        self.originalPost = post
        self.caption = post.caption ?? ""
        self.postRepo = postRepo

        // Decode session bundle if this is a session post
        if case .session(_, _, _, let snapshot) = post.content {
            if let bundle = try? SessionShareBundle.decode(from: snapshot) {
                self.sessionBundle = bundle
                self.session = bundle.session

                // Initialize selection state from existing highlights
                if let exerciseIds = bundle.highlightedExerciseIds {
                    self.selectedExerciseIds = Set(exerciseIds)
                    self.originalExerciseIds = Set(exerciseIds)
                }
                if let setIds = bundle.highlightedSetIds {
                    // Group set IDs by exercise
                    self.initializeSetSelections(setIds: setIds)
                }
            }
        }
    }

    private func initializeSetSelections(setIds: [UUID]) {
        guard let session = session else { return }

        for module in session.completedModules where !module.skipped {
            for exercise in module.completedExercises {
                for setGroup in exercise.completedSetGroups {
                    for set in setGroup.sets where set.completed && setIds.contains(set.id) {
                        var exerciseSets = selectedSetIds[exercise.id] ?? []
                        exerciseSets.insert(set.id)
                        selectedSetIds[exercise.id] = exerciseSets

                        // Also populate original state
                        var originalExerciseSets = originalSetIds[exercise.id] ?? []
                        originalExerciseSets.insert(set.id)
                        originalSetIds[exercise.id] = originalExerciseSets
                    }
                }
            }
        }
    }

    /// Number of selected highlights
    var highlightCount: Int {
        let exerciseCount = selectedExerciseIds.count
        let individualSetCount = selectedSetIds
            .filter { !selectedExerciseIds.contains($0.key) }
            .values
            .reduce(0) { $0 + $1.count }
        return exerciseCount + individualSetCount
    }

    /// Build the updated post with new caption and highlights
    func buildUpdatedPost() -> Post? {
        var updatedPost = originalPost
        updatedPost.caption = caption.isEmpty ? nil : caption
        updatedPost.updatedAt = Date()
        updatedPost.syncStatus = .pendingSync

        // For session posts, rebuild the snapshot with new highlight IDs
        if case .session(let id, let workoutName, let date, _) = originalPost.content,
           let session = session {
            // Build new bundle with updated highlights
            let exerciseIds = selectedExerciseIds.isEmpty ? nil : Array(selectedExerciseIds)
            let flatSetIds = selectedSetIds.flatMap { Array($0.value) }
            let setIds = flatSetIds.isEmpty ? nil : flatSetIds

            let newBundle = SessionShareBundle(
                session: session,
                workoutName: workoutName,
                date: date,
                highlightedExerciseIds: exerciseIds,
                highlightedSetIds: setIds
            )

            if let newSnapshot = try? newBundle.encode() {
                updatedPost.content = .session(id: id, workoutName: workoutName, date: date, snapshot: newSnapshot)
            }
        }

        return updatedPost
    }

    // MARK: - Highlight Selection

    func toggleExercise(_ exerciseId: UUID) {
        if selectedExerciseIds.contains(exerciseId) {
            selectedExerciseIds.remove(exerciseId)
        } else if highlightCount < 5 {
            selectedExerciseIds.insert(exerciseId)
            // Clear individual set selections for this exercise
            selectedSetIds[exerciseId] = nil
        }
    }

    func toggleSet(_ setId: UUID, exerciseId: UUID) {
        guard !selectedExerciseIds.contains(exerciseId) else { return }

        var exerciseSets = selectedSetIds[exerciseId] ?? []
        if exerciseSets.contains(setId) {
            exerciseSets.remove(setId)
            if exerciseSets.isEmpty {
                selectedSetIds[exerciseId] = nil
            } else {
                selectedSetIds[exerciseId] = exerciseSets
            }
        } else if highlightCount < 5 {
            exerciseSets.insert(setId)
            selectedSetIds[exerciseId] = exerciseSets
        }
    }

    func isExerciseSelected(_ exerciseId: UUID) -> Bool {
        selectedExerciseIds.contains(exerciseId)
    }

    func isSetSelected(_ setId: UUID, exerciseId: UUID) -> Bool {
        selectedExerciseIds.contains(exerciseId) || (selectedSetIds[exerciseId]?.contains(setId) ?? false)
    }

    var canSelectMore: Bool {
        highlightCount < 5
    }
}
