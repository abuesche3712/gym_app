//
//  AppState.swift
//  gym app
//
//  Global app state and settings
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // ViewModels
    @Published var moduleViewModel: ModuleViewModel
    @Published var workoutViewModel: WorkoutViewModel
    @Published var sessionViewModel: SessionViewModel
    @Published var programViewModel: ProgramViewModel

    // Settings
    @Published var weightUnit: WeightUnit {
        didSet {
            UserDefaults.standard.set(weightUnit.rawValue, forKey: "weightUnit")
            syncUserProfileToCloud()
        }
    }
    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
            syncUserProfileToCloud()
        }
    }
    @Published var defaultRestTime: Int {
        didSet {
            UserDefaults.standard.set(defaultRestTime, forKey: "defaultRestTime")
            syncUserProfileToCloud()
        }
    }

    // Sync state
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    private let repository = DataRepository.shared
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.moduleViewModel = ModuleViewModel(repository: repository)
        let workoutVM = WorkoutViewModel(repository: repository)
        self.workoutViewModel = workoutVM
        self.sessionViewModel = SessionViewModel(repository: repository)
        self.programViewModel = ProgramViewModel(repository: repository, workoutViewModel: workoutVM)

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

        setupSyncNotifications()
    }

    // MARK: - Sync Notifications

    private func setupSyncNotifications() {
        // Listen for user profile synced from cloud
        NotificationCenter.default.publisher(for: .userProfileSyncedFromCloud)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let profile = notification.object as? UserProfile {
                    self?.applyUserProfile(profile)
                }
            }
            .store(in: &cancellables)

        // Listen for request to push user profile to cloud
        NotificationCenter.default.publisher(for: .requestUserProfileForSync)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.pushUserProfileToCloud()
                }
            }
            .store(in: &cancellables)
    }

    private func applyUserProfile(_ profile: UserProfile) {
        // Update local settings without triggering sync back to cloud
        UserDefaults.standard.set(profile.weightUnit.rawValue, forKey: "weightUnit")
        UserDefaults.standard.set(profile.distanceUnit.rawValue, forKey: "distanceUnit")
        UserDefaults.standard.set(profile.defaultRestTime, forKey: "defaultRestTime")

        // Update published properties (will trigger didSet but we check auth below)
        weightUnit = profile.weightUnit
        distanceUnit = profile.distanceUnit
        defaultRestTime = profile.defaultRestTime
    }

    private func syncUserProfileToCloud() {
        guard authService.isAuthenticated else { return }
        Task {
            await pushUserProfileToCloud()
        }
    }

    private func pushUserProfileToCloud() async {
        guard authService.isAuthenticated else { return }
        let profile = UserProfile(
            weightUnit: weightUnit,
            distanceUnit: distanceUnit,
            defaultRestTime: defaultRestTime
        )
        do {
            try await firestoreService.saveUserProfile(profile)
        } catch {
            print("Failed to sync user profile to cloud: \(error)")
        }
    }

    func refreshAllData() {
        moduleViewModel.loadModules()
        workoutViewModel.loadWorkouts()
        sessionViewModel.loadSessions()
        programViewModel.loadPrograms()
    }

    func triggerSync() async {
        guard authService.isAuthenticated else {
            print("triggerSync: Not authenticated")
            return
        }

        isSyncing = true

        // Sync from cloud first (gets latest data)
        await repository.syncFromCloud()

        // Then push any local changes
        await repository.pushAllToCloud()

        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        isSyncing = false

        // Refresh all view models
        refreshAllData()
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
