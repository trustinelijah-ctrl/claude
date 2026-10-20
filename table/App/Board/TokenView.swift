import SwiftUI
import ChessCore

enum HoldState: Equatable {
    case resting, selected, held, dragging
}

/// One piece on the board, with its shadow, lift and movement.
struct TokenView: View {
    let token: PieceToken
    let geometry: BoardGeometry
    let facesOpponent: Bool
    let hold: HoldState
    let translation: CGSize
    let lift: CGSize
    let revealed: Bool
    let shadowStrength: Double

    var body: some View {
        let sq = geometry.square
        let base = geometry.center(token.square)
        PieceBody(piece: token.piece, size: sq, hold: hold, rotated: facesOpponent,
                  light: lightDirection(base), shadowStrength: shadowStrength)
            .scaleEffect(scale, anchor: anchor)
            .animation(Motion.lift, value: hold)
            .opacity(token.isCaptured ? 0 : (revealed ? 1 : 0))
            .scaleEffect(token.isCaptured ? 0.84 : 1, anchor: anchor)
            .blur(radius: token.isCaptured ? sq * 0.03 : 0)
            .offset(lift)
            .position(x: base.x + translation.width, y: base.y + translation.height)
            .animation(token.motion, value: token.revision)
            .animation(.easeOut(duration: 0.4).delay(Double(token.square.rank) * 0.024), value: revealed)
    }

    /// Pieces grow from their base, not from the middle of the square.
    private var anchor: UnitPoint {
        UnitPoint(x: 0.5, y: facesOpponent ? 1 - PieceSprite.squareBase : PieceSprite.squareBase)
    }

    /// The lamp hangs over the centre of the table, so each shadow falls outward from it.
    private func lightDirection(_ p: CGPoint) -> CGSize {
        let c = geometry.size / 2
        return CGSize(width: (p.x - c) / geometry.inner, height: (p.y - c) / geometry.inner)
    }

    private var scale: CGFloat {
        switch hold {
        case .resting: return 1
        case .selected: return 1.03
        case .held: return 1.06
        case .dragging: return 1.12
        }
    }
}

/// The piece and its shadow on the board. Lifting it raises the piece and lets the shadow
/// drift further from the base, wider and softer, as an object rising toward a lamp would.
struct PieceBody: View {
    let piece: Piece
    let size: CGFloat
    let hold: HoldState
    let rotated: Bool
    /// Direction from the lamp, in screen space, roughly -0.5...0.5 on each axis.
    let light: CGSize
    let shadowStrength: Double

    var body: some View {
        let rise: CGFloat = hold == .dragging ? 1 : (hold == .held ? 0.45 : (hold == .selected ? 0.2 : 0))
        // Shadow drift in screen space, converted into the piece's own frame when it is turned.
        let drift = CGSize(width: light.width * size * (0.22 + 0.25 * rise),
                           height: light.height * size * (0.22 + 0.25 * rise) + size * 0.05 * rise)
        let local = rotated ? CGSize(width: -drift.width, height: -drift.height) : drift
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(shadowStrength * (1 - 0.35 * rise)), .black.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.36 * (1 + rise * 0.3)))
                .frame(width: size * (0.74 + rise * 0.2), height: size * (0.34 + rise * 0.12))
                .offset(x: local.width, y: size * PieceSprite.baseOffset + local.height)
            Image(PieceSprite.imageName(piece))
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: size * PieceSprite.scale, height: size * PieceSprite.scale)
                .offset(y: size * PieceSprite.spriteOffset - size * 0.035 * rise)
                .id(piece)
                .transition(.opacity.animation(.easeInOut(duration: 0.24)))
        }
        .frame(width: size, height: size)
        .rotationEffect(rotated ? .degrees(180) : .zero)
        .allowsHitTesting(false)
    }
}
