import Foundation

/// Whether an attempt was a first pass with no warm-up on that material, or
/// came after working on it. Evidence is only ever compared within one phase.
public enum AttemptPhase: String, CaseIterable, Codable, Identifiable, Sendable {
    case cold
    case afterPractice

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .cold: "Cold first pass"
        case .afterPractice: "After practice"
        }
    }
}

/// What kind of thing went wrong. Picking one is the "diagnose" step; it is
/// never used to score anything.
public enum ErrorCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case notes
    case rhythm
    case fingering
    case coordination
    case control
    case reading
    case memory
    case tension
    case sound
    case unsure

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .notes: "Wrong notes"
        case .rhythm: "Rhythm or pulse"
        case .fingering: "Fingering"
        case .coordination: "Hands together"
        case .control: "Too fast to control"
        case .reading: "Lost my place reading"
        case .memory: "Memory slip"
        case .tension: "Tension or effort"
        case .sound: "Sound or balance"
        case .unsure: "Not sure yet"
        }
    }

    /// A first idea for shrinking the problem. Suggestions only; the user
    /// writes the actual exercise.
    public var shrinkIdea: String {
        switch self {
        case .notes: "Play just the notes that went wrong, slowly, then add one note either side."
        case .rhythm: "Clap or tap the rhythm, then play it on one note before using the real notes."
        case .fingering: "Choose a fingering, write it down, and play only the crossing three times."
        case .coordination: "Hands separately until each is easy, then together at half tempo."
        case .control: "Drop the metronome 20 bpm and play it until it feels boring."
        case .reading: "Say the note names aloud for the bar, then play it without stopping."
        case .memory: "Play from the slip point three times, then start one phrase earlier."
        case .tension: "Play it softer and slower, checking shoulders and wrist on each downbeat."
        case .sound: "Play the melody alone, then add the accompaniment as quietly as you can."
        case .unsure: "Play it once more, slowly, and listen for the first moment it stops feeling easy."
        }
    }
}

/// How a specific experiment went.
public enum ExperimentOutcome: String, CaseIterable, Codable, Identifiable, Sendable {
    case worked
    case partly
    case notYet

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .worked: "It worked"
        case .partly: "Partly"
        case .notYet: "Not yet"
        }
    }
}

/// The short response shown after logging an experiment. Only a finished
/// experiment that worked gets the warm response; tapping around never does.
public struct ExperimentFeedback: Equatable, Sendable {
    public let message: String
    public let celebrate: Bool

    public static func after(outcome: ExperimentOutcome, tempo: Int?, phase: AttemptPhase) -> ExperimentFeedback {
        switch outcome {
        case .worked:
            let tempoPart = tempo.map { "Even at \($0) bpm." } ?? "That worked."
            let next = phase == .cold ? "It held up cold. Try it a notch faster next time." : "Try it cold next time."
            return ExperimentFeedback(message: "\(tempoPart) \(next)", celebrate: true)
        case .partly:
            return ExperimentFeedback(message: "Part of it's there. Shrink the bit that isn't and try again.", celebrate: false)
        case .notYet:
            return ExperimentFeedback(message: "Useful to know. Make it smaller or slower and try again.", celebrate: false)
        }
    }
}
