//
//  AppConfig.swift
//  gym app
//
//  App-wide configuration for debug/release builds
//

import Foundation

/// Central configuration for debug/release build behavior
enum AppConfig {
    // MARK: - Build Configuration

    /// Whether the app is running in DEBUG mode
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Whether this is a TestFlight build (not App Store, not Xcode)
    static var isTestFlight: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }

    /// Whether this is an App Store release build
    static var isAppStore: Bool {
        #if DEBUG
        return false
        #else
        return !isTestFlight
        #endif
    }

    // MARK: - Logging Configuration

    /// Enable detailed sync operation logging (persisted to CoreData via SyncLogger)
    /// Enabled in DEBUG and TestFlight for debugging sync issues
    static var enableSyncLogging: Bool {
        isDebug || isTestFlight
    }

    /// Enable performance timing logs for slow operations
    static var enablePerformanceLogging: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Enable verbose debug logging to console
    static var enableVerboseLogging: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - UI Configuration

    /// Show debug UI elements (debug sync logs view, etc.)
    static var showDebugUI: Bool {
        isDebug || isTestFlight
    }

    /// Show developer-only features
    static var showDeveloperFeatures: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Performance Thresholds

    /// Threshold (in seconds) for logging slow sync operations
    static let slowSyncThreshold: TimeInterval = 2.0

    /// Threshold (in seconds) for logging slow data loads
    static let slowLoadThreshold: TimeInterval = 0.5

    /// Threshold (in seconds) for logging slow CoreData saves
    static let slowSaveThreshold: TimeInterval = 0.3
}

// MARK: - Startup Crash Detection

/// Manages startup crash detection and recovery.
/// Detects crashes during startup and enables recovery mode to prevent crash loops.
enum StartupGuard {
    private static let startupInProgressKey = "StartupGuard_InProgress"
    private static let crashCountKey = "StartupGuard_CrashCount"
    private static let lastSuccessfulStartupKey = "StartupGuard_LastSuccess"
    private static let recoveryModeKey = "StartupGuard_RecoveryMode"

    /// Maximum crashes before entering recovery mode
    private static let maxCrashesBeforeRecovery = 2

    /// Whether the app is currently in recovery mode (skip risky operations)
    static var isInRecoveryMode: Bool {
        UserDefaults.standard.bool(forKey: recoveryModeKey)
    }

    /// Number of consecutive startup crashes
    static var crashCount: Int {
        UserDefaults.standard.integer(forKey: crashCountKey)
    }

    /// Call this at the very beginning of app launch (before any risky operations)
    static func markStartupBegan() {
        let wasInProgress = UserDefaults.standard.bool(forKey: startupInProgressKey)

        if wasInProgress {
            // Previous startup didn't complete - this is a crash
            let newCrashCount = crashCount + 1
            UserDefaults.standard.set(newCrashCount, forKey: crashCountKey)

            Logger.warning("StartupGuard: Detected startup crash (count: \(newCrashCount))")

            if newCrashCount >= maxCrashesBeforeRecovery {
                // Enter recovery mode
                UserDefaults.standard.set(true, forKey: recoveryModeKey)
                Logger.warning("StartupGuard: Entering recovery mode after \(newCrashCount) crashes")
            }
        }

        // Mark startup as in progress
        UserDefaults.standard.set(true, forKey: startupInProgressKey)
        UserDefaults.standard.synchronize()
    }

    /// Call this after app has successfully launched (e.g., after first view appears)
    static func markStartupSucceeded() {
        UserDefaults.standard.set(false, forKey: startupInProgressKey)
        UserDefaults.standard.set(0, forKey: crashCountKey)
        UserDefaults.standard.set(Date(), forKey: lastSuccessfulStartupKey)

        // Exit recovery mode on successful startup
        if isInRecoveryMode {
            Logger.info("StartupGuard: Exiting recovery mode after successful startup")
            UserDefaults.standard.set(false, forKey: recoveryModeKey)
        }

        UserDefaults.standard.synchronize()
    }

    /// Manually exit recovery mode (e.g., user chose to retry)
    static func exitRecoveryMode() {
        UserDefaults.standard.set(false, forKey: recoveryModeKey)
        UserDefaults.standard.set(0, forKey: crashCountKey)
        UserDefaults.standard.synchronize()
        Logger.info("StartupGuard: Manually exited recovery mode")
    }

    /// Reset all migration flags to allow retrying
    static func resetMigrationFlags() {
        UserDefaults.standard.removeObject(forKey: "ExerciseMigrationCompleted_v1")
        UserDefaults.standard.removeObject(forKey: "ExerciseTemplateIdRepair_v1")
        UserDefaults.standard.synchronize()
        Logger.info("StartupGuard: Reset all migration flags")
    }

    /// Full reset - clears all startup guard state
    static func fullReset() {
        UserDefaults.standard.removeObject(forKey: startupInProgressKey)
        UserDefaults.standard.removeObject(forKey: crashCountKey)
        UserDefaults.standard.removeObject(forKey: lastSuccessfulStartupKey)
        UserDefaults.standard.removeObject(forKey: recoveryModeKey)
        resetMigrationFlags()
        Logger.info("StartupGuard: Full reset completed")
    }
}
