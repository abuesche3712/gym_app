//
//  QuickLogViewModel.swift
//  gym app
//
//  ViewModel for the Quick Log feature
//

import Foundation
import SwiftUI

// MARK: - Quick Log Preset

struct QuickLogPreset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let exerciseType: ExerciseType
    let icon: String
    let metrics: [QuickLogMetric]

    static func == (lhs: QuickLogPreset, rhs: QuickLogPreset) -> Bool {
        lhs.id == rhs.id
    }
}

enum QuickLogMetric: String, CaseIterable {
    case distance
    case duration
    case weight
    case reps
    case temperature
    case holdTime
    case intensity
    case height

    var label: String {
        switch self {
        case .distance: return "Distance"
        case .duration: return "Duration"
        case .weight: return "Weight"
        case .reps: return "Reps"
        case .temperature: return "Temperature"
        case .holdTime: return "Hold Time"
        case .intensity: return "Intensity"
        case .height: return "Height"
        }
    }

    var unit: String? {
        switch self {
        case .distance: return "mi"
        case .duration: return nil  // Displayed as time picker
        case .weight: return "lbs"
        case .reps: return nil
        case .temperature: return "°F"
        case .holdTime: return nil  // Displayed as time picker
        case .intensity: return "/10"
        case .height: return "in"
        }
    }
}

// MARK: - Default Presets

let defaultQuickLogPresets: [QuickLogPreset] = [
    QuickLogPreset(
        name: "Run",
        exerciseType: .cardio,
        icon: "figure.run",
        metrics: [.distance, .duration]
    ),
    QuickLogPreset(
        name: "Bike",
        exerciseType: .cardio,
        icon: "bicycle",
        metrics: [.distance, .duration]
    ),
    QuickLogPreset(
        name: "Swim",
        exerciseType: .cardio,
        icon: "figure.pool.swim",
        metrics: [.distance, .duration]
    ),
    QuickLogPreset(
        name: "Walk",
        exerciseType: .cardio,
        icon: "figure.walk",
        metrics: [.distance, .duration]
    ),
    QuickLogPreset(
        name: "Sauna",
        exerciseType: .recovery,
        icon: "flame",
        metrics: [.duration, .temperature]
    ),
    QuickLogPreset(
        name: "Cold Plunge",
        exerciseType: .recovery,
        icon: "snowflake",
        metrics: [.duration, .temperature]
    ),
    QuickLogPreset(
        name: "Stretch",
        exerciseType: .mobility,
        icon: "figure.flexibility",
        metrics: [.duration]
    ),
    QuickLogPreset(
        name: "Yoga",
        exerciseType: .mobility,
        icon: "figure.mind.and.body",
        metrics: [.duration]
    )
]

// MARK: - ViewModel

@MainActor
class QuickLogViewModel: ObservableObject {
    @Published var selectedPreset: QuickLogPreset?
    @Published var isCustom: Bool = false
    @Published var customName: String = ""
    @Published var exerciseType: ExerciseType = .cardio

    // Metric values
    @Published var distance: String = ""
    @Published var duration: Int = 0  // seconds
    @Published var weight: String = ""
    @Published var reps: String = ""
    @Published var temperature: String = ""
    @Published var holdTime: Int = 0  // seconds
    @Published var intensity: String = ""
    @Published var height: String = ""
    @Published var notes: String = ""
    @Published var logDate: Date = Date()

    let presets = defaultQuickLogPresets

    var exerciseName: String {
        if isCustom {
            return customName
        }
        return selectedPreset?.name ?? ""
    }

    var resolvedExerciseType: ExerciseType {
        if isCustom {
            return exerciseType
        }
        return selectedPreset?.exerciseType ?? exerciseType
    }

    var activeMetrics: [QuickLogMetric] {
        if isCustom {
            return metricsForExerciseType(exerciseType)
        }
        return selectedPreset?.metrics ?? []
    }

    var canSave: Bool {
        !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasAtLeastOneMetric
    }

    private var hasAtLeastOneMetric: Bool {
        !distance.isEmpty ||
        duration > 0 ||
        !weight.isEmpty ||
        !reps.isEmpty ||
        !temperature.isEmpty ||
        holdTime > 0 ||
        !intensity.isEmpty ||
        !height.isEmpty
    }

    func save() -> Session {
        var metrics = SetData(setNumber: 1)
        metrics.distance = Double(distance)
        metrics.duration = duration > 0 ? duration : nil
        metrics.weight = Double(weight)
        metrics.reps = Int(reps)
        metrics.temperature = Int(temperature)
        metrics.holdTime = holdTime > 0 ? holdTime : nil
        metrics.intensity = Int(intensity)
        metrics.height = Double(height)
        metrics.completed = true

        return QuickLogService.shared.createQuickLog(
            exerciseName: exerciseName,
            exerciseType: resolvedExerciseType,
            metrics: metrics,
            notes: notes.isEmpty ? nil : notes,
            date: logDate
        )
    }

    func selectPreset(_ preset: QuickLogPreset) {
        selectedPreset = preset
        isCustom = false
        clearMetrics()

        // Set default temperature for sauna/cold plunge
        if preset.name == "Sauna" {
            temperature = "180"
        } else if preset.name == "Cold Plunge" {
            temperature = "50"
        }
    }

    func selectCustom() {
        selectedPreset = nil
        isCustom = true
        clearMetrics()
    }

    func clearMetrics() {
        distance = ""
        duration = 0
        weight = ""
        reps = ""
        temperature = ""
        holdTime = 0
        intensity = ""
        height = ""
    }

    private func metricsForExerciseType(_ type: ExerciseType) -> [QuickLogMetric] {
        switch type {
        case .cardio:
            return [.distance, .duration]
        case .strength:
            return [.weight, .reps]
        case .isometric:
            return [.holdTime, .intensity]
        case .mobility:
            return [.duration, .reps]
        case .explosive:
            return [.reps, .height]
        case .recovery:
            return [.duration, .temperature]
        }
    }
}
