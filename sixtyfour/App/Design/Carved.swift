import SwiftUI

// The player's end of the table is worked into the wood itself, the way a fine games table
// is made: the captured pieces stand in a recess lined with felt, the controls sit in a
// routed rail, the clock looks out through a small window with a brass bezel, and words are
// cut into the surface and filled with gold. Everything here is lit from the lamp over the
// middle of the board, so each recess is shadowed along the edge nearest the board.

extension BoardTheme {
    /// The baize that lines this table's recesses.
    var felt: Color {
        switch id {
        case .house, .tournament: Color(hex: 0x1D3A2A)
        case .walnut, .rosewood: Color(hex: 0x3F1517)
        case .ebony: Color(hex: 0x2B1113)
        case .salon: Color(hex: 0x0F261D)
        case .slate: Color(hex: 0x23272C)
        case .marble, .midnight: Color(hex: 0x172036)
        case .olive: Color(hex: 0x24321E)
        }
    }
}

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
                shape.fill(Color.black.opacity(0.22))
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

/// A clock window: a small pane of glass in a brass bezel, set into the table. The dial
/// behind it is lit like enamel while that player's time runs and falls dark while it waits.
struct ClockWindow<Content: View>: View {
    let running: Bool
    let low: Bool
    let theme: BoardTheme
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        content
            .background {
                ZStack {
                    // The dial: warm enamel when running, smoked glass when waiting.
                    shape.fill(running
                               ? (low ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xB0352C), Color(hex: 0x7E1E19)], startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFBF3E2), Color(hex: 0xE8DAC0)], startPoint: .top, endPoint: .bottom)))
                               : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x17110C), Color(hex: 0x0C0806)], startPoint: .top, endPoint: .bottom)))
                    // Set below the bezel: shadow under its upper edge.
                    InnerShadow(shape: shape, color: .black.opacity(running ? 0.45 : 0.8), radius: 3, y: 2)
                    // The glass: a faint diagonal reflection of the lamp.
                    shape.fill(LinearGradient(stops: [.init(color: .white.opacity(running ? 0.22 : 0.08), location: 0),
                                                      .init(color: .white.opacity(0.0), location: 0.48),
                                                      .init(color: .white.opacity(0.0), location: 1)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .overlay {
                // The brass bezel: bright where the lamp hits its upper face, dark below.
                shape.strokeBorder(LinearGradient(colors: [Color(hex: 0xF6E2AE), Color(hex: 0xC59C52), Color(hex: 0x6E4F22)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .padding(-2)
            }
            .background {
                // The bezel sits in a cut in the wood: a fine dark seam around it.
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .padding(-3)
                    .blur(radius: 0.8)
            }
            .shadow(color: running && !low ? Color(hex: 0xFFE7B0).opacity(theme.isDark ? 0.18 : 0.1) : .clear, radius: 10)
    }
}

/// The routed rail the controls sit in: one long, shallow channel in the wood.
struct ControlRail<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(CarvedRecess(shape: Capsule(style: .continuous), depth: 0.8))
    }
}

/// The groove between two controls in the rail.
struct RailDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.black.opacity(0.45)).frame(width: 0.75)
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 0.75)
        }
        .frame(height: 26)
        .accessibilityHidden(true)
    }
}
