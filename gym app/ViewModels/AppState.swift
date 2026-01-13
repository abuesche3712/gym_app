//
//  AppState.swift
//  gym app
//
//  Global app state and settings
//

import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // ViewModels
    @Published var moduleViewModel: ModuleViewModel
    @Published var workoutViewModel: WorkoutViewModel
    @Published var sessionViewModel: SessionViewModel

    // Settings
    @Published var weightUnit: WeightUnit {
        didSet {
            UserDefaults.standard.set(weightUnit.rawValue, forKey: "weightUnit")
        }
    }
    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
        }
    }
    @Published var defaultRestTime: Int {
        didSet {
            UserDefaults.standard.set(defaultRestTime, forKey: "defaultRestTime")
        }
    }

    // Sync state
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    init() {
        let repository = DataRepository.shared

        self.moduleViewModel = ModuleViewModel(repository: repository)
        self.workoutViewModel = WorkoutViewModel(repository: repository)
        self.sessionViewModel = SessionViewModel(repository: repository)

        // Load settings
        if let weightRaw = UserDefaults.standard.string(forKey: "weightUnit"),
           let unit = WeightUnit(rawValue: weightRaw) {
            self.weightUnit = unit
        } else {
            self.weightUnit = .lbs
        }

        if let distanceRaw = UserDefaults.standard.string(forKey: "distanceUnit"),
           let unit = DistanceUnit(rawValue: distanceRaw) {
            self.distanceUnit = unit
        } else {
            self.distanceUnit = .miles
        }

        self.defaultRestTime = UserDefaults.standard.integer(forKey: "defaultRestTime")
        if self.defaultRestTime == 0 {
            self.defaultRestTime = 90 // default 90 seconds
        }

        if let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            self.lastSyncDate = lastSync
        }
    }

    func refreshAllData() {
        moduleViewModel.loadModules()
        workoutViewModel.loadWorkouts()
        sessionViewModel.loadSessions()
    }

    func triggerSync() async {
        isSyncing = true
        // TODO: Implement Firebase sync
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate sync
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        isSyncing = false
    }
}

// MARK: - Environment Key

struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState = AppState.shared
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
