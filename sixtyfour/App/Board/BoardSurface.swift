import SwiftUI

/// The physical board: framed rim, inlay, the 64 veneered squares and engraved coordinates.
/// Static artwork, flattened once into a single layer.
struct BoardSurface: View {
    let theme: BoardTheme
    let geometry: BoardGeometry
    let showCoordinates: Bool
    /// Also set the coordinates along the far edges, turned for the player opposite.
    var mirrorCoordinates = true

    var body: some View {
        let g = geometry
        let corner: CGFloat = g.rim > 0 ? max(4, g.size * 0.011) : 2
        ZStack(alignment: .topLeading) {
            // Frame
            Image(theme.rimImage)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: g.size, height: g.size)
                .clipped()
            theme.rimTint

            // Bevel: light catches the outer top edge, the lower edge falls into shade.
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [theme.rimHighlight, .clear, .black.opacity(0.35)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: max(1, g.rim * 0.08))

            // Gilt tooling just outside the playing surface
            Rectangle()
                .strokeBorder(theme.inlay.opacity(0.95), lineWidth: max(1, g.rim * 0.14))
                .frame(width: g.inner + g.rim * 0.7, height: g.inner + g.rim * 0.7)
                .offset(x: g.rim * 0.65, y: g.rim * 0.65)

            // Playing surface, recessed a hair below the frame
            Image(theme.surfaceImage)
                .resizable()
                .interpolation(.high)
                .frame(width: g.inner, height: g.inner)
                .overlay {
                    // The lamp's pool of light: brightest over the centre, falling off to the edges.
                    RadialGradient(colors: [.clear, .black.opacity(theme.vignette)],
                                   center: .center, startRadius: g.inner * 0.2, endRadius: g.inner * 0.78)
                }
                .overlay {
                    Rectangle()
                        .strokeBorder(Color.black.opacity(theme.isDark ? 0.5 : 0.28), lineWidth: 1.5)
                        .blur(radius: 1.2)
                        .clipped()
                }
                .offset(x: g.rim, y: g.rim)

            if showCoordinates {
                coordinates(g)
            }
        }
        .frame(width: g.size, height: g.size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .drawingGroup()
    }

    /// Fine coordinates set into the corners of the edge squares: files along the near rank,
    /// ranks up the near-left file, and (face to face) the same again turned for the far player.
    @ViewBuilder
    private func coordinates(_ g: BoardGeometry) -> some View {
        let font = Font.system(size: max(9, g.square * 0.14), weight: .semibold)
        let files = Array("abcdefgh")
        let pad = g.square * 0.07
        ForEach(0..<8, id: \.self) { i in
            let file = String(files[g.flipped ? 7 - i : i])
            let rank = "\(g.flipped ? i + 1 : 8 - i)"       // rank of screen row i
            let left = g.rim + CGFloat(i) * g.square
            let top = g.rim + CGFloat(i) * g.square
            Group {
                // near edge: file at the bottom-right of each bottom square, rank at the top-left of each left square
                Text(file)
                    .foregroundStyle(ink(col: i, row: 7))
                    .frame(width: g.square - 2 * pad, height: g.square - 2 * pad, alignment: .bottomTrailing)
                    .position(x: left + g.square / 2, y: g.rim + 7.5 * g.square)
                Text(rank)
                    .foregroundStyle(ink(col: 0, row: i))
                    .frame(width: g.square - 2 * pad, height: g.square - 2 * pad, alignment: .topLeading)
                    .position(x: g.rim + 0.5 * g.square, y: top + g.square / 2)
                if mirrorCoordinates {
                    Text(file)
                        .foregroundStyle(ink(col: i, row: 0))
                        .frame(width: g.square - 2 * pad, height: g.square - 2 * pad, alignment: .bottomTrailing)
                        .rotationEffect(.degrees(180))
                        .position(x: left + g.square / 2, y: g.rim + 0.5 * g.square)
                    Text(rank)
                        .foregroundStyle(ink(col: 7, row: i))
                        .frame(width: g.square - 2 * pad, height: g.square - 2 * pad, alignment: .topLeading)
                        .rotationEffect(.degrees(180))
                        .position(x: g.rim + 7.5 * g.square, y: top + g.square / 2)
                }
            }
            .font(font)
        }
    }

    /// Coordinates take the opposite tone of the square they sit on.
    private func ink(col: Int, row: Int) -> Color {
        let light = (col + row) % 2 == 0
        if light {
            return theme.isDark ? Color(hex: 0x1E2B26, opacity: 0.62) : Color(hex: 0x2A2C30, opacity: 0.5)
        }
        return theme.coordinate
    }
}

/// A soft line of light along the edge of the player whose move it is.
struct TurnEdge: View {
    let theme: BoardTheme
    let geometry: BoardGeometry
    let side: PieceColorSide
    let active: Bool
    let nudge: Int

    @State private var pulse = false

    var body: some View {
        let g = geometry
        Capsule()
            .fill(LinearGradient(stops: [
                .init(color: theme.turnGlow.opacity(0), location: 0),
                .init(color: theme.turnGlow.opacity(0.95), location: 0.5),
                .init(color: theme.turnGlow.opacity(0), location: 1),
            ], startPoint: .leading, endPoint: .trailing))
            .frame(width: g.inner * 0.62, height: max(1.5, g.rim * 0.075))
            .shadow(color: theme.turnGlow.opacity(0.7), radius: g.rim * 0.25)
            .opacity(active ? (pulse ? 1 : 0.78) : 0)
            .scaleEffect(x: active ? 1 : 0.7, y: 1)
            .position(x: g.size / 2, y: side == .bottom ? g.size - g.rim * 0.16 : g.rim * 0.16)
            .animation(.easeInOut(duration: 0.35), value: active)
            .onChange(of: nudge) {
                withAnimation(.easeOut(duration: 0.12)) { pulse = true }
                withAnimation(.easeIn(duration: 0.45).delay(0.14)) { pulse = false }
            }
            .allowsHitTesting(false)
    }
}

enum PieceColorSide { case bottom, top }
