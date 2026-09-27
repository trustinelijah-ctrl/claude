import XCTest
@testable import PianoCore

final class ChordTheoryTests: XCTestCase {
    func testTwoFiveOneInFIsSpelledCorrectly() {
        let chords = Progression.twoFiveOne(in: .f)
        XCTAssertEqual(chords.map(\.name), ["Gm7", "C7", "Fmaj7"])
        XCTAssertEqual(chords.map(\.function), ["ii", "V", "I"])
        XCTAssertEqual(chords[0].tones.map(\.description), ["G", "B♭", "D", "F"])
        XCTAssertEqual(chords[1].tones.map(\.description), ["C", "E", "G", "B♭"])
        XCTAssertEqual(chords[2].tones.map(\.description), ["F", "A", "C", "E"])
    }

    func testOtherKeysUseFlatsAndSharpsCorrectly() {
        XCTAssertEqual(Progression.twoFiveOne(in: .bFlat).map { $0.tones.map(\.description) },
                       [["C", "E♭", "G", "B♭"], ["F", "A", "C", "E♭"], ["B♭", "D", "F", "A"]])
        XCTAssertEqual(Progression.twoFiveOne(in: SpelledNote(letter: 4)).map { $0.tones.map(\.description) },
                       [["A", "C", "E", "G"], ["D", "F♯", "A", "C"], ["G", "B", "D", "F♯"]])
        XCTAssertEqual(Progression.twoFiveOne(in: .c).map(\.name), ["Dm7", "G7", "Cmaj7"])
    }

    func testVoicingsInFAreTheExpectedKeys() {
        let chords = Progression.twoFiveOne(in: .f)
        // Gm7 root position: G3 B♭3 D4 F4 (MIDI 60 = middle C).
        XCTAssertEqual(chords[0].voicing(inversion: 0).map(\.midi), [55, 58, 62, 65])
        // Gm7 1st inversion: B♭3 D4 F4 G4.
        XCTAssertEqual(chords[0].voicing(inversion: 1).map(\.midi), [58, 62, 65, 67])
        // C7 2nd inversion: G3 B♭3 C4 E4.
        XCTAssertEqual(chords[1].voicing(inversion: 2).map(\.midi), [55, 58, 60, 64])
        // Fmaj7 root position: F3 A3 C4 E4.
        XCTAssertEqual(chords[2].voicing(inversion: 0).map(\.midi), [53, 57, 60, 64])
        // Fmaj7 3rd inversion puts E in the bass: E4 F4 A4 C5.
        XCTAssertEqual(chords[2].voicing(inversion: 3).map(\.midi), [64, 65, 69, 72])
        XCTAssertEqual(chords[2].voicing(inversion: 3).map(\.name.description), ["E", "F", "A", "C"])
    }

    func testEveryVoicingHasTheRightPitchClassesAndBass() {
        for key in Progression.keys {
            for chord in Progression.twoFiveOne(in: key) {
                for inversion in 0..<chord.inversionCount {
                    let voicing = chord.voicing(inversion: inversion)
                    XCTAssertEqual(Set(voicing.map { $0.midi % 12 }), Set(chord.tones.map(\.pitchClass)), chord.name)
                    XCTAssertEqual(voicing.first?.name, chord.tones[inversion], "\(chord.name) inversion \(inversion) bass")
                    XCTAssertEqual(voicing.map(\.midi), voicing.map(\.midi).sorted())
                    XCTAssertLessThan(voicing.last!.midi - voicing.first!.midi, 12, "close position")
                    XCTAssertTrue(voicing.allSatisfy { Progression.keyboardRange.contains($0.midi) },
                                  "\(chord.name) inversion \(inversion) must fit the drawn keyboard")
                }
            }
        }
    }

    func testSmoothVoiceLeadingMovesEachVoiceAtMostAWholeStepInEveryOfferedKey() {
        for key in Progression.keys {
            let chords = Progression.twoFiveOne(in: key)
            let voicings = zip(chords, Progression.smoothTwoFiveOne).map { $0.voicing(inversion: $1).map(\.midi) }
            for (a, b) in zip(voicings, voicings.dropFirst()) {
                let moves = zip(a, b).map { abs($0 - $1) }
                XCTAssertTrue(moves.allSatisfy { $0 <= 2 }, "\(key) ii–V–I moves \(moves)")
            }
        }
    }

    func testSpokenNamesForVoiceOver() {
        XCTAssertEqual(Progression.twoFiveOne(in: .f).map(\.spokenName), ["G minor seven", "C seven", "F major seven"])
        XCTAssertEqual(SpelledNote.bFlat.spoken, "B flat")
    }
}
