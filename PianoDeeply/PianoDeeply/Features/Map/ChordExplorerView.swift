import SwiftUI
import PianoCore

/// ii–V–I with correct spelling, drawn on a keyboard, with inversion controls.
/// All the theory comes from PianoCore, where it is tested.
struct ChordExplorerView: View {
    @State private var keyIndex = 0
    @State private var inversions = [0, 0, 0]

    private var key: SpelledNote { Progression.keys[keyIndex] }
    private var chords: [Chord] { Progression.twoFiveOne(in: key) }
    private var isSmooth: Bool { inversions == Progression.smoothTwoFiveOne }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ii–V–I in \(key.description)")
                        .font(.displayTitle)
                    Text("You'll find it all over jazz standards and plenty of pop. Brass marks the lowest note.")
                        .foregroundStyle(Palette.inkSoft)
                }

                Picker("Key", selection: $keyIndex) {
                    ForEach(Progression.keys.indices, id: \.self) { index in
                        Text(Progression.keys[index].description).tag(index)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(Array(chords.enumerated()), id: \.offset) { index, chord in
                    ChordCard(chord: chord, inversion: $inversions[index])
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button(isSmooth ? "Showing smooth voice leading" : "Show smooth voice leading") {
                        inversions = Progression.smoothTwoFiveOne
                    }
                    .buttonStyle(.secondary)
                    .disabled(isSmooth)
                    Text("ii in root position, V in second inversion, I in root position. Each note moves a step or less, or stays put.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSoft)
                    if !isSmooth && inversions != [0, 0, 0] {
                        Button("Back to root position") { inversions = [0, 0, 0] }
                            .frame(minHeight: 44)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("Chords")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChordCard: View {
    let chord: Chord
    @Binding var inversion: Int

    private var voicing: [VoicedNote] { chord.voicing(inversion: inversion) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(chord.function)
                    .font(.system(.title3, design: .serif).italic())
                    .foregroundStyle(Palette.brass)
                Text(chord.name)
                    .font(.displayHeadline)
                Spacer()
                Text(Chord.inversionName(inversion))
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
            }

            KeyboardView(
                range: Progression.keyboardRange,
                marks: Dictionary(uniqueKeysWithValues: voicing.enumerated().map { pair in
                    (pair.element.midi, pair.offset == 0 ? KeyboardView.Mark.bass : KeyboardView.Mark.tone)
                }),
                labels: Dictionary(uniqueKeysWithValues: voicing.map { ($0.midi, $0.name.description) })
            )
            .frame(height: 110)
            .accessibilityElement()
            .accessibilityLabel("\(chord.spokenName), \(Chord.inversionName(inversion)). From the bottom: \(voicing.map(\.name.spoken).joined(separator: ", ")).")

            Text("Notes: \(chord.tones.map(\.description).joined(separator: " – "))")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)
                .accessibilityLabel("Chord tones: \(chord.tones.map(\.spoken).joined(separator: ", "))")

            Picker("Inversion", selection: $inversion) {
                ForEach(0..<chord.inversionCount, id: \.self) { index in
                    Text(index == 0 ? "Root" : ["1st", "2nd", "3rd"][index - 1]).tag(index)
                }
            }
            .pickerStyle(.segmented)
        }
        .surface()
    }
}

#if DEBUG
#Preview("ii–V–I") {
    NavigationStack { ChordExplorerView() }
}
#endif
