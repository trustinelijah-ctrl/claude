import Foundation
import SwiftData
import PianoCore

enum SessionKind: String {
    case practice, justPlay
}

/// A practice session or a Just play session. Everything the user types is
/// written straight into these properties, so an interrupted session keeps
/// its notes; the timer is two stored values (see `SessionClock`).
@Model
final class PracticeSession {
    var id: UUID = UUID()
    var kindRaw: String = SessionKind.practice.rawValue
    var startedAt: Date = Date()
    var endedAt: Date?
    var plannedMinutes: Int = 0
    var planRaw: String = ""
    var currentStepIndex: Int = 0

    var clockAccumulated: Double = 0
    var clockRunningSince: Date?

    // The focused problem, written as the user works through it.
    var focusSmallerExercise: String = ""
    var focusCorrection: String = ""
    var focusVariation: String = ""
    var focusReintegration: String = ""

    /// Free notes for the non-focus steps, keyed by step kind.
    var stepNotesJSON: String = "{}"

    var closingEasier: String = ""
    var closingNext: String = ""

    var focusTask: PracticeTask?

    @Relationship(deleteRule: .nullify, inverse: \Attempt.session)
    var attempts: [Attempt] = []

    @Relationship(deleteRule: .nullify, inverse: \Recording.session)
    var recordings: [Recording] = []

    init(kind: SessionKind, plan: [PlannedStep] = [], focusTask: PracticeTask? = nil, startedAt: Date = .now) {
        self.kindRaw = kind.rawValue
        self.planRaw = SessionPlanner.encode(plan)
        self.plannedMinutes = plan.reduce(0) { $0 + $1.minutes }
        self.focusTask = focusTask
        self.startedAt = startedAt
        self.clockRunningSince = startedAt
    }

    var kind: SessionKind { SessionKind(rawValue: kindRaw) ?? .practice }
    var isActive: Bool { endedAt == nil }
    var plan: [PlannedStep] { SessionPlanner.decode(planRaw) }

    var currentStep: PlannedStep? {
        let steps = plan
        guard steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    var clock: SessionClock {
        get { SessionClock(accumulated: clockAccumulated, runningSince: clockRunningSince) }
        set {
            clockAccumulated = newValue.accumulated
            clockRunningSince = newValue.runningSince
        }
    }

    var isPaused: Bool { clockRunningSince == nil }

    func elapsed(at date: Date = .now) -> TimeInterval { clock.elapsed(at: date) }

    func pause(at date: Date = .now) {
        var c = clock
        c.pause(at: date)
        clock = c
    }

    func resume(at date: Date = .now) {
        var c = clock
        c.resume(at: date)
        clock = c
    }

    func finish(at date: Date = .now) {
        pause(at: date)
        endedAt = date
    }

    func note(for step: SessionStepKind) -> String {
        stepNotes[step.rawValue] ?? ""
    }

    func setNote(_ text: String, for step: SessionStepKind) {
        var notes = stepNotes
        notes[step.rawValue] = text
        if let data = try? JSONEncoder().encode(notes), let json = String(data: data, encoding: .utf8) {
            stepNotesJSON = json
        }
    }

    var stepNotes: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(stepNotesJSON.utf8))) ?? [:]
    }

    var practisedMinutesText: String {
        let minutes = Int((elapsed() / 60).rounded())
        return minutes < 1 ? "under a minute" : "\(minutes) min"
    }

    var hasAnyWriting: Bool {
        let fields = [focusSmallerExercise, focusCorrection, focusVariation, focusReintegration, closingEasier, closingNext]
            + Array(stepNotes.values)
        return fields.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
