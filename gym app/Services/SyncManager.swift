//
//  SyncManager.swift
//  gym app
//
//  Manages local-first data sync with Firebase
//  NOTE: Firebase disabled for now - local-only mode
//

import Foundation
import Network
import Combine

class SyncManager: ObservableObject {
    static let shared = SyncManager()

    private let firebaseService = FirebaseService.shared
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var pendingSyncCount = 0
    @Published var syncEnabled = false  // Disabled until Firebase works

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupNetworkMonitoring()
        loadLastSyncDate()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied

                // Auto-sync when coming back online (if enabled)
                if path.status == .satisfied && self?.syncEnabled == true {
                    Task {
                        await self?.syncIfNeeded()
                    }
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Sync Operations

    @MainActor
    func syncAll() async {
        guard syncEnabled else {
            print("Sync disabled - local only mode")
            return
        }

        guard isOnline else {
            print("Offline - skipping sync")
            return
        }

        guard !isSyncing else {
            print("Sync already in progress")
            return
        }

        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
            saveLastSyncDate()
        }

        do {
            // Ensure authenticated
            if !firebaseService.isAuthenticated {
                try await firebaseService.signInAnonymously()
            }

            // Get local data
            let repository = DataRepository.shared

            // Sync modules
            try await firebaseService.syncModules(repository.modules)

            // Sync workouts
            try await firebaseService.syncWorkouts(repository.workouts)

            // Sync sessions
            try await firebaseService.syncSessions(repository.sessions)

            print("Sync completed successfully")
        } catch {
            print("Sync failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    func syncIfNeeded() async {
        guard syncEnabled else { return }

        // Only sync if we haven't synced recently (within 5 minutes)
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < 300 {
            return
        }

        await syncAll()
    }

    @MainActor
    func pullFromCloud() async {
        guard syncEnabled else { return }
        guard isOnline else { return }

        do {
            if !firebaseService.isAuthenticated {
                try await firebaseService.signInAnonymously()
            }

            // Fetch from cloud
            let remoteModules = try await firebaseService.fetchModules()
            let remoteWorkouts = try await firebaseService.fetchWorkouts()
            let remoteSessions = try await firebaseService.fetchSessions()

            // Merge with local (last-write-wins for MVP)
            let repository = DataRepository.shared

            for remoteModule in remoteModules {
                if let localModule = repository.getModule(id: remoteModule.id) {
                    if remoteModule.updatedAt > localModule.updatedAt {
                        repository.saveModule(remoteModule)
                    }
                } else {
                    repository.saveModule(remoteModule)
                }
            }

            for remoteWorkout in remoteWorkouts {
                if let localWorkout = repository.getWorkout(id: remoteWorkout.id) {
                    if remoteWorkout.updatedAt > localWorkout.updatedAt {
                        repository.saveWorkout(remoteWorkout)
                    }
                } else {
                    repository.saveWorkout(remoteWorkout)
                }
            }

            // Sessions are immutable, so just add any missing ones
            let localSessionIds = Set(repository.sessions.map { $0.id })
            for remoteSession in remoteSessions {
                if !localSessionIds.contains(remoteSession.id) {
                    repository.saveSession(remoteSession)
                }
            }

            repository.loadAllData()

        } catch {
            print("Pull from cloud failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Persistence

    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
    }
}

// MARK: - App Lifecycle Integration

extension SyncManager {
    func appDidBecomeActive() {
        guard syncEnabled else { return }
        Task { @MainActor in
            await syncIfNeeded()
        }
    }

    func appWillResignActive() {
        guard syncEnabled else { return }
        Task { @MainActor in
            await syncAll()
        }
    }
}
