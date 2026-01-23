//
//  TodayWorkoutWidget.swift
//  TodayWorkoutWidget
//
//  Shows today's scheduled workout on the home/lock screen
//

import WidgetKit
import SwiftUI

// MARK: - Shared Data Model (must match main app)

struct TodayWorkoutData: Codable {
    let workoutName: String?
    let moduleNames: [String]
    let isRestDay: Bool
    let lastUpdated: Date
}

// MARK: - Widget Entry

struct TodayWorkoutEntry: TimelineEntry {
    let date: Date
    let workoutName: String?
    let moduleNames: [String]
    let isRestDay: Bool

    static let placeholder = TodayWorkoutEntry(
        date: Date(),
        workoutName: "Push Day A",
        moduleNames: ["Chest", "Shoulders", "Triceps"],
        isRestDay: false
    )

    static let restDay = TodayWorkoutEntry(
        date: Date(),
        workoutName: nil,
        moduleNames: [],
        isRestDay: true
    )

    static let noWorkout = TodayWorkoutEntry(
        date: Date(),
        workoutName: nil,
        moduleNames: [],
        isRestDay: false
    )
}

// MARK: - Timeline Provider

struct TodayWorkoutProvider: TimelineProvider {
    private let appGroupIdentifier = "group.UI.gym-app"
    private let widgetDataKey = "todayWorkoutData"

    func placeholder(in context: Context) -> TodayWorkoutEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayWorkoutEntry) -> Void) {
        completion(loadCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayWorkoutEntry>) -> Void) {
        let entry = loadCurrentEntry()
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func loadCurrentEntry() -> TodayWorkoutEntry {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: widgetDataKey) else {
            return .noWorkout
        }

        do {
            let workoutData = try JSONDecoder().decode(TodayWorkoutData.self, from: data)
            if !Calendar.current.isDateInToday(workoutData.lastUpdated) {
                return .noWorkout
            }
            return TodayWorkoutEntry(
                date: Date(),
                workoutName: workoutData.workoutName,
                moduleNames: workoutData.moduleNames,
                isRestDay: workoutData.isRestDay
            )
        } catch {
            return .noWorkout
        }
    }
}

// MARK: - Widget Views

struct TodayWorkoutWidgetEntryView: View {
    var entry: TodayWorkoutEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryRectangular:
            LockScreenWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: TodayWorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.caption)
                Text("TODAY")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)

            Spacer()

            if entry.isRestDay {
                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: "bed.double.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Rest Day")
                        .font(.headline)
                }
            } else if let workoutName = entry.workoutName {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutName)
                        .font(.headline)
                        .lineLimit(2)
                    if !entry.moduleNames.isEmpty {
                        Text(entry.moduleNames.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No Workout")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumWidgetView: View {
    let entry: TodayWorkoutEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption)
                    Text("TODAY'S WORKOUT")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)

                if entry.isRestDay {
                    HStack(spacing: 8) {
                        Image(systemName: "bed.double.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rest Day")
                                .font(.title2.weight(.semibold))
                            Text("Recovery is gains")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let workoutName = entry.workoutName {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workoutName)
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)
                        Text("\(entry.moduleNames.count) modules")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No Workout")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Schedule one in the app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }

            Spacer()

            if !entry.isRestDay && !entry.moduleNames.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(entry.moduleNames.prefix(4), id: \.self) { name in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 6, height: 6)
                            Text(name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                    if entry.moduleNames.count > 4 {
                        Text("+\(entry.moduleNames.count - 4) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct LockScreenWidgetView: View {
    let entry: TodayWorkoutEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if entry.isRestDay {
                    Label("Rest Day", systemImage: "bed.double.fill")
                        .font(.headline)
                } else if let workoutName = entry.workoutName {
                    Text(workoutName)
                        .font(.headline)
                        .lineLimit(1)
                    if !entry.moduleNames.isEmpty {
                        Text(entry.moduleNames.prefix(3).joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Label("No Workout", systemImage: "calendar")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .containerBackground(for: .widget) { }
    }
}

// MARK: - Widget

@main
struct TodayWorkoutWidget: Widget {
    let kind: String = "TodayWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWorkoutProvider()) { entry in
            TodayWorkoutWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Workout")
        .description("See your scheduled workout for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
