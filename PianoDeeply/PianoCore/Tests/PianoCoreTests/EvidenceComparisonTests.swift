import XCTest
@testable import PianoCore

final class EvidenceComparisonTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let base = Date(timeIntervalSince1970: 1_789_948_800) // midnight UTC
    func day(_ n: Int, hour: Int = 10) -> Date { base.addingTimeInterval(TimeInterval(n * 86_400 + hour * 3_600)) }

    let taskA = UUID(), taskB = UUID()

    func testNoPairWithoutTwoComparableAttempts() {
        let points = [
            EvidencePoint(taskID: taskA, date: day(0), phase: .cold, tempo: 60),
            EvidencePoint(taskID: taskA, date: day(3), phase: .afterPractice, tempo: 80),
            EvidencePoint(taskID: taskB, date: day(5), phase: .cold, tempo: 90),
        ]
        XCTAssertNil(EvidenceComparison.latestPair(in: points, calendar: calendar),
                     "cold vs after-practice and different tasks must never be paired")
    }

    func testSameDayAttemptsAreNotBeforeAndNow() {
        let points = [
            EvidencePoint(taskID: taskA, date: day(1, hour: 9), phase: .afterPractice, tempo: 60),
            EvidencePoint(taskID: taskA, date: day(1, hour: 10), phase: .afterPractice, tempo: 72),
        ]
        XCTAssertNil(EvidenceComparison.latestPair(in: points, calendar: calendar))
    }

    func testPairsEarliestWithLatestWithinOnePhase() {
        let first = EvidencePoint(taskID: taskA, date: day(0), phase: .cold, tempo: 60, observation: "Stumbled at the turn")
        let middle = EvidencePoint(taskID: taskA, date: day(7), phase: .cold, tempo: 66)
        let latest = EvidencePoint(taskID: taskA, date: day(14), phase: .cold, tempo: 72, nextStep: "Try 76")
        let noise = EvidencePoint(taskID: taskA, date: day(15), phase: .afterPractice, tempo: 100)
        let pair = EvidenceComparison.latestPair(in: [latest, noise, first, middle], calendar: calendar)
        // The after-practice point on day 15 has no partner, so the cold pair wins.
        XCTAssertEqual(pair?.phase, .cold)
        XCTAssertEqual(pair?.before, first)
        XCTAssertEqual(pair?.now, latest)
        XCTAssertEqual(pair?.tempoChange, 12)
        XCTAssertEqual(pair?.next, "Try 76")
    }

    func testTempoChangeOnlyWhenBothTempiWereEntered() {
        let points = [
            EvidencePoint(taskID: taskA, date: day(0), phase: .cold),
            EvidencePoint(taskID: taskA, date: day(4), phase: .cold, tempo: 80),
        ]
        let pair = EvidenceComparison.latestPair(in: points, calendar: calendar)
        XCTAssertNotNil(pair)
        XCTAssertNil(pair?.tempoChange)
    }

    func testPrefersMostRecentlyActiveTask() {
        let points = [
            EvidencePoint(taskID: taskA, date: day(0), phase: .cold),
            EvidencePoint(taskID: taskA, date: day(3), phase: .cold),
            EvidencePoint(taskID: taskB, date: day(1), phase: .afterPractice),
            EvidencePoint(taskID: taskB, date: day(9), phase: .afterPractice),
        ]
        XCTAssertEqual(EvidenceComparison.latestPair(in: points, calendar: calendar)?.taskID, taskB)
    }

    func testNextStepComesFromLatestAttemptOfThatTaskOnly() {
        let points = [
            EvidencePoint(taskID: taskA, date: day(0), phase: .cold, nextStep: "old"),
            EvidencePoint(taskID: taskA, date: day(2), phase: .cold, nextStep: " "),
            EvidencePoint(taskID: taskA, date: day(3), phase: .afterPractice, nextStep: "Hands together at 66"),
            EvidencePoint(taskID: taskB, date: day(10), phase: .cold, nextStep: "belongs to B"),
        ]
        let pairs = EvidenceComparison.pairs(forTask: taskA, in: points, calendar: calendar)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.next, "Hands together at 66")
    }
}
