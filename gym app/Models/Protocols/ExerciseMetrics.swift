//
//  ExerciseMetrics.swift
//  gym app
//
//  Protocol for types that have exercise tracking metadata.
//  Consolidates computed properties that were duplicated across
//  ExerciseTemplate, ResolvedExercise, and SessionExercise.
//

import Foundation

protocol ExerciseMetrics {
    var exerciseType: ExerciseType { get }
    var cardioMetric: CardioMetric { get }
    var mobilityTracking: MobilityTracking { get }
    var supersetGroupId: UUID? { get }
}

extension ExerciseMetrics {
    /// Whether this exercise tracks time (cardio with time tracking)
    var tracksTime: Bool {
        exerciseType == .cardio && cardioMetric.tracksTime
    }

    /// Whether this exercise tracks distance (cardio with distance tracking)
    var tracksDistance: Bool {
        exerciseType == .cardio && cardioMetric.tracksDistance
    }

    /// Whether this is a distance-only cardio exercise
    var isDistanceBased: Bool {
        exerciseType == .cardio && cardioMetric == .distanceOnly
    }

    /// Whether this mobility exercise tracks reps
    var mobilityTracksReps: Bool {
        exerciseType == .mobility && mobilityTracking.tracksReps
    }

    /// Whether this mobility exercise tracks duration
    var mobilityTracksDuration: Bool {
        exerciseType == .mobility && mobilityTracking.tracksDuration
    }

    /// Whether this exercise is part of a superset
    var isInSuperset: Bool {
        supersetGroupId != nil
    }
}
