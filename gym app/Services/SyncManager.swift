//
//  SyncManager.swift
//  gym app
//
//  Manages local-first data sync with Firebase
//  Now uses AuthService and FirestoreService
//

import Foundation
import Network
import Combine

@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()

    private let authService = AuthService.shared
    private let dataRepository = DataRepository.shared
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    @Published var isOnline = true
    @Published var lastSyncDate: Date?
    @Published var pendingSyncCount = 0

    /// Sync is enabled when user is authenticated
    var syncEnabled: Bool {
        authService.isAuthenticated
    }

    var isSyncing: Bool {
        dataRepository.isSyncing
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupNetworkMonitoring()
        loadLastSyncDate()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isOnline = isOnline

                // Auto-sync when coming back online (if authenticated)
                if isOnline && self.syncEnabled {
                    await self.syncIfNeeded()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Sync Operations

    func syncAll() async {
        guard syncEnabled else {
            print("Sync disabled - not authenticated")
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

        await dataRepository.syncFromCloud()
        lastSyncDate = Date()
        saveLastSyncDate()
    }

    func syncIfNeeded() async {
        guard syncEnabled else { return }

        // Only sync if we haven't synced recently (within 5 minutes)
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < 300 {
            return
        }

        await syncAll()
    }

    func pullFromCloud() async {
        guard syncEnabled else { return }
        guard isOnline else { return }

        await dataRepository.syncFromCloud()
    }

    func pushToCloud() async {
        guard syncEnabled else { return }
        guard isOnline else { return }

        await dataRepository.pushAllToCloud()
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
