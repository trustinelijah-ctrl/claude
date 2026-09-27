import Foundation
import SwiftData
import PianoCore

/// An observable target: "Bars 9–12, hands together, no stops at 60".
@Model
final class PracticeTask {
    var id: UUID = UUID()
    var title: String = ""
    /// Where and how: passage, hands, edition, anything that makes a later
    /// retest the same task.
    var contextNote: String = ""
    var createdAt: Date = Date()
    var isArchived: Bool = false
    var inventorySampleRaw: String?

    var skill: Skill?
    var piece: Piece?

    @Relationship(deleteRule: .cascade, inverse: \Attempt.task)
    var attempts: [Attempt] = []

    @Relationship(deleteRule: .cascade, inverse: \Retest.task)
    var retests: [Retest] = []

    // Recordings outlive their task; they're the user's audio.
    @Relationship(deleteRule: .nullify, inverse: \Recording.task)
    var recordings: [Recording] = []

    @Relationship(deleteRule: .nullify, inverse: \PracticeSession.focusTask)
    var focusSessions: [PracticeSession] = []

    init(title: String, contextNote: String = "", skill: Skill? = nil, piece: Piece? = nil) {
        self.title = title
        self.contextNote = contextNote
        self.skill = skill
        self.piece = piece
    }

    var inventorySample: InventorySample? {
        get { inventorySampleRaw.flatMap(InventorySample.init(rawValue:)) }
        set { inventorySampleRaw = newValue?.rawValue }
    }

    var sortedAttempts: [Attempt] { attempts.sorted { $0.date > $1.date } }
    var lastAttempt: Attempt? { attempts.max { $0.date < $1.date } }
    var lastColdAttempt: Attempt? { attempts.filter { $0.phase == .cold }.max { $0.date < $1.date } }
    var pendingRetests: [Retest] { retests.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate } }

    /// The most recent thing done on this task and the next step written
    /// there. Attempts always count; a focus session counts only if its
    /// closing note says what's next. A blank next step on the latest attempt
    /// means there is no pending next step, however old ones read.
    var latestActivity: (date: Date, nextStep: String)? {
        let fromAttempts = attempts.map { (date: $0.date, nextStep: $0.nextStep) }
        let fromSessions = focusSessions
            .filter { !$0.closingNext.isBlank }
            .map { (date: $0.endedAt ?? $0.startedAt, nextStep: $0.closingNext) }
        return (fromAttempts + fromSessions).max { $0.date < $1.date }
    }

    var snapshot: TaskSnapshot {
        let latest = latestActivity
        return TaskSnapshot(
            id: id,
            title: title,
            skillName: skill?.name,
            skillIsBottleneck: skill?.isBottleneck ?? false,
            createdAt: createdAt,
            lastAttemptAt: latest?.date,
            lastColdAttemptAt: lastColdAttempt?.date,
            nextStep: latest.flatMap { $0.nextStep.isBlank ? nil : $0.nextStep },
            isArchived: isArchived
        )
    }

    /// One line for a retest card: what the situation was when it was set up.
    var contextSummary: String {
        [piece?.title, contextNote.isEmpty ? nil : contextNote].compactMap { $0 }.joined(separator: " · ")
    }
}
