//
//  StrongImportService.swift
//  gym app
//
//  Service for importing workout history from Strong app CSV exports
//

import Foundation

// MARK: - CSV Row Model

struct StrongCSVRow {
    let date: Date
    let workoutName: String
    let duration: String       // Raw string like "45m", "1h 15m"
    let exerciseName: String
    let setOrder: Int
    let weight: Double         // 0 if no weight
    let reps: Int              // 0 if no reps
    let distance: Double       // 0 if no distance
    let seconds: Int           // 0 if no duration
    let notes: String          // Per-exercise notes
    let workoutNotes: String   // Per-session notes
}

// MARK: - Import Result

struct StrongImportResult {
    let sessions: [Session]
    let totalRows: Int
    let skippedRows: Int
    let exerciseNames: Set<String>
    let warnings: [String]
    let duplicateSessions: [Session]  // Sessions that may already exist
    let dateRange: (earliest: Date, latest: Date)?
}

// MARK: - Import Error

enum StrongImportError: LocalizedError {
    case emptyFile
    case noDataRows
    case invalidFormat(String)
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The file is empty"
        case .noDataRows:
            return "No workout data found in this file"
        case .invalidFormat(let details):
            return "Invalid file format: \(details)"
        case .parsingFailed(let details):
            return "Failed to parse CSV: \(details)"
        }
    }
}

// MARK: - Strong Import Service

class StrongImportService {

    // Namespace UUID for generating deterministic IDs
    private static let importNamespaceUUID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!

    // Date formatter for Strong's date format
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Main Import Function

    /// Import a Strong CSV file and convert to Session objects
    /// - Parameters:
    ///   - data: The CSV file data
    ///   - csvWeightUnit: The weight unit used in the CSV
    ///   - appWeightUnit: The current app's weight unit
    ///   - existingSessions: Existing sessions to check for duplicates
    /// - Returns: Import result with sessions and metadata
    func importCSV(
        data: Data,
        csvWeightUnit: WeightUnit,
        appWeightUnit: WeightUnit,
        existingSessions: [Session]
    ) throws -> StrongImportResult {
        // Convert data to string, stripping BOM if present
        guard var csvString = String(data: data, encoding: .utf8) else {
            throw StrongImportError.invalidFormat("Could not read file as UTF-8 text")
        }

        // Strip UTF-8 BOM if present
        if csvString.hasPrefix("\u{FEFF}") {
            csvString = String(csvString.dropFirst())
        }

        // Parse CSV rows
        let (rows, warnings, skippedCount) = try parseCSV(csvString, csvWeightUnit: csvWeightUnit, appWeightUnit: appWeightUnit)

        if rows.isEmpty {
            throw StrongImportError.noDataRows
        }

        // Group rows into sessions
        let sessions = assembleSessionsFromRows(rows)

        // Collect unique exercise names
        let exerciseNames = Set(rows.map { $0.exerciseName })

        // Find date range
        let dates = rows.map { $0.date }
        let dateRange: (Date, Date)? = dates.isEmpty ? nil : (dates.min()!, dates.max()!)

        // Check for duplicates
        let duplicates = findDuplicates(sessions: sessions, existingSessions: existingSessions)

        return StrongImportResult(
            sessions: sessions,
            totalRows: rows.count + skippedCount,
            skippedRows: skippedCount,
            exerciseNames: exerciseNames,
            warnings: warnings,
            duplicateSessions: duplicates,
            dateRange: dateRange
        )
    }

    // MARK: - CSV Parsing

    private func parseCSV(
        _ csvString: String,
        csvWeightUnit: WeightUnit,
        appWeightUnit: WeightUnit
    ) throws -> (rows: [StrongCSVRow], warnings: [String], skippedCount: Int) {
        var rows: [StrongCSVRow] = []
        var warnings: [String] = []
        var skippedCount = 0

        let lines = parseCSVLines(csvString)

        guard !lines.isEmpty else {
            throw StrongImportError.emptyFile
        }

        // Skip header row
        let dataLines = Array(lines.dropFirst())

        for (index, line) in dataLines.enumerated() {
            let lineNumber = index + 2 // +1 for header, +1 for 1-based indexing

            do {
                if let row = try parseCSVRow(line, csvWeightUnit: csvWeightUnit, appWeightUnit: appWeightUnit) {
                    rows.append(row)
                } else {
                    // Row was skipped (empty set)
                    skippedCount += 1
                }
            } catch {
                warnings.append("Line \(lineNumber): \(error.localizedDescription)")
                skippedCount += 1
            }
        }

        return (rows, warnings, skippedCount)
    }

