import XCTest
import SwiftData
import PianoCore
@testable import PianoDeeply

/// SwiftData behaviour the app relies on: deletes don't take unrelated
/// evidence with them, a session's timer survives a reload, and the export
/// reflects what is really stored.
@MainActor
final class PersistenceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer(for: Schema(AppSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testDeletingAnAttemptLeavesTheTaskAndOtherAttempts() throws {
        let task = PracticeTask(title: "Bars 9–12")
        context.insert(task)
        let first = Attempt(task: task, phase: .cold)
        let second = Attempt(task: task, phase: .afterPractice)
        context.insert(first)
        context.insert(second)
        try context.save()

        context.delete(first)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<PracticeTask>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Attempt>()).map(\.id), [second.id])
    }

    func testDeletingATaskRemovesItsAttemptsButKeepsRecordingsAndSessions() throws {
        let task = PracticeTask(title: "Scale")
        context.insert(task)
        let attempt = Attempt(task: task, phase: .cold)
        context.insert(attempt)
        let session = PracticeSession(kind: .practice, plan: SessionPlanner.template(minutes: 20), focusTask: task)
        context.insert(session)
        attempt.session = session
        let recording = Recording(fileName: "missing.m4a", duration: 12, title: "Take")
        context.insert(recording)
        recording.task = task
        recording.attempt = attempt
        context.insert(Retest(task: task, dueDate: .now, context: ""))
        try context.save()

        context.delete(task)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Attempt>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Retest>()).isEmpty)
        let recordings = try context.fetch(FetchDescriptor<Recording>())
        XCTAssertEqual(recordings.count, 1, "the user's audio must outlive the task")
        XCTAssertNil(recordings.first?.task)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PracticeSession>()).count, 1)
    }

    func testPausedSessionTimeSurvivesAReload() throws {
        let start = Date(timeIntervalSinceNow: -600)
        let session = PracticeSession(kind: .practice, plan: SessionPlanner.template(minutes: 30), startedAt: start)
        context.insert(session)
        session.pause(at: start.addingTimeInterval(240))
        session.focusCorrection = "Thumb under earlier"
        try context.save()

        let fresh = ModelContext(container)
        let reloaded = try XCTUnwrap(fresh.fetch(FetchDescriptor<PracticeSession>()).first)
        XCTAssertTrue(reloaded.isPaused)
        XCTAssertEqual(reloaded.elapsed(at: .now), 240, accuracy: 0.001)
        XCTAssertEqual(reloaded.focusCorrection, "Thumb under earlier")
        XCTAssertNil(reloaded.endedAt, "an unfinished session stays active")
    }

    func testStepNotesRoundTrip() {
        let session = PracticeSession(kind: .practice)
        session.setNote("Bach minuet, first half", for: .reading)
        session.setNote("C major, two octaves", for: .technique)
        XCTAssertEqual(session.note(for: .reading), "Bach minuet, first half")
        XCTAssertEqual(session.note(for: .technique), "C major, two octaves")
        XCTAssertEqual(session.note(for: .ear), "")
    }

    func testExportContainsWhatWasSaved() throws {
        let task = PracticeTask(title: "ii–V–I in F")
        context.insert(task)
        let attempt = Attempt(task: task, phase: .cold)
        attempt.tempo = 72
        attempt.isRetest = true
        context.insert(attempt)
        context.insert(JournalNote(text: "Pedal changes on the chord."))
        try context.save()

        let bundle = try ExportService.makeBundle(from: context)
        XCTAssertEqual(bundle.tasks.map(\.title), ["ii–V–I in F"])
        XCTAssertEqual(bundle.attempts.first?.tempo, 72)
        XCTAssertEqual(bundle.attempts.first?.phase, "coldRetest")
        XCTAssertEqual(bundle.attempts.first?.taskID, task.id.uuidString)
        XCTAssertEqual(bundle.notes.map(\.text), ["Pedal changes on the chord."])
        XCTAssertEqual(try ExportBundle.decode(bundle.encoded()), bundle)
    }

    func testStarterSkillsAreSeededOnceAndStayDeletedIfTheUserDeletesThem() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "PersistenceTests-\(UUID())"))
        SkillSeeder.seedIfNeeded(context, defaults: defaults)
        let seeded = try context.fetch(FetchDescriptor<Skill>())
        XCTAssertFalse(seeded.isEmpty)
        XCTAssertTrue(seeded.allSatisfy { $0.state == .notExplored && !$0.isBottleneck })

        seeded.forEach { context.delete($0) }
        try context.save()
        SkillSeeder.seedIfNeeded(context, defaults: defaults)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Skill>()).isEmpty)
    }

    func testABlankLatestNextStepHidesAnOlderOne() throws {
        let task = PracticeTask(title: "Nocturne, bars 9–12")
        context.insert(task)
        let old = Attempt(task: task, phase: .cold, date: .now.addingTimeInterval(-60 * 86_400))
        old.nextStep = "Slower"
        let recent = Attempt(task: task, phase: .cold, date: .now.addingTimeInterval(-86_400))
        context.insert(old)
        context.insert(recent)
        try context.save()

        let snapshot = task.snapshot
        XCTAssertNil(snapshot.nextStep, "a 60-day-old next step must not resurface as yesterday's")
        XCTAssertEqual(snapshot.lastAttemptAt, recent.date)

        recent.nextStep = "Turn at 66"
        XCTAssertEqual(task.snapshot.nextStep, "Turn at 66")
    }

    func testOnlyOneBottleneckAtATime() {
        let a = Skill(branch: .rhythm, name: "Pulse", evidence: "", sortOrder: 0)
        let b = Skill(branch: .ear, name: "Bass lines", evidence: "", sortOrder: 0)
        SkillSeeder.markBottleneck(a, in: [a, b])
        SkillSeeder.markBottleneck(b, in: [a, b])
        XCTAssertFalse(a.isBottleneck)
        XCTAssertTrue(b.isBottleneck)
        SkillSeeder.markBottleneck(b, in: [a, b])
        XCTAssertFalse(b.isBottleneck, "marking the current bottleneck again clears it")
    }
}
