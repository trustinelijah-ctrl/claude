import Foundation

/// The eight branches of the skill map. Fixed, because every other part of the
/// app (inventory, suggestions, export) refers to them by raw value.
public enum SkillBranch: String, CaseIterable, Codable, Identifiable, Sendable {
    case technique
    case rhythm
    case reading
    case ear
    case harmony
    case repertoire
    case improvisation
    case selfCoaching

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .technique: "Technique & touch"
        case .rhythm: "Rhythm"
        case .reading: "Reading"
        case .ear: "Ear"
        case .harmony: "Harmony & chords"
        case .repertoire: "Repertoire"
        case .improvisation: "Improvisation & creation"
        case .selfCoaching: "Self-coaching"
        }
    }

    public var summary: String {
        switch self {
        case .technique: "Getting the sound you mean with a hand that stays free."
        case .rhythm: "Keeping time, feeling subdivision, landing together."
        case .reading: "Turning the page into sound without stopping."
        case .ear: "Hearing it, then finding it on the keys."
        case .harmony: "Knowing what the chords are and where your hands go."
        case .repertoire: "Pieces you can play, keep, and bring back."
        case .improvisation: "Making things up, arranging, writing."
        case .selfCoaching: "Noticing what went wrong and choosing what to try next."
        }
    }

    /// SF Symbol name. Kept here so the map and the journal agree.
    public var symbol: String {
        switch self {
        case .technique: "hand.raised.fingers.spread"
        case .rhythm: "metronome"
        case .reading: "music.note.list"
        case .ear: "ear"
        case .harmony: "pianokeys"
        case .repertoire: "music.quarternote.3"
        case .improvisation: "sparkles"
        case .selfCoaching: "magnifyingglass"
        }
    }

    /// Starting subskills. The user can rename, delete, or add to these; they
    /// begin as `notExplored` so the map never shows progress nobody made.
    public var starterSubskills: [SubskillTemplate] {
        switch self {
        case .technique: [
            .init("Five-finger evenness", evidence: "Five-note pattern, each hand, even at 80 bpm with no accents I didn't choose."),
            .init("Scales & thumb crossings", evidence: "Two-octave scale hands separately without a bump at the crossing."),
            .init("Voicing the melody", evidence: "Melody audibly louder than the accompaniment on a recording."),
            .init("Staying relaxed", evidence: "Shoulders and wrist loose through a whole passage; I can check mid-phrase."),
        ]
        case .rhythm: [
            .init("Steady pulse", evidence: "Play with a metronome for 16 bars and stay with it."),
            .init("Subdivision", evidence: "Count and play eighths, triplets, and sixteenths against a beat."),
            .init("Swing & syncopation", evidence: "Play a syncopated left-hand pattern against a steady right hand."),
        ]
        case .reading: [
            .init("Easy sight-reading", evidence: "Read a new 8-bar piece a level below mine without stopping."),
            .init("Reading both clefs", evidence: "Name and play bass-clef notes as quickly as treble."),
            .init("Reading ahead", evidence: "Keep eyes a beat ahead of the hands through a phrase."),
        ]
        case .ear: [
            .init("Melodies by ear", evidence: "Find a short familiar melody on the keys in under five minutes."),
            .init("Hearing chord quality", evidence: "Tell major, minor, and dominant 7th apart when someone plays them."),
            .init("Hearing bass lines", evidence: "Play the bass line of a song I know."),
        ]
        case .harmony: [
            .init("Triads & inversions", evidence: "Play any major or minor triad in all three positions without stopping to think."),
            .init("Seventh chords", evidence: "Play maj7, m7, and dominant 7 from any root."),
            .init("ii–V–I", evidence: "Play ii–V–I in three keys with smooth voice leading."),
            .init("Lead-sheet voicings", evidence: "Play a lead sheet with melody in the right hand and chords in the left."),
        ]
        case .repertoire: [
            .init("Learning a new piece", evidence: "A new piece goes from reading to slowly playable in a few weeks."),
            .init("Keeping old pieces", evidence: "Play a piece I haven't touched in a month, cold, through the hard spots."),
            .init("Playing for someone", evidence: "Play one piece for a person, or into a recording, start to finish."),
        ]
        case .improvisation: [
            .init("Free playing", evidence: "Play two minutes without stopping, on anything."),
            .init("Improvising over changes", evidence: "Keep a right-hand line going over a repeated progression."),
            .init("Arranging a song", evidence: "Make a simple arrangement of a song I love."),
        ]
        case .selfCoaching: [
            .init("Naming the problem", evidence: "After a stumble, say what went wrong in one specific sentence."),
            .init("Shrinking the problem", evidence: "Turn a failing passage into a smaller exercise that works."),
            .init("Testing later", evidence: "Check a fix cold the next day instead of trusting today's version."),
        ]
        }
    }
}

public struct SubskillTemplate: Equatable, Sendable {
    public let name: String
    public let evidence: String
    public init(_ name: String, evidence: String) {
        self.name = name
        self.evidence = evidence
    }
}

/// Qualitative states. Deliberately not a number: "fluent" in reading and
/// "fluent" in improvising are not the same amount of anything.
public enum SkillState: String, CaseIterable, Codable, Identifiable, Sendable {
    case notExplored
    case understood
    case slowlyPlayable
    case fluent
    case reliableLater
    case usableFreely

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .notExplored: "Not explored"
        case .understood: "Understood"
        case .slowlyPlayable: "Slowly playable"
        case .fluent: "Fluent"
        case .reliableLater: "Reliable later"
        case .usableFreely: "Usable freely"
        }
    }

    public var meaning: String {
        switch self {
        case .notExplored: "Haven't looked at it yet."
        case .understood: "I know what it is and how it should go."
        case .slowlyPlayable: "I can do it slowly, with attention."
        case .fluent: "I can do it at tempo today."
        case .reliableLater: "It still works cold, days later."
        case .usableFreely: "I can use it in music I didn't prepare."
        }
    }
}
