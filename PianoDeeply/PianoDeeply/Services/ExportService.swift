import Foundation
import SwiftData
import PianoCore

/// Builds the JSON export from what is actually saved.
enum ExportService {
    static func makeBundle(from context: ModelContext, now: Date = .now) throws -> ExportBundle {
        var bundle = ExportBundle(exportedAt: now)

        bundle.skills = try context.fetch(FetchDescriptor<Skill>(sortBy: [SortDescriptor(\.branchRaw), SortDescriptor(\.sortOrder)])).map {
            SkillRecord(id: $0.id.uuidString, branch: $0.branchRaw, name: $0.name, evidence: $0.evidence,
                        state: $0.stateRaw, isBottleneck: $0.isBottleneck)
        }
        bundle.pieces = try context.fetch(FetchDescriptor<Piece>(sortBy: [SortDescriptor(\.createdAt)])).map {
            PieceRecord(id: $0.id.uuidString, title: $0.title, composer: $0.composer, notes: $0.notes,
                        isCurrent: $0.isCurrent, createdAt: $0.createdAt)
        }
        bundle.tasks = try context.fetch(FetchDescriptor<PracticeTask>(sortBy: [SortDescriptor(\.createdAt)])).map {
            TaskRecord(id: $0.id.uuidString, title: $0.title, context: $0.contextNote, skillID: $0.skill?.id.uuidString,
                       pieceID: $0.piece?.id.uuidString, inventorySample: $0.inventorySampleRaw,
                       isArchived: $0.isArchived, createdAt: $0.createdAt)
        }
        bundle.sessions = try context.fetch(FetchDescriptor<PracticeSession>(sortBy: [SortDescriptor(\.startedAt)])).map {
            SessionRecord(id: $0.id.uuidString, kind: $0.kindRaw, startedAt: $0.startedAt, endedAt: $0.endedAt,
                          plannedMinutes: $0.plannedMinutes, practisedSeconds: Int($0.elapsed(at: $0.endedAt ?? now)),
                          plan: $0.planRaw, focusTaskID: $0.focusTask?.id.uuidString,
                          smallerExercise: $0.focusSmallerExercise, correction: $0.focusCorrection,
                          variation: $0.focusVariation, backIntoMusic: $0.focusReintegration,
                          stepNotes: $0.stepNotes, whatGotEasier: $0.closingEasier, nextTime: $0.closingNext)
        }
        bundle.attempts = try context.fetch(FetchDescriptor<Attempt>(sortBy: [SortDescriptor(\.date)])).map {
            AttemptRecord(id: $0.id.uuidString, taskID: $0.task?.id.uuidString, sessionID: $0.session?.id.uuidString,
                          date: $0.date, phase: $0.isRetest ? "coldRetest" : $0.phaseRaw, tempo: $0.tempo,
                          errorCategory: $0.errorCategoryRaw, observation: $0.observation,
                          smallerExercise: $0.smallerExercise, outcome: $0.outcomeRaw, nextStep: $0.nextStep)
        }
        bundle.retests = try context.fetch(FetchDescriptor<Retest>(sortBy: [SortDescriptor(\.scheduledAt)])).map {
            RetestRecord(id: $0.id.uuidString, taskID: $0.task?.id.uuidString, scheduledAt: $0.scheduledAt,
                         dueDate: $0.dueDate, context: $0.context, completedAttemptID: $0.resultAttemptID?.uuidString)
        }
        bundle.recordings = try context.fetch(FetchDescriptor<Recording>(sortBy: [SortDescriptor(\.createdAt)])).map {
            RecordingRecord(id: $0.id.uuidString, fileName: $0.fileName, createdAt: $0.createdAt, durationSeconds: $0.duration,
                            title: $0.title, taskID: $0.task?.id.uuidString, attemptID: $0.attempt?.id.uuidString,
                            sessionID: $0.session?.id.uuidString)
        }
        bundle.notes = try context.fetch(FetchDescriptor<JournalNote>(sortBy: [SortDescriptor(\.date)])).map {
            NoteRecord(id: $0.id.uuidString, date: $0.date, text: $0.text)
        }
        return bundle
    }

    /// Writes the export to a temporary file for the share sheet.
    static func writeFile(from context: ModelContext, now: Date = .now) throws -> URL {
        let bundle = try makeBundle(from: context, now: now)
        let day = now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appending(path: "PianoDeeply-\(day).json")
        try bundle.encoded().write(to: url, options: .atomic)
        return url
    }
}
