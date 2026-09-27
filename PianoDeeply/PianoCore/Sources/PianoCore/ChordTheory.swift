import Foundation

/// A note name with correct spelling (B♭ in F major, not A♯).
public struct SpelledNote: Equatable, Hashable, Sendable, CustomStringConvertible {
    /// 0 = C … 6 = B.
    public let letter: Int
    /// -2 … 2 (double flat … double sharp).
    public let accidental: Int

    static let letters = ["C", "D", "E", "F", "G", "A", "B"]
    static let naturalSemitones = [0, 2, 4, 5, 7, 9, 11]

    public init(letter: Int, accidental: Int = 0) {
        self.letter = ((letter % 7) + 7) % 7
        self.accidental = accidental
    }

    public var pitchClass: Int {
        ((Self.naturalSemitones[letter] + accidental) % 12 + 12) % 12
    }

    public var description: String {
        let mark: String
        switch accidental {
        case -2: mark = "𝄫"
        case -1: mark = "♭"
        case 1: mark = "♯"
        case 2: mark = "𝄪"
        default: mark = ""
        }
        return Self.letters[letter] + mark
    }

    /// Spoken form for VoiceOver ("B flat").
    public var spoken: String {
        switch accidental {
        case -2: "\(Self.letters[letter]) double flat"
        case -1: "\(Self.letters[letter]) flat"
        case 1: "\(Self.letters[letter]) sharp"
        case 2: "\(Self.letters[letter]) double sharp"
        default: Self.letters[letter]
        }
    }

    /// The note `steps` letters above with a total distance of `semitones`,
    /// spelled accordingly (a minor third above G is B♭, not A♯).
    public func up(steps: Int, semitones: Int) -> SpelledNote {
        let targetLetter = (letter + steps) % 7
        let targetPC = (pitchClass + semitones) % 12
        var diff = (targetPC - Self.naturalSemitones[targetLetter]) % 12
        if diff > 6 { diff -= 12 }
        if diff < -6 { diff += 12 }
        return SpelledNote(letter: targetLetter, accidental: diff)
    }

    public static let c = SpelledNote(letter: 0)
    public static let f = SpelledNote(letter: 3)
    public static let bFlat = SpelledNote(letter: 6, accidental: -1)
}

public enum ChordQuality: String, CaseIterable, Sendable {
    case major, minor, dominant7, minor7, major7

    /// (letter steps, semitones) above the root for each chord tone.
    var intervals: [(Int, Int)] {
        switch self {
        case .major: [(0, 0), (2, 4), (4, 7)]
        case .minor: [(0, 0), (2, 3), (4, 7)]
        case .dominant7: [(0, 0), (2, 4), (4, 7), (6, 10)]
        case .minor7: [(0, 0), (2, 3), (4, 7), (6, 10)]
        case .major7: [(0, 0), (2, 4), (4, 7), (6, 11)]
        }
    }

    var suffix: String {
        switch self {
        case .major: ""
        case .minor: "m"
        case .dominant7: "7"
        case .minor7: "m7"
        case .major7: "maj7"
        }
    }

    var spokenSuffix: String {
        switch self {
        case .major: " major"
        case .minor: " minor"
        case .dominant7: " seven"
        case .minor7: " minor seven"
        case .major7: " major seven"
        }
    }
}

public struct Chord: Equatable, Sendable {
    public let root: SpelledNote
    public let quality: ChordQuality
    /// Roman numeral in context, e.g. "ii".
    public let function: String

    public init(root: SpelledNote, quality: ChordQuality, function: String = "") {
        self.root = root
        self.quality = quality
        self.function = function
    }

    public var name: String { root.description + quality.suffix }
    public var spokenName: String { root.spoken + quality.spokenSuffix }

    /// Chord tones in root position order: root, third, fifth, (seventh).
    public var tones: [SpelledNote] {
        quality.intervals.map { root.up(steps: $0.0, semitones: $0.1) }
    }

    public var inversionCount: Int { tones.count }

    /// Close-position voicing as MIDI note numbers, lowest first. The bass
    /// note is the lowest one at or above `anchor`; each note above it is the
    /// next available instance of its pitch class.
    public func voicing(inversion: Int, anchor: Int = 53) -> [VoicedNote] {
        let count = tones.count
        let k = ((inversion % count) + count) % count
        let ordered = Array(tones[k...] + tones[..<k])
        var result: [VoicedNote] = []
        var floor = anchor
        for tone in ordered {
            let midi = floor + ((tone.pitchClass - floor % 12) + 12) % 12
            result.append(VoicedNote(midi: midi, name: tone))
            floor = midi + 1
        }
        return result
    }

    public static func inversionName(_ inversion: Int) -> String {
        switch inversion {
        case 0: "Root position"
        case 1: "1st inversion"
        case 2: "2nd inversion"
        default: "3rd inversion"
        }
    }
}

public struct VoicedNote: Equatable, Hashable, Sendable {
    public let midi: Int
    public let name: SpelledNote
}

public enum Progression {
    /// ii–V–I in a major key: ii m7, V7, I maj7.
    public static func twoFiveOne(in key: SpelledNote) -> [Chord] {
        [
            Chord(root: key.up(steps: 1, semitones: 2), quality: .minor7, function: "ii"),
            Chord(root: key.up(steps: 4, semitones: 7), quality: .dominant7, function: "V"),
            Chord(root: key, quality: .major7, function: "I"),
        ]
    }

    /// Inversions giving the classic close voice leading for ii–V–I:
    /// ii in root position, V in second inversion, I in root position. Each
    /// voice moves by at most a whole step.
    public static let smoothTwoFiveOne = [0, 2, 0]

    /// Keys offered in the chord explorer, starting with F. Each is checked
    /// by the tests: `smoothTwoFiveOne` moves every voice by a step or less,
    /// and every inversion fits on the drawn keyboard (`keyboardRange`).
    public static let keys: [SpelledNote] = [.f, .c, .bFlat, SpelledNote(letter: 4)]

    /// F3 to F5.
    public static let keyboardRange = 53...77
}
