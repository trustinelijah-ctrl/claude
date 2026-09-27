import XCTest
@testable import PianoCore

final class SuggestionEngineTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    lazy var now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 10))!

    func days(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now)! }

    func testNothingLoggedMeansNoSuggestionRatherThanAnInventedOne() {
        XCTAssertNil(SuggestionEngine.suggest(tasks: [], retests: [], bottleneckSkillName: nil, now: now, calendar: calendar))
        // A task that was created but never practised isn't "stale" either.
        let untouched = TaskSnapshot(title: "Bars 1–8", createdAt: days(40))
        XCTAssertNil(SuggestionEngine.suggest(tasks: [untouched], retests: [], bottleneckSkillName: nil, now: now, calendar: calendar))
    }

    func testDueRetestComesFirstAndSaysWhenItWasScheduled() {
        let task = TaskSnapshot(title: "Turn in bar 12", skillName: "Left-hand coordination", skillIsBottleneck: true,
                                createdAt: days(10), lastAttemptAt: days(1), nextStep: "Hands together at 60")
        let retest = RetestSnapshot(taskID: task.id, taskTitle: task.title, dueDate: days(0), scheduledAt: days(3))
        let s = SuggestionEngine.suggest(tasks: [task], retests: [retest], bottleneckSkillName: "Left-hand coordination", now: now, calendar: calendar)
        XCTAssertEqual(s?.rule, .retestDue)
        XCTAssertEqual(s?.retestID, retest.id)
        XCTAssertEqual(s?.reason, "You set up this cold retest 3 days ago.")
    }

    func testFutureCompletedOrOrphanedRetestsAreIgnored() {
        let task = TaskSnapshot(title: "Scale", createdAt: days(5), lastAttemptAt: days(1))
        let future = RetestSnapshot(taskID: task.id, taskTitle: "Scale", dueDate: calendar.date(byAdding: .day, value: 2, to: now)!, scheduledAt: days(1))
        let done = RetestSnapshot(taskID: task.id, taskTitle: "Scale", dueDate: days(1), scheduledAt: days(4), isCompleted: true)
        let orphan = RetestSnapshot(taskID: UUID(), taskTitle: "Deleted task", dueDate: days(1), scheduledAt: days(4))
        let s = SuggestionEngine.suggest(tasks: [task], retests: [future, done, orphan], bottleneckSkillName: nil, now: now, calendar: calendar)
        XCTAssertNotEqual(s?.rule, .retestDue)
        XCTAssertEqual(SuggestionEngine.nextUpcomingRetest([future, done, orphan], now: now), future)
    }

    func testBottleneckReasonNamesTheSkill() {
        let other = TaskSnapshot(title: "Reading", createdAt: days(3), lastAttemptAt: days(0), nextStep: "Try level 2")
        let linked = TaskSnapshot(title: "Alberti bass, bars 5–8", skillName: "Left-hand coordination", skillIsBottleneck: true,
                                  createdAt: days(6), lastAttemptAt: days(2))
        let s = SuggestionEngine.suggest(tasks: [other, linked], retests: [], bottleneckSkillName: "Left-hand coordination", now: now, calendar: calendar)
        XCTAssertEqual(s?.rule, .bottleneckTask)
        XCTAssertEqual(s?.taskID, linked.id)
        XCTAssertEqual(s?.reason, "Because you marked left-hand coordination as your bottleneck.")
    }

    func testBottleneckWithoutATaskAsksForOneInsteadOfPickingSomethingUnrelated() {
        let other = TaskSnapshot(title: "Reading", createdAt: days(3), lastAttemptAt: days(0), nextStep: "Try level 2")
        let s = SuggestionEngine.suggest(tasks: [other], retests: [], bottleneckSkillName: "ii–V–I", now: now, calendar: calendar)
        XCTAssertEqual(s?.rule, .bottleneckNeedsTask)
        XCTAssertNil(s?.taskID)
        XCTAssertTrue(s?.reason.hasPrefix("Because you marked ii–V–I as your bottleneck.") == true)
    }

    func testArchivedBottleneckTaskIsNotSuggested() {
        let archived = TaskSnapshot(title: "Old", skillIsBottleneck: true, createdAt: days(9), lastAttemptAt: days(1), isArchived: true)
        let s = SuggestionEngine.suggest(tasks: [archived], retests: [], bottleneckSkillName: "Rhythm", now: now, calendar: calendar)
        XCTAssertEqual(s?.rule, .bottleneckNeedsTask)
    }

    func testMostRecentNextStepIsResurfacedWithQuote() {
        let older = TaskSnapshot(title: "A", createdAt: days(12), lastAttemptAt: days(9), lastColdAttemptAt: days(9), nextStep: "Old idea")
        let recent = TaskSnapshot(title: "B", createdAt: days(12), lastAttemptAt: days(2), lastColdAttemptAt: days(2), nextStep: "  Try the turn at 66  ")
        let s = SuggestionEngine.suggest(tasks: [older, recent], retests: [], bottleneckSkillName: nil, now: now, calendar: calendar)
        XCTAssertEqual(s?.rule, .unfinishedNextStep)
        XCTAssertEqual(s?.taskID, recent.id)
        XCTAssertEqual(s?.reason, "You left yourself a next step 2 days ago: “Try the turn at 66”")
    }

    func testStaleNextStepFallsThroughToColdCheck() {
        let stale = TaskSnapshot(title: "Nocturne opening", createdAt: days(60), lastAttemptAt: days(30), lastColdAttemptAt: days(45), nextStep: "Slower")
        let s = SuggestionEngine.suggest(tasks: [stale], retests: [], bottleneckSkillName: nil, now: now, calendar: calendar)
        XCTAssertEqual(s?.rule, .notTriedColdLately)
        XCTAssertEqual(s?.reason, "You haven't tried this cold since 6 weeks ago.")
    }

    func testNeverColdTaskGetsHonestReason() {
        let t = TaskSnapshot(title: "Arpeggios", createdAt: days(30), lastAttemptAt: days(25))
        let s = SuggestionEngine.suggest(tasks: [t], retests: [], bottleneckSkillName: nil, now: now, calendar: calendar)
        XCTAssertEqual(s?.reason, "You've practised this but haven't tried it cold yet.")
    }

    func testRecentlyColdTestedTaskIsLeftAlone() {
        let t = TaskSnapshot(title: "Arpeggios", createdAt: days(30), lastAttemptAt: days(25), lastColdAttemptAt: days(3))
        XCTAssertNil(SuggestionEngine.suggest(tasks: [t], retests: [], bottleneckSkillName: nil, now: now, calendar: calendar))
    }

    func testDayPhrases() {
        XCTAssertEqual(DayPhrase.since(now, now: now, calendar: calendar), "today")
        XCTAssertEqual(DayPhrase.since(days(1), now: now, calendar: calendar), "yesterday")
        XCTAssertEqual(DayPhrase.since(days(13), now: now, calendar: calendar), "13 days ago")
        XCTAssertEqual(DayPhrase.since(days(28), now: now, calendar: calendar), "4 weeks ago")
        XCTAssertEqual(DayPhrase.until(calendar.date(byAdding: .day, value: 1, to: now)!, now: now, calendar: calendar), "tomorrow")
        XCTAssertEqual(DayPhrase.until(calendar.date(byAdding: .day, value: 28, to: now)!, now: now, calendar: calendar), "in 4 weeks")
    }
}
