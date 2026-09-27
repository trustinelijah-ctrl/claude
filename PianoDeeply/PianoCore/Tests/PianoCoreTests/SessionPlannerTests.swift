import XCTest
@testable import PianoCore

final class SessionPlannerTests: XCTestCase {
    func testPresetsAddUpAndAlwaysHaveAFocusedProblemAndANote() {
        for minutes in SessionPlanner.presetMinutes {
            let plan = SessionPlanner.template(minutes: minutes)
            XCTAssertEqual(plan.reduce(0) { $0 + $1.minutes }, minutes, "\(minutes)-minute plan")
            XCTAssertTrue(plan.contains { $0.kind == .focus })
            XCTAssertEqual(plan.first?.kind, .arrival)
            XCTAssertEqual(plan.last?.kind, .closing)
        }
    }

    func testShortPresetHasTheFiveCoreSteps() {
        XCTAssertEqual(SessionPlanner.template(minutes: 20).map(\.kind), [.arrival, .reading, .focus, .application, .closing])
    }

    func testCustomDurationsAddUpExactlyWithNoEmptySteps() {
        for minutes in [5, 7, 9, 10, 11, 15, 25, 33, 45, 47, 75, 100, 120, 180, 240] {
            let plan = SessionPlanner.template(minutes: minutes)
            XCTAssertEqual(plan.reduce(0) { $0 + $1.minutes }, minutes, "\(minutes)-minute plan: \(plan)")
            XCTAssertTrue(plan.allSatisfy { $0.minutes >= 1 }, "\(minutes)-minute plan: \(plan)")
            XCTAssertTrue(plan.contains { $0.kind == .focus })
        }
    }

    func testOutOfRangeRequestsAreClamped() {
        XCTAssertEqual(SessionPlanner.template(minutes: 0).reduce(0) { $0 + $1.minutes }, SessionPlanner.minimumMinutes)
        XCTAssertEqual(SessionPlanner.template(minutes: 10_000).reduce(0) { $0 + $1.minutes }, SessionPlanner.maximumMinutes)
    }

    func testPlanSurvivesStorageRoundTrip() {
        let plan = SessionPlanner.template(minutes: 90)
        XCTAssertEqual(SessionPlanner.decode(SessionPlanner.encode(plan)), plan)
    }

    func testDecodingSkipsUnknownOrBrokenEntriesInsteadOfLosingThePlan() {
        let decoded = SessionPlanner.decode("arrival:4,harpsichord:9,focus:x,focus:12,closing:0,closing:2")
        XCTAssertEqual(decoded, [PlannedStep(.arrival, 4), PlannedStep(.focus, 12), PlannedStep(.closing, 2)])
        XCTAssertEqual(SessionPlanner.decode(""), [])
    }
}

final class FeedbackAndGreetingTests: XCTestCase {
    func testOnlyAnExperimentThatWorkedCelebrates() {
        XCTAssertTrue(ExperimentFeedback.after(outcome: .worked, tempo: 72, phase: .afterPractice).celebrate)
        XCTAssertFalse(ExperimentFeedback.after(outcome: .partly, tempo: 72, phase: .afterPractice).celebrate)
        XCTAssertFalse(ExperimentFeedback.after(outcome: .notYet, tempo: nil, phase: .cold).celebrate)
    }

    func testFeedbackQuotesTheUsersOwnTempoAndNeverInventsOne() {
        XCTAssertEqual(ExperimentFeedback.after(outcome: .worked, tempo: 72, phase: .afterPractice).message,
                       "Even at 72 bpm. Try it cold next time.")
        XCTAssertFalse(ExperimentFeedback.after(outcome: .worked, tempo: nil, phase: .afterPractice).message.contains("bpm"))
    }

    func testReturningAfterTwoWeeksIsWelcomedWithoutCountingOrStreaks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 19))!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        let headline = ReturnGreeting.headline(lastPlayed: twoWeeksAgo, now: now, calendar: calendar)
        XCTAssertEqual(headline, "Welcome back.")
        XCTAssertTrue(ReturnGreeting.isLongGap(lastPlayed: twoWeeksAgo, now: now, calendar: calendar))
        XCTAssertFalse(ReturnGreeting.isLongGap(lastPlayed: nil, now: now, calendar: calendar))
        XCTAssertFalse(headline.contains("14"))
        XCTAssertFalse(headline.lowercased().contains("streak"))

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(ReturnGreeting.headline(lastPlayed: yesterday, now: now, calendar: calendar), "Good evening.")
        XCTAssertEqual(ReturnGreeting.headline(lastPlayed: nil, now: now, calendar: calendar), "Good evening.")
    }
}
