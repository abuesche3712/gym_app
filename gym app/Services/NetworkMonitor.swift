//
//  NetworkMonitor.swift
//  gym app
//
//  Monitors network connectivity status
//

import Foundation
import Network

class NetworkMonitorService: ObservableObject {
    static let shared = NetworkMonitorService()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }

        monitor.start(queue: queue)
    }
}
