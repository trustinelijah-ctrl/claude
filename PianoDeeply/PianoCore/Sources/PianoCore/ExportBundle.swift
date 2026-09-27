import Foundation

/// Everything the app stores, as plain JSON. Records reference each other by
/// UUID string. Audio stays on the device; each recording lists its file name
/// so an audio file shared separately can be matched back to its entry.
public struct ExportBundle: Codable, Equatable, Sendable {
    public var format = "piano-deeply-export"
    public var version = 1
    public var exportedAt: Date
    public var audioNote = "Audio files are not embedded. Share a recording from the Journal to get its .m4a file; fileName matches."
    public var skills: [SkillRecord] = []
    public var pieces: [PieceRecord] = []
    public var tasks: [TaskRecord] = []
    public var sessions: [SessionRecord] = []
    public var attempts: [AttemptRecord] = []
    public var retests: [RetestRecord] = []
    public var recordings: [RecordingRecord] = []
    public var notes: [NoteRecord] = []

    public init(exportedAt: Date) {
        self.exportedAt = exportedAt
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> ExportBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportBundle.self, from: data)
    }

    public var isEmpty: Bool {
        pieces.isEmpty && tasks.isEmpty && sessions.isEmpty && attempts.isEmpty
            && retests.isEmpty && recordings.isEmpty && notes.isEmpty
    }
}

public struct SkillRecord: Codable, Equatable, Sendable {
    public var id: String
    public var branch: String
    public var name: String
    public var evidence: String
    public var state: String
    public var isBottleneck: Bool
    public init(id: String, branch: String, name: String, evidence: String, state: String, isBottleneck: Bool) {
        self.id = id; self.branch = branch; self.name = name; self.evidence = evidence; self.state = state; self.isBottleneck = isBottleneck
    }
}

public struct PieceRecord: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var composer: String
    public var notes: String
    public var isCurrent: Bool
    public var createdAt: Date
    public init(id: String, title: String, composer: String, notes: String, isCurrent: Bool, createdAt: Date) {
        self.id = id; self.title = title; self.composer = composer; self.notes = notes; self.isCurrent = isCurrent; self.createdAt = createdAt
    }
}

public struct TaskRecord: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var context: String
    public var skillID: String?
    public var pieceID: String?
    public var inventorySample: String?
    public var isArchived: Bool
    public var createdAt: Date
    public init(id: String, title: String, context: String, skillID: String?, pieceID: String?, inventorySample: String?, isArchived: Bool, createdAt: Date) {
        self.id = id; self.title = title; self.context = context; self.skillID = skillID; self.pieceID = pieceID
        self.inventorySample = inventorySample; self.isArchived = isArchived; self.createdAt = createdAt
    }
}

public struct SessionRecord: Codable, Equatable, Sendable {
    public var id: String
    public var kind: String
    public var startedAt: Date
    public var endedAt: Date?
    public var plannedMinutes: Int
    public var practisedSeconds: Int
    public var plan: String
    public var focusTaskID: String?
    public var smallerExercise: String
    public var correction: String
    public var variation: String
    public var backIntoMusic: String
    public var stepNotes: [String: String]
    public var whatGotEasier: String
    public var nextTime: String
    public init(id: String, kind: String, startedAt: Date, endedAt: Date?, plannedMinutes: Int, practisedSeconds: Int, plan: String,
                focusTaskID: String?, smallerExercise: String = "", correction: String = "", variation: String = "",
                backIntoMusic: String = "", stepNotes: [String: String] = [:], whatGotEasier: String = "", nextTime: String = "") {
        self.id = id; self.kind = kind; self.startedAt = startedAt; self.endedAt = endedAt; self.plannedMinutes = plannedMinutes
        self.practisedSeconds = practisedSeconds; self.plan = plan; self.focusTaskID = focusTaskID
        self.smallerExercise = smallerExercise; self.correction = correction; self.variation = variation
        self.backIntoMusic = backIntoMusic; self.stepNotes = stepNotes; self.whatGotEasier = whatGotEasier; self.nextTime = nextTime
    }
}

public struct AttemptRecord: Codable, Equatable, Sendable {
    public var id: String
    public var taskID: String?
    public var sessionID: String?
    public var date: Date
    public var phase: String
    public var tempo: Int?
    public var errorCategory: String?
    public var observation: String
    public var smallerExercise: String
    public var outcome: String?
    public var nextStep: String
    public init(id: String, taskID: String?, sessionID: String?, date: Date, phase: String, tempo: Int?, errorCategory: String?, observation: String, smallerExercise: String, outcome: String?, nextStep: String) {
        self.id = id; self.taskID = taskID; self.sessionID = sessionID; self.date = date; self.phase = phase; self.tempo = tempo
        self.errorCategory = errorCategory; self.observation = observation; self.smallerExercise = smallerExercise; self.outcome = outcome; self.nextStep = nextStep
    }
}

public struct RetestRecord: Codable, Equatable, Sendable {
    public var id: String
    public var taskID: String?
    public var scheduledAt: Date
    public var dueDate: Date
    public var context: String
    public var completedAttemptID: String?
    public init(id: String, taskID: String?, scheduledAt: Date, dueDate: Date, context: String, completedAttemptID: String?) {
        self.id = id; self.taskID = taskID; self.scheduledAt = scheduledAt; self.dueDate = dueDate; self.context = context; self.completedAttemptID = completedAttemptID
    }
}

public struct RecordingRecord: Codable, Equatable, Sendable {
    public var id: String
    public var fileName: String
    public var createdAt: Date
    public var durationSeconds: Double
    public var title: String
    public var taskID: String?
    public var attemptID: String?
    public var sessionID: String?
    public init(id: String, fileName: String, createdAt: Date, durationSeconds: Double, title: String, taskID: String?, attemptID: String?, sessionID: String?) {
        self.id = id; self.fileName = fileName; self.createdAt = createdAt; self.durationSeconds = durationSeconds
        self.title = title; self.taskID = taskID; self.attemptID = attemptID; self.sessionID = sessionID
    }
}

public struct NoteRecord: Codable, Equatable, Sendable {
    public var id: String
    public var date: Date
    public var text: String
    public init(id: String, date: Date, text: String) {
        self.id = id; self.date = date; self.text = text
    }
}