    /// Parse CSV string into lines, handling quoted fields with newlines
    private func parseCSVLines(_ csvString: String) -> [[String]] {
        var lines: [[String]] = []
        var currentLine: [String] = []
        var currentField = ""
        var inQuotes = false

        var iterator = csvString.makeIterator()

        while let char = iterator.next() {
            if inQuotes {
                if char == "\"" {
                    // Check for escaped quote
                    if let nextChar = iterator.next() {
                        if nextChar == "\"" {
                            // Escaped quote
                            currentField.append("\"")
                        } else {
                            // End of quoted field
                            inQuotes = false
                            if nextChar == "," {
                                currentLine.append(currentField)
                                currentField = ""
                            } else if nextChar == "\n" || nextChar == "\r" {
                                currentLine.append(currentField)
                                currentField = ""
                                if !currentLine.isEmpty {
                                    lines.append(currentLine)
                                    currentLine = []
                                }
                                // Skip \r\n combination
                                if nextChar == "\r" {
                                    // Peek at next char
                                }
                            } else {
                                currentField.append(nextChar)
                            }
                        }
                    } else {
                        // End of string
                        inQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    currentLine.append(currentField)
                    currentField = ""
                } else if char == "\n" || char == "\r" {
                    currentLine.append(currentField)
                    currentField = ""
                    if !currentLine.isEmpty && currentLine.contains(where: { !$0.isEmpty }) {
                        lines.append(currentLine)
                        currentLine = []
                    }
                } else {
                    currentField.append(char)
                }
            }
        }

        // Don't forget the last field/line
        if !currentField.isEmpty || !currentLine.isEmpty {
            currentLine.append(currentField)
            if !currentLine.isEmpty && currentLine.contains(where: { !$0.isEmpty }) {
                lines.append(currentLine)
            }
        }

        return lines
    }

    /// Parse a single CSV row into a StrongCSVRow
    private func parseCSVRow(
        _ fields: [String],
        csvWeightUnit: WeightUnit,
        appWeightUnit: WeightUnit
    ) throws -> StrongCSVRow? {
        // Expected columns: Date, Workout Name, Duration, Exercise Name, Set Order, Weight, Reps, Distance, Seconds, Notes, Workout Notes
        guard fields.count >= 10 else {
            throw StrongImportError.invalidFormat("Row has \(fields.count) columns, expected at least 10")
        }

        let dateStr = fields[0].trimmingCharacters(in: .whitespaces)
        let workoutName = fields[1].trimmingCharacters(in: .whitespaces)
        let duration = fields[2].trimmingCharacters(in: .whitespaces)
        let exerciseName = fields[3].trimmingCharacters(in: .whitespaces)
        let setOrderStr = fields[4].trimmingCharacters(in: .whitespaces)
        let weightStr = fields[5].trimmingCharacters(in: .whitespaces)
        let repsStr = fields[6].trimmingCharacters(in: .whitespaces)
        let distanceStr = fields[7].trimmingCharacters(in: .whitespaces)
        let secondsStr = fields[8].trimmingCharacters(in: .whitespaces)
        let notes = fields[9].trimmingCharacters(in: .whitespaces)
        let workoutNotes = fields.count > 10 ? fields[10].trimmingCharacters(in: .whitespaces) : ""

        // Skip rows with empty exercise name
        if exerciseName.isEmpty {
            return nil
        }

        // Parse date
        guard let date = Self.dateFormatter.date(from: dateStr) else {
            throw StrongImportError.parsingFailed("Invalid date format: \(dateStr)")
        }

        // Parse numeric fields
        let setOrder = Int(setOrderStr) ?? 1
        let weight = Double(weightStr) ?? 0
        let reps = Int(repsStr) ?? 0
        let distance = Double(distanceStr) ?? 0
        let seconds = Int(secondsStr) ?? 0

        // Skip empty sets (no meaningful data)
        if weight == 0 && reps == 0 && distance == 0 && seconds == 0 {
            return nil
        }

        // Convert weight if needed
        let convertedWeight = convertWeight(weight, from: csvWeightUnit, to: appWeightUnit)

        return StrongCSVRow(
            date: date,
            workoutName: workoutName,
            duration: duration,
            exerciseName: exerciseName,
            setOrder: setOrder,
            weight: convertedWeight,
            reps: reps,
            distance: distance,
            seconds: seconds,
            notes: notes,
            workoutNotes: workoutNotes
        )
    }

    // MARK: - Weight Conversion

    private func convertWeight(_ weight: Double, from: WeightUnit, to: WeightUnit) -> Double {
        if from == to || weight == 0 {
            return weight
        }

        switch (from, to) {
        case (.kg, .lbs):
            return weight * 2.20462
        case (.lbs, .kg):
            return weight / 2.20462
        default:
            return weight
        }
    }

    // MARK: - Duration Parsing

    /// Parse Strong's duration string (e.g., "45m", "1h 15m") into minutes
    static func parseDuration(_ durationString: String) -> Int? {
        let trimmed = durationString.trimmingCharacters(in: .whitespaces).lowercased()

        if trimmed.isEmpty {
            return nil
        }

        var totalMinutes = 0

        // Try to extract hours
        if let hourRange = trimmed.range(of: #"(\d+)\s*h"#, options: .regularExpression) {
            let hourString = trimmed[hourRange]
            if let hours = Int(hourString.filter { $0.isNumber }) {
                totalMinutes += hours * 60
            }
        }

        // Try to extract minutes
        if let minRange = trimmed.range(of: #"(\d+)\s*m"#, options: .regularExpression) {
            let minString = trimmed[minRange]
            if let minutes = Int(minString.filter { $0.isNumber }) {
                totalMinutes += minutes
            }
        }

        return totalMinutes > 0 ? totalMinutes : nil
    }

    // MARK: - Session Assembly

    private func assembleSessionsFromRows(_ rows: [StrongCSVRow]) -> [Session] {
        // Group by (date, workoutName) to identify unique sessions
        var sessionGroups: [String: [StrongCSVRow]] = [:]

        for row in rows {
            let key = "\(row.date.timeIntervalSince1970)_\(row.workoutName)"
            sessionGroups[key, default: []].append(row)
        }

        // Convert each group into a Session
        var sessions: [Session] = []

        // Track workout name -> UUID mapping for deterministic IDs
        var workoutIdCache: [String: UUID] = [:]
        var exerciseIdCache: [String: UUID] = [:]

        for (_, groupRows) in sessionGroups {
            guard let firstRow = groupRows.first else { continue }

            // Get or create deterministic workout ID
            let workoutId = workoutIdCache[firstRow.workoutName] ?? generateDeterministicUUID(from: firstRow.workoutName, namespace: "workout")
            workoutIdCache[firstRow.workoutName] = workoutId

            // Group rows by exercise name (preserving order of first appearance)
            var exerciseOrder: [String] = []
            var exerciseRows: [String: [StrongCSVRow]] = [:]

            for row in groupRows {
                if exerciseRows[row.exerciseName] == nil {
                    exerciseOrder.append(row.exerciseName)
                }
                exerciseRows[row.exerciseName, default: []].append(row)
            }

            // Build SessionExercises
            var sessionExercises: [SessionExercise] = []

            for exerciseName in exerciseOrder {
                guard let exRows = exerciseRows[exerciseName] else { continue }

                // Get or create deterministic exercise ID
                let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespaces)
                let exerciseId = exerciseIdCache[normalizedName] ?? generateDeterministicUUID(from: normalizedName, namespace: "exercise")
                exerciseIdCache[normalizedName] = exerciseId

                // Infer exercise type from data
                let exerciseType = inferExerciseType(from: exRows)
                let cardioMetric = inferCardioMetric(from: exRows)

                // Build sets
                var sets: [SetData] = []
                for (index, row) in exRows.sorted(by: { $0.setOrder < $1.setOrder }).enumerated() {
                    let setData = SetData(
                        setNumber: index + 1,
                        weight: row.weight > 0 ? row.weight : nil,
                        reps: row.reps > 0 ? row.reps : nil,
                        completed: true,
                        duration: row.seconds > 0 ? row.seconds : nil,
                        distance: row.distance > 0 ? row.distance : nil
                    )
                    sets.append(setData)
                }

                // Get exercise notes (first non-empty)
                let exerciseNotes = exRows.first(where: { !$0.notes.isEmpty })?.notes

                let setGroup = CompletedSetGroup(
                    setGroupId: UUID(),
                    sets: sets
                )

                let sessionExercise = SessionExercise(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    exerciseType: exerciseType,
                    cardioMetric: cardioMetric,
                    distanceUnit: .miles, // Strong typically uses miles
                    completedSetGroups: [setGroup],
                    notes: exerciseNotes,
                    isAdHoc: true
                )

                sessionExercises.append(sessionExercise)
            }

            // Create the module
            let moduleId = generateDeterministicUUID(from: firstRow.workoutName + "_module", namespace: "module")
            let completedModule = CompletedModule(
                moduleId: moduleId,
                moduleName: "Imported",
                moduleType: .strength,
                completedExercises: sessionExercises
            )

            // Parse duration
            let durationMinutes = Self.parseDuration(firstRow.duration)

            // Get session notes (first non-empty workout notes)
            let sessionNotes = groupRows.first(where: { !$0.workoutNotes.isEmpty })?.workoutNotes

            // Create the session
            let session = Session(
                workoutId: workoutId,
                workoutName: firstRow.workoutName,
                date: firstRow.date,
                completedModules: [completedModule],
                duration: durationMinutes,
                notes: sessionNotes,
                createdAt: Date(),
                syncStatus: .pendingSync,
                isImported: true  // Mark as imported from external app
            )

            sessions.append(session)
        }

        // Sort by date descending (most recent first)
        return sessions.sorted { $0.date > $1.date }
    }

