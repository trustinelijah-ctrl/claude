import SwiftUI

/// A drawn keyboard. Highlighted keys can carry a label (the note name).
struct KeyboardView: View {
    enum Mark { case tone, bass }

    var range: ClosedRange<Int>
    var marks: [Int: Mark] = [:]
    var labels: [Int: String] = [:]

    private static let whitePitchClasses: Set<Int> = [0, 2, 4, 5, 7, 9, 11]
    static func isWhite(_ midi: Int) -> Bool { whitePitchClasses.contains(((midi % 12) + 12) % 12) }

    var body: some View {
        Canvas { context, size in
            let whites = range.filter(Self.isWhite)
            guard !whites.isEmpty else { return }
            let whiteWidth = size.width / CGFloat(whites.count)
            let blackWidth = whiteWidth * 0.62
            let blackHeight = size.height * 0.6

            for (index, midi) in whites.enumerated() {
                let rect = CGRect(x: CGFloat(index) * whiteWidth, y: 0, width: whiteWidth, height: size.height)
                    .insetBy(dx: 0.75, dy: 0)
                let shape = UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5).path(in: rect)
                context.fill(shape, with: .color(fill(for: midi, white: true)))
                context.stroke(shape, with: .color(Palette.keyEdge), lineWidth: 0.75)
                if let label = labels[midi] {
                    context.draw(
                        Text(label).font(.caption.weight(.bold)).foregroundStyle(Palette.onForest),
                        at: CGPoint(x: rect.midX, y: rect.maxY - 14)
                    )
                }
            }

            for midi in range where !Self.isWhite(midi) {
                let whitesBelow = whites.filter { $0 < midi }.count
                guard whitesBelow > 0 else { continue }
                let x = CGFloat(whitesBelow) * whiteWidth - blackWidth / 2
                let rect = CGRect(x: x, y: 0, width: blackWidth, height: blackHeight)
                let shape = UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3).path(in: rect)
                context.fill(shape, with: .color(fill(for: midi, white: false)))
                if let label = labels[midi] {
                    context.draw(
                        Text(label).font(.caption2.weight(.bold)).foregroundStyle(Palette.onForest),
                        at: CGPoint(x: rect.midX, y: rect.maxY - 11)
                    )
                }
            }
        }
    }

    private func fill(for midi: Int, white: Bool) -> Color {
        switch marks[midi] {
        case .bass: Palette.brass
        case .tone: Palette.forest
        case nil: white ? Palette.whiteKey : Palette.blackKey
        }
    }
}

/// The recurring motif: a short run of keys, used once on Today and once on
/// Just play. Decorative, so hidden from VoiceOver.
struct KeyboardMotif: View {
    var body: some View {
        KeyboardView(range: 60...76)
            .frame(width: 132, height: 30)
            .opacity(0.9)
            .accessibilityHidden(true)
    }
}

#Preview("Keyboard") {
    KeyboardView(range: 53...77, marks: [55: .bass, 58: .tone, 62: .tone, 65: .tone],
                 labels: [55: "G", 58: "B♭", 62: "D", 65: "F"])
        .frame(height: 120)
        .padding()
}
