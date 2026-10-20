import SwiftUI

/// The physical board: framed rim, inlay, the 64 veneered squares and engraved coordinates.
/// Static artwork, flattened once into a single layer.
struct BoardSurface: View {
    let theme: BoardTheme
    let geometry: BoardGeometry
    let showCoordinates: Bool

    var body: some View {
        let g = geometry
        let corner = max(4, g.size * 0.011)
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

            // Gilt tooling: a line just outside the playing surface, and a finer one near the edge
            Rectangle()
                .strokeBorder(theme.inlay.opacity(0.9), lineWidth: max(0.75, g.rim * 0.055))
                .frame(width: g.inner + g.rim * 0.42, height: g.inner + g.rim * 0.42)
                .offset(x: g.rim * 0.79, y: g.rim * 0.79)
            if theme.doubleTooling {
                Rectangle()
                    .strokeBorder(theme.inlay.opacity(0.55), lineWidth: max(0.5, g.rim * 0.025))
                    .frame(width: g.size - g.rim * 0.36, height: g.size - g.rim * 0.36)
                    .offset(x: g.rim * 0.18, y: g.rim * 0.18)
            }

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

    /// Engraved file letters and rank numbers, set once for each player along their own edges.
    @ViewBuilder
    private func coordinates(_ g: BoardGeometry) -> some View {
        let font = Typeface.display(max(8, g.rim * 0.5), bold: true)
        let files = Array("abcdefgh")
        ForEach(0..<8, id: \.self) { i in
            let x = g.rim + (CGFloat(i) + 0.5) * g.square
            let y = g.rim + (CGFloat(7 - i) + 0.5) * g.square
            Group {
                Text(String(files[i])).position(x: x, y: g.size - g.rim * 0.5)
                Text(String(files[i])).rotationEffect(.degrees(180)).position(x: x, y: g.rim * 0.5)
                Text("\(i + 1)").position(x: g.rim * 0.5, y: y)
                Text("\(i + 1)").rotationEffect(.degrees(180)).position(x: g.size - g.rim * 0.5, y: y)
            }
            .font(font)
            .foregroundStyle(theme.coordinate)
        }
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