    // MARK: - Exercise Type Inference

    private func inferExerciseType(from rows: [StrongCSVRow]) -> ExerciseType {
        // Check if any row has weight or reps
        let hasStrengthData = rows.contains { $0.weight > 0 || $0.reps > 0 }
        let hasCardioData = rows.contains { $0.distance > 0 || $0.seconds > 0 }

        if hasStrengthData {
            return .strength
        } else if hasCardioData {
            return .cardio
        } else {
            return .strength // Default
        }
    }

    private func inferCardioMetric(from rows: [StrongCSVRow]) -> CardioMetric {
        let hasDistance = rows.contains { $0.distance > 0 }
        let hasTime = rows.contains { $0.seconds > 0 }

        if hasDistance && hasTime {
            return .both
        } else if hasDistance {
            return .distanceOnly
        } else {
            return .timeOnly
        }
    }

    // MARK: - Duplicate Detection

    private func findDuplicates(sessions: [Session], existingSessions: [Session]) -> [Session] {
        var duplicates: [Session] = []
        let calendar = Calendar.current

        for session in sessions {
            let isDuplicate = existingSessions.contains { existing in
                // Match on workout name
                guard existing.workoutName.lowercased() == session.workoutName.lowercased() else {
                    return false
                }

                // Match on date (within 1 minute tolerance)
                let timeDiff = abs(existing.date.timeIntervalSince(session.date))
                return timeDiff < 60
            }

            if isDuplicate {
                duplicates.append(session)
            }
        }

        return duplicates
    }

