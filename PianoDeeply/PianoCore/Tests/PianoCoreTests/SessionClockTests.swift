import XCTest
@testable import PianoCore

final class SessionClockTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testRunningClockCountsWallTime() {
        let clock = SessionClock.started(at: t0)
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(95)), 95)
        XCTAssertTrue(clock.isRunning)
    }

    func testPausedClockDoesNotGrow() {
        var clock = SessionClock.started(at: t0)
        clock.pause(at: t0.addingTimeInterval(60))
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(60)), 60)
        // An hour in the background while paused adds nothing.
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(3_660)), 60)
        XCTAssertFalse(clock.isRunning)
    }

    func testPauseResumeAccumulatesOnlyRunningStretches() {
        var clock = SessionClock.started(at: t0)
        clock.pause(at: t0.addingTimeInterval(120))        // 2 min
        clock.resume(at: t0.addingTimeInterval(600))       // 8 min break
        clock.pause(at: t0.addingTimeInterval(780))        // +3 min
        clock.resume(at: t0.addingTimeInterval(800))
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(860)), 120 + 180 + 60)
    }

    func testDoublePauseAndDoubleResumeAreHarmless() {
        var clock = SessionClock.started(at: t0)
        clock.pause(at: t0.addingTimeInterval(30))
        clock.pause(at: t0.addingTimeInterval(500))
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(900)), 30)
        clock.resume(at: t0.addingTimeInterval(1_000))
        clock.resume(at: t0.addingTimeInterval(1_500)) // must not reset the stretch start
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(1_600)), 30 + 600)
    }

    func testClockMovingBackwardsNeverSubtracts() {
        var clock = SessionClock(accumulated: 300, runningSince: t0)
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(-120)), 300)
        clock.pause(at: t0.addingTimeInterval(-120))
        XCTAssertEqual(clock.elapsed(at: t0), 300)
    }

    func testSurvivesRoundTripThroughStorage() throws {
        // What persistence does: store the two fields, rebuild later.
        var clock = SessionClock.started(at: t0)
        clock.pause(at: t0.addingTimeInterval(45))
        clock.resume(at: t0.addingTimeInterval(100))
        let rebuilt = SessionClock(accumulated: clock.accumulated, runningSince: clock.runningSince)
        XCTAssertEqual(rebuilt.elapsed(at: t0.addingTimeInterval(200)), 145)
    }

    func testFormat() {
        XCTAssertEqual(SessionClock.format(0), "0:00")
        XCTAssertEqual(SessionClock.format(724), "12:04")
        XCTAssertEqual(SessionClock.format(3_729), "1:02:09")
        XCTAssertEqual(SessionClock.format(-5), "0:00")
    }

    func testStepHintFollowsPlan() {
        let steps = SessionPlanner.template(minutes: 20) // 3, 4, 8, 4, 1
        XCTAssertEqual(SessionClock.stepIndex(for: 0, in: steps), 0)
        XCTAssertEqual(SessionClock.stepIndex(for: 179, in: steps), 0)
        XCTAssertEqual(SessionClock.stepIndex(for: 180, in: steps), 1)
        XCTAssertEqual(SessionClock.stepIndex(for: 15 * 60, in: steps), 3)
        XCTAssertEqual(SessionClock.stepIndex(for: 99 * 60, in: steps), 4)
        XCTAssertNil(SessionClock.stepIndex(for: 10, in: []))
    }

    func testRetestDueDatesLandOnStartOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let lateEvening = calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 23, minute: 30))!
        let due = RetestInterval.tomorrow.dueDate(from: lateEvening, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour], from: due),
                       DateComponents(year: 2026, month: 3, day: 29, hour: 0))
        // Across the spring-forward change, a week is still seven calendar days.
        let week = RetestInterval.oneWeek.dueDate(from: lateEvening, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.month, .day, .hour], from: week), DateComponents(month: 4, day: 4, hour: 0))
    }
}
