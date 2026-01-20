//
//  Logger.swift
//  gym app
//
//  Centralized logging utility with debug/release awareness
//

import Foundation
import FirebaseCrashlytics

/// Centralized logging utility that respects debug/release configuration
enum Logger {
    // MARK: - General Logging

    /// Debug-only log. Stripped from release builds entirely.
    /// Use for development/troubleshooting messages.
    static func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let filename = file.split(separator: "/").last.map(String.init) ?? file
        print("[\(filename):\(line)] \(function): \(message())")
        #endif
    }

    /// Verbose log for detailed tracing. Only prints in DEBUG with verbose logging enabled.
    static func verbose(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function
    ) {
        #if DEBUG
        guard AppConfig.enableVerboseLogging else { return }
        let filename = file.split(separator: "/").last.map(String.init) ?? file
        print("[VERBOSE] [\(filename).\(function)] \(message())")
        #endif
    }

    /// Info log. Prints in DEBUG builds only.
    static func info(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[INFO] \(message())")
        #endif
    }

    /// Warning log. Prints in DEBUG builds only.
    static func warning(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[WARN] \(message())")
        #endif
    }

    /// Error log. Always logs (DEBUG and RELEASE) as errors indicate issues that need attention.
    /// Does NOT include sensitive data - sanitize before calling.
    static func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let filename = file.split(separator: "/").last.map(String.init) ?? file
        print("[ERROR] [\(filename):\(line)] \(message)")

        // Record to Crashlytics for production error tracking
        let error = NSError(
            domain: "com.gymapp.error",
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                "file": filename,
                "line": line,
                "function": function
            ]
        )
        Crashlytics.crashlytics().record(error: error)
    }

    /// Log an Error object. Always logs.
    static func error(
        _ error: Error,
        context: String,
        file: String = #file,
        line: Int = #line
    ) {
        let filename = file.split(separator: "/").last.map(String.init) ?? file
        print("[ERROR] [\(filename):\(line)] \(context): \(error.localizedDescription)")

        // Record to Crashlytics with context
        Crashlytics.crashlytics().setCustomValue(context, forKey: "error_context")
        Crashlytics.crashlytics().setCustomValue(filename, forKey: "file")
        Crashlytics.crashlytics().setCustomValue(line, forKey: "line")
        Crashlytics.crashlytics().record(error: error)
    }

    // MARK: - Sync-Specific Logging

    /// Sync operation log. Uses SyncLogger for persistence in DEBUG/TestFlight.
    /// These logs are viewable in the Debug Sync Logs UI.
    @MainActor
    static func sync(_ message: String, context: String, severity: SyncLogSeverity = .info) {
        guard AppConfig.enableSyncLogging else { return }

        // Use SyncLogger for persistent logging
        SyncLogger.shared.log(message, context: context, severity: severity)
    }

    /// Sync info log
    @MainActor
    static func syncInfo(_ message: String, context: String) {
        sync(message, context: context, severity: .info)
    }

    /// Sync warning log
    @MainActor
    static func syncWarning(_ message: String, context: String) {
        sync(message, context: context, severity: .warning)
    }

    /// Sync error log
    @MainActor
    static func syncError(_ message: String, context: String) {
        sync(message, context: context, severity: .error)
    }

    /// Sync error log with Error object
    @MainActor
    static func syncError(_ error: Error, context: String, additionalInfo: String? = nil) {
        guard AppConfig.enableSyncLogging else { return }
        SyncLogger.shared.logError(error, context: context, additionalInfo: additionalInfo)
    }

    // MARK: - Performance Logging

    /// Log performance timing for an operation.
    /// Only logs if duration exceeds threshold and performance logging is enabled.
    static func performance(
        _ operation: String,
        duration: TimeInterval,
        threshold: TimeInterval = AppConfig.slowLoadThreshold
    ) {
        #if DEBUG
        guard AppConfig.enablePerformanceLogging else { return }
        guard duration >= threshold else { return }

        let ms = Int(duration * 1000)
        print("[PERF] \(operation) took \(ms)ms (threshold: \(Int(threshold * 1000))ms)")
        #endif
    }

    /// Measure and log the duration of a synchronous operation
    @discardableResult
    static func measure<T>(
        _ operation: String,
        threshold: TimeInterval = AppConfig.slowLoadThreshold,
        block: () throws -> T
    ) rethrows -> T {
        #if DEBUG
        guard AppConfig.enablePerformanceLogging else {
            return try block()
        }

        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - start

        if duration >= threshold {
            let ms = Int(duration * 1000)
            print("[PERF] \(operation) took \(ms)ms")
        }

        return result
        #else
        return try block()
        #endif
    }

    /// Measure and log the duration of an async operation
    @discardableResult
    static func measureAsync<T>(
        _ operation: String,
        threshold: TimeInterval = AppConfig.slowLoadThreshold,
        block: () async throws -> T
    ) async rethrows -> T {
        #if DEBUG
        guard AppConfig.enablePerformanceLogging else {
            return try await block()
        }

        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - start

        if duration >= threshold {
            let ms = Int(duration * 1000)
            print("[PERF] \(operation) took \(ms)ms")
        }

        return result
        #else
        return try await block()
        #endif
    }

    // MARK: - Sensitive Data Helpers

    /// Redact a UUID for logging (shows first 8 chars only)
    static func redactUUID(_ uuid: UUID) -> String {
        let str = uuid.uuidString
        return String(str.prefix(8)) + "..."
    }

    /// Redact a user ID for logging
    static func redactUserID(_ userId: String) -> String {
        guard userId.count > 4 else { return "***" }
        return String(userId.prefix(4)) + "..."
    }

    /// Redact an email for logging
    static func redactEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else { return "***@***" }
        let prefix = String(email[..<atIndex].prefix(2))
        let domain = String(email[atIndex...])
        return prefix + "***" + domain
    }
}

// MARK: - Performance Timer Helper

/// Helper class for timing operations that span multiple calls
final class PerformanceTimer {
    private let operation: String
    private let threshold: TimeInterval
    private let start: CFAbsoluteTime

    init(_ operation: String, threshold: TimeInterval = AppConfig.slowLoadThreshold) {
        self.operation = operation
        self.threshold = threshold
        self.start = CFAbsoluteTimeGetCurrent()
    }

    func stop() {
        #if DEBUG
        guard AppConfig.enablePerformanceLogging else { return }
        let duration = CFAbsoluteTimeGetCurrent() - start
        Logger.performance(operation, duration: duration, threshold: threshold)
        #endif
    }

    deinit {
        // Auto-log if not explicitly stopped
        #if DEBUG
        let duration = CFAbsoluteTimeGetCurrent() - start
        if duration >= threshold && AppConfig.enablePerformanceLogging {
            Logger.performance(operation, duration: duration, threshold: threshold)
        }
        #endif
    }
}
