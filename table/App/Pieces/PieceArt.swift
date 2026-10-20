import SwiftUI
import ChessCore

/// One drawing command of the piece artwork, in the 100 x 100 art box.
enum PathCommand {
    case m(CGFloat, CGFloat)
    case l(CGFloat, CGFloat)
    case c(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    case z
}

/// The vector layers of one piece design, built once into reusable paths.
struct PieceArt {
    /// Filled silhouettes. Several may overlap (the queen's coronet balls), so outlines are
    /// stroked underneath the fill to read as a single shape.
    let bodies: [Path]
    let silhouette: Path
    let details: Path
    let cuts: Path

    init(body: [[PathCommand]], detail: [[PathCommand]], cut: [[PathCommand]]) {
        bodies = body.map(Self.path)
        var all = Path()
        for p in bodies { all.addPath(p) }
        silhouette = all
        var d = Path()
        for p in detail { d.addPath(Self.path(p)) }
        details = d
        var c = Path()
        for p in cut { c.addPath(Self.path(p)) }
        cuts = c
    }

    private static func path(_ commands: [PathCommand]) -> Path {
        var p = Path()
        for cmd in commands {
            switch cmd {
            case let .m(x, y): p.move(to: CGPoint(x: x, y: y))
            case let .l(x, y): p.addLine(to: CGPoint(x: x, y: y))
            case let .c(x1, y1, x2, y2, x, y):
                p.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
            case .z: p.closeSubpath()
            }
        }
        return p
    }
}

/// The finish of a piece: turned boxwood for white, ebonised wood for black.
struct PieceMaterial {
    let stops: [Gradient.Stop]
    let outline: Color
    let detail: Color
    let detailOpacity: Double
    let cut: Color
    let rimLight: Color

    static let boxwood = PieceMaterial(
        stops: [
            .init(color: Color(hex: 0xBFA885), location: 0.00),
            .init(color: Color(hex: 0xE8DBC1), location: 0.16),
            .init(color: Color(hex: 0xFBF4E6), location: 0.32),
            .init(color: Color(hex: 0xFFFCF4), location: 0.42),
            .init(color: Color(hex: 0xEADFC8), location: 0.60),
            .init(color: Color(hex: 0xC7B28E), location: 0.82),
            .init(color: Color(hex: 0xA88F6A), location: 1.00),
        ],
        outline: Color(hex: 0x4B3826),
        detail: Color(hex: 0x6E5638),
        detailOpacity: 0.62,
        cut: Color(hex: 0x5A4430),
        rimLight: Color.white.opacity(0.55)
    )

    static let ebony = PieceMaterial(
        stops: [
            .init(color: Color(hex: 0x0B0807), location: 0.00),
            .init(color: Color(hex: 0x2A211C), location: 0.16),
            .init(color: Color(hex: 0x4E4038), location: 0.32),
            .init(color: Color(hex: 0x5F5046), location: 0.42),
            .init(color: Color(hex: 0x3A2F28), location: 0.60),
            .init(color: Color(hex: 0x1A1411), location: 0.82),
            .init(color: Color(hex: 0x0A0706), location: 1.00),
        ],
        outline: Color(hex: 0x050403),
        detail: Color(hex: 0x8A7462),
        detailOpacity: 0.55,
        cut: Color(hex: 0x050403),
        rimLight: Color(hex: 0xC9AE92).opacity(0.42)
    )

    static func of(_ color: PieceColor) -> PieceMaterial { color == .white ? .boxwood : .ebony }
}

enum PieceRenderer {
    static let artScale: CGFloat = 1.07
    /// Where the foot of a piece sits, as a fraction of the square's height.
    static let baseline: CGFloat = 0.93

    /// Draws a piece into `rect` of a graphics context. Everything is vector, so it is sharp at any size.
    static func draw(_ piece: Piece, in context: inout GraphicsContext, rect: CGRect) {
        let art = PieceArtwork.art(for: piece.kind)
        let m = PieceMaterial.of(piece.color)
        var ctx = context
        // Pieces stand on a common baseline near the foot of the square, drawn slightly larger
        // than the 100-unit art box so they have presence without touching their neighbours.
        let k = rect.width / 100 * artScale
        ctx.translateBy(x: rect.midX, y: rect.minY + rect.height * baseline)
        ctx.scaleBy(x: k, y: k)
        ctx.translateBy(x: -50, y: -92)

        // Outline first; the fill then covers its inner half, leaving one clean edge around overlaps.
        let outline = StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round)
        for body in art.bodies {
            ctx.stroke(body, with: .color(m.outline), style: outline)
        }

        // Cylindrical shading across the turned form, lit from the upper left.
        let across = GraphicsContext.Shading.linearGradient(
            Gradient(stops: m.stops), startPoint: CGPoint(x: 21, y: 0), endPoint: CGPoint(x: 79, y: 0))
        let down = GraphicsContext.Shading.linearGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.10), location: 0),
                .init(color: .white.opacity(0.0), location: 0.5),
                .init(color: .black.opacity(0.0), location: 0.78),
                .init(color: .black.opacity(0.18), location: 1),
            ]),
            startPoint: CGPoint(x: 0, y: 8), endPoint: CGPoint(x: 0, y: 92))
        for body in art.bodies {
            ctx.fill(body, with: across)
        }
        ctx.fill(art.silhouette, with: down)

        // A fine rim of light along the upper-left edges keeps dark pieces legible on dark squares.
        var rim = ctx
        rim.clip(to: art.silhouette)
        rim.stroke(art.silhouette,
                   with: .linearGradient(Gradient(colors: [m.rimLight, m.rimLight.opacity(0)]),
                                         startPoint: CGPoint(x: 22, y: 10), endPoint: CGPoint(x: 64, y: 80)),
                   lineWidth: 2.2)

        ctx.stroke(art.details, with: .color(m.detail.opacity(m.detailOpacity)),
                   style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
        ctx.fill(art.cuts, with: .color(m.cut))
    }
}

/// A single piece glyph at any size.
struct PieceGlyph: View {
    let piece: Piece

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            PieceRenderer.draw(piece, in: &context, rect: CGRect(origin: .zero, size: size))
        }
        .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
