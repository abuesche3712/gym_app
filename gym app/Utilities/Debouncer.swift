//
//  Debouncer.swift
//  gym app
//
//  Simple debouncer utility to coalesce rapid-fire events
//

import Foundation

/// A simple debouncer that delays execution until events stop coming
/// Useful for auto-save operations to avoid excessive writes
final class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue

    /// Initialize with a delay interval
    /// - Parameters:
    ///   - delay: Time to wait after the last call before executing
    ///   - queue: Queue to execute on (defaults to main)
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    /// Schedule an action to run after the delay
    /// If called again before the delay expires, the previous action is cancelled
    /// - Parameter action: The closure to execute
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        if let workItem = workItem {
            queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    /// Cancel any pending action
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }

    /// Execute immediately if there's a pending action
    func flush() {
        if let workItem = workItem, !workItem.isCancelled {
            workItem.perform()
            self.workItem = nil
        }
    }
}
