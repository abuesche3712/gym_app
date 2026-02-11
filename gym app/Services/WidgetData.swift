//
//  WidgetData.swift
//  gym app
//
//  Shared data model for the Today's Workout widget
//  Used by both the main app and the widget extension
//

import Foundation
import WidgetKit

/// Data passed from the main app to the widget via App Groups
struct TodayWorkoutData: Codable {
    let workoutName: String?
    let moduleNames: [String]
    let isRestDay: Bool
    let isCompleted: Bool
    let lastUpdated: Date

    /// Rest day placeholder
    static let restDay = TodayWorkoutData(
        workoutName: nil,
        moduleNames: [],
        isRestDay: true,
        isCompleted: false,
        lastUpdated: Date()
    )

    /// No workout scheduled placeholder
    static let noWorkout = TodayWorkoutData(
        workoutName: nil,
        moduleNames: [],
        isRestDay: false,
        isCompleted: false,
        lastUpdated: Date()
    )
}

/// Service for reading/writing widget data via App Groups
enum WidgetDataService {
    // IMPORTANT: This must match the App Group configured in both targets
    // Update this if your App Group name is different
    static let appGroupIdentifier = "group.UI.gym-app"
    static let widgetDataKey = "todayWorkoutData"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// Write today's workout data for the widget
    static func writeTodayWorkout(_ data: TodayWorkoutData) {
        guard let defaults = sharedDefaults else {
            Logger.warning("Failed to access App Group UserDefaults")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            defaults.set(encoded, forKey: widgetDataKey)
            Logger.debug("Widget data updated: \(data.workoutName ?? "Rest/None")")
        } catch {
            Logger.error(error, context: "Widget failed to encode data")
        }
    }

    /// Read today's workout data (used by widget)
    static func readTodayWorkout() -> TodayWorkoutData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: widgetDataKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(TodayWorkoutData.self, from: data)
        } catch {
            return nil
        }
    }

    /// Request widget timeline refresh
    static func refreshWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayWorkoutWidget")
    }
}
