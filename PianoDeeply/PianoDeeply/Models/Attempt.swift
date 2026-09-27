import Foundation
import SwiftData
import PianoCore

/// One try at a task, cold or after practice.
@Model
final class Attempt {
    var id: UUID = UUID()
    var date: Date = Date()
    var phaseRaw: String = AttemptPhase.cold.rawValue
    /// Only ever what the user typed. The app never estimates tempo.
    var tempo: Int?
    var errorCategoryRaw: String?
    var observation: String = ""
    var smallerExercise: String = ""
    var outcomeRaw: String?
    var nextStep: String = ""
    var isRetest: Bool = false

    var task: PracticeTask?
    var session: PracticeSession?

    @Relationship(deleteRule: .nullify, inverse: \Recording.attempt)
    var recordings: [Recording] = []

    init(task: PracticeTask?, phase: AttemptPhase, date: Date = .now) {
        self.task = task
        self.phaseRaw = phase.rawValue
        self.date = date
    }

    var phase: AttemptPhase {
        get { AttemptPhase(rawValue: phaseRaw) ?? .cold }
        set { phaseRaw = newValue.rawValue }
    }

    var errorCategory: ErrorCategory? {
        get { errorCategoryRaw.flatMap(ErrorCategory.init(rawValue:)) }
        set { errorCategoryRaw = newValue?.rawValue }
    }

    var outcome: ExperimentOutcome? {
        get { outcomeRaw.flatMap(ExperimentOutcome.init(rawValue:)) }
        set { outcomeRaw = newValue?.rawValue }
    }

    /// "Cold retest", "Cold first pass", or "After practice".
    var phaseLabel: String { isRetest ? "Cold retest" : phase.label }

    var recording: Recording? { recordings.max { $0.createdAt < $1.createdAt } }

    var evidencePoint: EvidencePoint? {
        guard let task else { return nil }
        return EvidencePoint(id: id, taskID: task.id, date: date, phase: phase, tempo: tempo,
                             observation: observation, nextStep: nextStep, hasRecording: recording != nil)
    }
}

/// A cold check scheduled for later, carrying a snapshot of the situation it
/// was set up in, so the retest can be read with its original context.
@Model
final class Retest {
    var id: UUID = UUID()
    var scheduledAt: Date = Date()
    var dueDate: Date = Date()
    var context: String = ""
    var completedAt: Date?
    var resultAttemptID: UUID?

    var task: PracticeTask?

    init(task: PracticeTask, dueDate: Date, context: String, scheduledAt: Date = .now) {
        self.task = task
        self.dueDate = dueDate
        self.context = context
        self.scheduledAt = scheduledAt
    }

    var isCompleted: Bool { completedAt != nil }

    var snapshot: RetestSnapshot? {
        guard let task else { return nil }
        return RetestSnapshot(id: id, taskID: task.id, taskTitle: task.title, dueDate: dueDate,
                              scheduledAt: scheduledAt, isCompleted: isCompleted)
    }

    /// Builds the context line from the attempt that prompted the retest.
    static func context(from attempt: Attempt?) -> String {
        guard let attempt else { return "" }
        let date = attempt.date.formatted(date: .abbreviated, time: .omitted)
        var parts = ["\(attempt.phaseLabel), \(date)"]
        if let tempo = attempt.tempo { parts.append("\(tempo) bpm") }
        if let category = attempt.errorCategory { parts.append(category.label.lowercased()) }
        let note = attempt.observation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { parts.append("“\(note)”") }
        return parts.joined(separator: " · ")
    }
}
