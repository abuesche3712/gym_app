//
//  gym_appTests.swift
//  gym appTests
//
//  Analytics unit tests
//

import XCTest
@testable import gym_app

final class gym_appTests: XCTestCase {
    private var service: AnalyticsService!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        service = AnalyticsService()
        calendar = Calendar.current
    }

    func testCurrentStreak_countsConsecutiveDays() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: reference)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: reference)!
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: reference)!

        let sessions = [
            makeSession(date: reference, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]),
            makeSession(date: yesterday, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]),
            makeSession(date: twoDaysAgo, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]),
            makeSession(date: fourDaysAgo, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)])
        ]

        let streak = service.currentStreak(from: sessions, referenceDate: reference)
        XCTAssertEqual(streak, 3)
    }

    func testWeeklyVolumeTrend_groupsVolumeByWeek() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: reference)!.start
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!

        let currentWeekSessionDate = calendar.date(byAdding: .day, value: 1, to: currentWeekStart)!
        let previousWeekSessionDate = calendar.date(byAdding: .day, value: 2, to: previousWeekStart)!

        let sessions = [
            makeSession(date: currentWeekSessionDate, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]), // 500
            makeSession(date: previousWeekSessionDate, exercises: [makeStrengthExercise(name: "Bench", weight: 90, reps: 5)])   // 450
        ]

        let points = service.weeklyVolumeTrend(from: sessions, weeks: 2, referenceDate: reference)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].totalVolume, 450, accuracy: 0.001)
        XCTAssertEqual(points[1].totalVolume, 500, accuracy: 0.001)
    }

    func testProgressionBreakdown_countsRecommendations() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let recentDate = calendar.date(byAdding: .day, value: -3, to: reference)!

        let exercises = [
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .progress),
            makeStrengthExercise(name: "Squat", weight: 200, reps: 5, recommendation: .stay),
            makeStrengthExercise(name: "Deadlift", weight: 300, reps: 3, recommendation: .regress)
        ]
        let sessions = [makeSession(date: recentDate, exercises: exercises)]

        let breakdown = service.progressionBreakdown(from: sessions, days: 28, referenceDate: reference)
        XCTAssertEqual(breakdown.progressCount, 1)
        XCTAssertEqual(breakdown.stayCount, 1)
        XCTAssertEqual(breakdown.regressCount, 1)
        XCTAssertEqual(breakdown.total, 3)
    }

    func testRecentPRs_detectsWeightAndEstimatedOneRepMax() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 8)
        let day3 = makeDate(year: 2026, month: 1, day: 15)

        let sessions = [
            makeSession(date: day1, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]),
            makeSession(date: day2, exercises: [makeStrengthExercise(name: "Bench", weight: 105, reps: 5)]),
            makeSession(date: day3, exercises: [makeStrengthExercise(name: "Bench", weight: 105, reps: 8)])
        ]

        let prs = service.recentPRs(sessions: sessions, limit: 5)

        XCTAssertEqual(prs.count, 2)
        XCTAssertEqual(prs[0].exerciseName, "Bench")
        XCTAssertEqual(prs[0].date, day3)
        XCTAssertEqual(prs[1].date, day2)

        switch prs[0].type {
        case .estimatedOneRepMax:
            XCTAssertTrue(prs[0].newBest > prs[0].previousBest)
        default:
            XCTFail("Expected estimated 1RM PR on day 3")
        }

        switch prs[1].type {
        case .topWeight:
            XCTAssertEqual(prs[1].improvement, 5, accuracy: 0.001)
        default:
            XCTFail("Expected top-weight PR on day 2")
        }
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day)
        return calendar.date(from: components)!
    }

    private func makeStrengthExercise(
        name: String,
        weight: Double,
        reps: Int,
        recommendation: ProgressionRecommendation? = nil
    ) -> SessionExercise {
        SessionExercise(
            exerciseId: UUID(),
            exerciseName: name,
            exerciseType: .strength,
            completedSetGroups: [
                CompletedSetGroup(
                    setGroupId: UUID(),
                    sets: [SetData(setNumber: 1, weight: weight, reps: reps, completed: true)]
                )
            ],
            progressionRecommendation: recommendation
        )
    }

    private func makeSession(date: Date, exercises: [SessionExercise]) -> Session {
        Session(
            workoutId: UUID(),
            workoutName: "Test Workout",
            date: date,
            completedModules: [
                CompletedModule(
                    moduleId: UUID(),
                    moduleName: "Strength",
                    moduleType: .strength,
                    completedExercises: exercises
                )
            ]
        )
    }
}
