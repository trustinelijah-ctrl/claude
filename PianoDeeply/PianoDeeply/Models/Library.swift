import Foundation
import SwiftData

@Model
final class Piece {
    var id: UUID = UUID()
    var title: String = ""
    var composer: String = ""
    var notes: String = ""
    /// Shown on Today. More than one can be current.
    var isCurrent: Bool = true
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \PracticeTask.piece)
    var tasks: [PracticeTask] = []

    init(title: String, composer: String = "", notes: String = "") {
        self.title = title
        self.composer = composer
        self.notes = notes
    }

    var lastWorkedOn: Date? {
        tasks.flatMap(\.attempts).map(\.date).max()
    }
}

/// A small discovery or thought that isn't tied to one attempt.
@Model
final class JournalNote {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String = ""

    init(text: String, date: Date = .now) {
        self.text = text
        self.date = date
    }
}

/// Metadata for an audio file in Documents/Recordings. The file is the
/// source of truth for the audio; this record can outlive a missing file and
/// says so in the UI rather than failing silently.
@Model
final class Recording {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var fileName: String = ""
    var duration: Double = 0
    var title: String = ""

    var task: PracticeTask?
    var attempt: Attempt?
    var session: PracticeSession?

    init(fileName: String, duration: Double, title: String, createdAt: Date = .now) {
        self.fileName = fileName
        self.duration = duration
        self.title = title
        self.createdAt = createdAt
    }

    var url: URL { RecordingStore.url(for: fileName) }
    var fileExists: Bool { RecordingStore.fileExists(fileName) }

    var displayTitle: String {
        if !title.isEmpty { return title }
        if let task { return task.title }
        return "Recording"
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Skill.self, PracticeTask.self, Attempt.self, Retest.self,
        PracticeSession.self, Recording.self, Piece.self, JournalNote.self,
    ]
}
