import Foundation

/// The six-sample restart inventory. Each sample becomes an ordinary practice
/// task with one cold attempt, so the four-week check is just another cold
/// retest of the same task: like for like.
public enum InventorySample: String, CaseIterable, Identifiable, Sendable {
    case familiarPiece
    case easyReading
    case scaleInversion
    case chordProgression
    case melodyByEar
    case freePlaying

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .familiarPiece: "A familiar piece"
        case .easyReading: "Easy unseen reading"
        case .scaleInversion: "A scale or inversion"
        case .chordProgression: "A chord progression"
        case .melodyByEar: "A short melody by ear"
        case .freePlaying: "Two minutes of free playing"
        }
    }

    public var instruction: String {
        switch self {
        case .familiarPiece: "Play something you used to know, from wherever you can start. No warm-up on it first."
        case .easyReading: "Pick something you've never seen that looks easy. Play it through once without stopping to fix."
        case .scaleInversion: "One scale, hands separately then together, or one triad through its inversions."
        case .chordProgression: "Any progression you know, or ii–V–I in F: Gm7, C7, Fmaj7."
        case .melodyByEar: "A tune you can sing, like a folk song or a theme. Find it on the keys."
        case .freePlaying: "Play anything for two minutes without stopping. This one has nothing to get right."
        }
    }

    public var branch: SkillBranch {
        switch self {
        case .familiarPiece: .repertoire
        case .easyReading: .reading
        case .scaleInversion: .technique
        case .chordProgression: .harmony
        case .melodyByEar: .ear
        case .freePlaying: .improvisation
        }
    }

    /// Suggested task title; the user can rename it ("Clair de lune, bars 1–8").
    public var taskTitle: String {
        switch self {
        case .familiarPiece: "Familiar piece, cold"
        case .easyReading: "Easy unseen reading"
        case .scaleInversion: "Scale or inversion check"
        case .chordProgression: "Chord progression check"
        case .melodyByEar: "Melody by ear"
        case .freePlaying: "Two minutes of free playing"
        }
    }

    public static let recheckInterval = RetestInterval.fourWeeks
}
