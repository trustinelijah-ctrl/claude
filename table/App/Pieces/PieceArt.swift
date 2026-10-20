import SwiftUI
import ChessCore

/// The piece set: ivory and ebony, turned and gilded, rendered offline in 3D by
/// `tools/render3d.py` from the lathe profiles in `tools/pieces.py`.
///
/// Every sprite shares one framing: the piece is seen from 35 degrees above the table,
/// and the centre of its base sits `spriteBase` of the way down the image.
enum PieceSprite {
    /// Sprite size relative to the square it stands on. Pieces are taller than their
    /// squares, as real pieces are; the tallest crowns reach a little into the square behind.
    static let scale: CGFloat = 1.16
    /// Centre of the base within the sprite, from the top.
    static let spriteBase: CGFloat = 0.81
    /// Where the base stands within its square, from the top, for a piece facing the bottom edge.
    static let squareBase: CGFloat = 0.71

    static func imageName(_ piece: Piece) -> String {
        "piece-\(piece.color.rawValue)-\(piece.kind.rawValue)"
    }

    /// Offset of the sprite's centre from the square's centre, as a fraction of the square.
    static var spriteOffset: CGFloat { squareBase - 0.5 - scale * (spriteBase - 0.5) }
    /// Offset of the base's centre from the square's centre, as a fraction of the square.
    static var baseOffset: CGFloat { squareBase - 0.5 }
}

/// A piece standing upright, filling a square frame: used in trays, pickers and swatches.
struct PieceGlyph: View {
    let piece: Piece

    var body: some View {
        Image(PieceSprite.imageName(piece))
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// A piece standing on the table with its own small shadow, for captured pieces and pickers.
struct StandingPiece: View {
    let piece: Piece
    let size: CGFloat
    var shadow: Double = 0.5

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(shadow), .black.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.34))
                .frame(width: size * 0.7, height: size * 0.26)
                .offset(y: size * (PieceSprite.spriteBase - 0.5) + size * 0.03)
            PieceGlyph(piece: piece)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}
