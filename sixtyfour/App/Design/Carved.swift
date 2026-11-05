import SwiftUI

// The player's end of the table is worked into the wood itself, quietly: the captured pieces
// stand in a shallow groove, and the words, marks and clock are cut into the surface and
// filled with gold. Nothing sits on top of the wood in a box. Everything is lit from the
// lamp over the middle of the board, so a groove is shadowed along the edge nearest it.

/// A recess cut into the table: its floor (felt, or the wood itself darkened by its own
/// shade), the shadow cast by the upper wall, and a fine catch of light along the lower lip.
struct CarvedRecess<S: InsettableShape>: View {
    let shape: S
    /// The floor of the recess: the felt colour, or nil for bare, shaded wood.
    var felt: Color? = nil
    /// 0...1, how deep it reads.
    var depth: CGFloat = 1

    var body: some View {
        ZStack {
            if let felt {
                shape.fill(felt)
                Image("Felt")
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(0.55)
                    .clipShape(shape)
            } else {
                shape.fill(Color.black.opacity(0.1))
            }
            // The upper wall's shadow, falling onto the floor, and a softer ambient one all round.
            InnerShadow(shape: shape, color: .black.opacity(0.8 * depth), radius: 5 * depth, y: 3.5 * depth)
            InnerShadow(shape: shape, color: .black.opacity(0.35 * depth), radius: 1.5, y: 0)
            // The edges of the cut: dark along the top, the lamp catching the lower lip.
            shape.strokeBorder(LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0),
                                                       .init(color: .black.opacity(0.0), location: 0.45),
                                                       .init(color: .white.opacity(0.0), location: 0.6),
                                                       .init(color: .white.opacity(0.2), location: 1)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .padding(-0.5)
        }
        .compositingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A shadow cast inward from a shape's edge: a thick blurred stroke, nudged down and kept
/// inside the shape.
struct InnerShadow<S: Shape>: View {
    let shape: S
    let color: Color
    let radius: CGFloat
    var y: CGFloat = 0

    var body: some View {
        shape
            .stroke(color, lineWidth: radius * 2 + 2)
            .blur(radius: radius)
            .offset(y: y)
            .mask(shape)
            .allowsHitTesting(false)
    }
}

extension View {
    /// Letters cut into the wood and filled with gold leaf: the gold sits a little below the
    /// surface, shadowed under the top edge of each cut, with the lower edge catching light.
    func gilded(_ strength: Double = 1) -> some View {
        self
            .foregroundStyle(
                LinearGradient(colors: [Color(hex: 0xF3DEA4), Color(hex: 0xD4AF66), Color(hex: 0xA07C3C)],
                               startPoint: .top, endPoint: .bottom)
                    .shadow(.inner(color: .black.opacity(0.55 * strength), radius: 0.6, x: 0, y: 1))
            )
            .shadow(color: .white.opacity(0.14 * strength), radius: 0, x: 0, y: 0.75)
    }

    /// Letters simply cut into the wood: darker than the surface, with a lit lower edge.
    func engraved(_ color: Color = .black, opacity: Double = 0.5) -> some View {
        self
            .foregroundStyle(color.opacity(opacity).shadow(.inner(color: .black.opacity(0.6), radius: 0.6, x: 0, y: 1)))
            .shadow(color: .white.opacity(0.16), radius: 0, x: 0, y: 0.75)
    }
}

/// The clock, cut into the wood: digits only. While that player's time runs they are lit
/// gold with a soft glow and a fine rule beneath; while waiting they sit dim in the wood.
struct ClockWindow<Content: View>: View {
    let running: Bool
    let low: Bool
    let theme: BoardTheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .shadow(color: running ? (low ? Color(hex: 0xFF5A48) : Color(hex: 0xFFD98A)).opacity(0.35) : .clear, radius: 8)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, (low ? Color(hex: 0xE0574A) : Brand.gold).opacity(running ? 0.8 : 0), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 0.75)
                    .padding(.horizontal, 10)
            }
    }
}

/// The controls at a player's end: their marks stand on the wood with nothing around them.
struct ControlRail<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
    }
}

/// A little room between two controls.
struct RailDivider: View {
    var body: some View {
        Color.clear.frame(width: 4, height: 1).accessibilityHidden(true)
    }
}