    // MARK: - Deterministic UUID Generation

    private func generateDeterministicUUID(from string: String, namespace: String) -> UUID {
        // Create a deterministic UUID by hashing the string with namespace
        let combined = "\(namespace):\(string)"
        let hash = combined.utf8.reduce(0) { (result, byte) -> UInt64 in
            var h = result
            h = h &* 31 &+ UInt64(byte)
            return h
        }

        // Create UUID from hash (this is a simplified deterministic approach)
        let uuid1 = UInt32(truncatingIfNeeded: hash)
        let uuid2 = UInt16(truncatingIfNeeded: hash >> 32)
        let uuid3 = UInt16(truncatingIfNeeded: hash >> 48)
        let uuid4 = UInt16(truncatingIfNeeded: hash &* 7)
        let uuid5 = UInt16(truncatingIfNeeded: hash &* 13)
        let uuid6 = UInt16(truncatingIfNeeded: hash &* 17)
        let uuid7 = UInt16(truncatingIfNeeded: hash &* 23)
        let uuid8 = UInt16(truncatingIfNeeded: hash &* 29)

        return UUID(uuid: (
            UInt8(truncatingIfNeeded: uuid1),
            UInt8(truncatingIfNeeded: uuid1 >> 8),
            UInt8(truncatingIfNeeded: uuid1 >> 16),
            UInt8(truncatingIfNeeded: uuid1 >> 24),
            UInt8(truncatingIfNeeded: uuid2),
            UInt8(truncatingIfNeeded: uuid2 >> 8),
            UInt8(truncatingIfNeeded: uuid3),
            UInt8(truncatingIfNeeded: uuid3 >> 8),
            UInt8(truncatingIfNeeded: uuid4),
            UInt8(truncatingIfNeeded: uuid4 >> 8),
            UInt8(truncatingIfNeeded: uuid5),
            UInt8(truncatingIfNeeded: uuid5 >> 8),
            UInt8(truncatingIfNeeded: uuid6),
            UInt8(truncatingIfNeeded: uuid6 >> 8),
            UInt8(truncatingIfNeeded: uuid7),
            UInt8(truncatingIfNeeded: uuid7 >> 8)
        ))
    }
}
