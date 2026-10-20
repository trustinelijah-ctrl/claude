import SwiftUI
import ChessCore

enum HoldState: Equatable {
    case resting, selected, held, dragging
}

/// One piece on the board, with its contact shadow, lift and movement.
struct TokenView: View {
    let token: PieceToken
    let geometry: BoardGeometry
    let facesOpponent: Bool
    let hold: HoldState
    let translation: CGSize
    let lift: CGSize
    let revealed: Bool

    var body: some View {
        let sq = geometry.square
        let base = geometry.center(token.square)
        PieceBody(piece: token.piece, size: sq, hold: hold, rotated: facesOpponent)
            .scaleEffect(scale)
            .animation(Motion.lift, value: hold)
            .opacity(token.isCaptured ? 0 : (revealed ? 1 : 0))
            .scaleEffect(token.isCaptured ? 0.84 : 1)
            .blur(radius: token.isCaptured ? sq * 0.03 : 0)
            .offset(lift)
            .position(x: base.x + translation.width, y: base.y + translation.height)
            .animation(token.motion, value: token.revision)
            .animation(.easeOut(duration: 0.34).delay(Double(token.square.rank) * 0.022), value: revealed)
    }

    private var scale: CGFloat {
        switch hold {
        case .resting: return 1
        case .selected: return 1.035
        case .held: return 1.07
        case .dragging: return 1.13
        }
    }
}

/// The glyph standing on its contact shadow. The shadow stays under the base and spreads
/// and softens as the piece is lifted off the board.
struct PieceBody: View {
    let piece: Piece
    let size: CGFloat
    let hold: HoldState
    let rotated: Bool

    var body: some View {
        let lifted = hold == .dragging || hold == .held
        let rise: CGFloat = hold == .dragging ? 1 : (hold == .held ? 0.45 : (hold == .selected ? 0.2 : 0))
        // Light comes from above the table's far side for both players, so in the piece's own
        // frame the shadow falls toward its base, slightly more so the higher it is lifted.
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(lifted ? 0.30 : 0.42), .black.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.31 * (1 + rise * 0.35)))
                .frame(width: size * (0.60 + rise * 0.16), height: size * (0.15 + rise * 0.08))
                .offset(y: size * (PieceRenderer.baseline - 0.5 - 0.01 + rise * 0.06))
            PieceGlyph(piece: piece)
                .frame(width: size, height: size)
                .offset(y: -size * 0.02 * rise)
                .id(piece)
                .transition(.opacity.animation(.easeInOut(duration: 0.22)))
        }
        .frame(width: size, height: size)
        .rotationEffect(rotated ? .degrees(180) : .zero)
    }
}
