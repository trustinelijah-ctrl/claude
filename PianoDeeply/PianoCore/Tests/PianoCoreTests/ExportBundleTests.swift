import XCTest
@testable import PianoCore

final class ExportBundleTests: XCTestCase {
    func testRoundTripKeepsEveryRecord() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        var bundle = ExportBundle(exportedAt: date)
        bundle.tasks = [TaskRecord(id: "T1", title: "Bars 9–12", context: "Left hand alone", skillID: "S1", pieceID: nil,
                                   inventorySample: "familiarPiece", isArchived: false, createdAt: date)]
        bundle.attempts = [AttemptRecord(id: "A1", taskID: "T1", sessionID: "X1", date: date, phase: "cold", tempo: 72,
                                         errorCategory: "coordination", observation: "Hands split at the turn",
                                         smallerExercise: "", outcome: nil, nextStep: "Hands separately at 60")]
        bundle.recordings = [RecordingRecord(id: "R1", fileName: "R1.m4a", createdAt: date, durationSeconds: 41.5,
                                             title: "Cold pass", taskID: "T1", attemptID: "A1", sessionID: nil)]
        let data = try bundle.encoded()
        XCTAssertEqual(try ExportBundle.decode(data), bundle)
    }

    func testJSONIsHumanReadableWithISODates() throws {
        let bundle = ExportBundle(exportedAt: Date(timeIntervalSince1970: 0))
        let json = String(decoding: try bundle.encoded(), as: UTF8.self)
        XCTAssertTrue(json.contains("\"exportedAt\" : \"1970-01-01T00:00:00Z\""), json)
        XCTAssertTrue(json.contains("\"format\" : \"piano-deeply-export\""))
        XCTAssertTrue(bundle.isEmpty)
    }

    func testNilOptionalsDoNotBreakDecoding() throws {
        var bundle = ExportBundle(exportedAt: Date(timeIntervalSince1970: 5))
        bundle.sessions = [SessionRecord(id: "S", kind: "justPlay", startedAt: Date(timeIntervalSince1970: 5), endedAt: nil,
                                         plannedMinutes: 0, practisedSeconds: 0, plan: "", focusTaskID: nil, closingNote: "")]
        XCTAssertEqual(try ExportBundle.decode(bundle.encoded()).sessions.first?.endedAt, nil)
        XCTAssertFalse(bundle.isEmpty)
    }
}
