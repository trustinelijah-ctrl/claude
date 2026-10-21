import SwiftUI
import ChessCore

enum HoldState: Equatable {
    /// Standing on the board.
    case resting
    /// Chosen with a tap; raised a little.
    case selected
    /// Under a finger, not yet moving.
    case held
    /// Being carried by a finger.
    case dragging
    /// Being carried by the computer's unseen hand.
    case carried
}

/// One piece on the table, with its shadow, lift, swing and landing.
/// Equatable, so while one piece is dragged the other thirty-one are not redrawn.
struct TokenView: View, Equatable {
    let token: PieceToken
    let position: CGPoint
    let size: CGFloat
    let rotated: Bool
    let hold: HoldState
    let translation: CGSize
    let lift: CGSize
    /// Swing while carried, in degrees.
    let tilt: Double
    /// Direction from the lamp, roughly -0.5...0.5 on each axis.
    let light: CGSize
    let revealed: Bool
    let shadowStrength: Double
    /// A beaten king, tipped over on its square.
    var fallen = false

    var body: some View {
        PieceBody(piece: token.piece, size: size, hold: hold, rotated: rotated,
                  light: light, shadowStrength: shadowStrength, fallen: fallen)
            // The landing: a weighted piece meeting felt gives a touch, then settles.
            .keyframeAnimator(initialValue: CGFloat(1), trigger: token.landing) { content, squash in
                content.scaleEffect(x: 2 - squash, y: squash, anchor: baseAnchor)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.93, duration: 0.05)
                    SpringKeyframe(1.0, duration: 0.32, spring: Spring(response: 0.26, dampingRatio: 0.5))
                }
            }
            .scaleEffect(scale, anchor: baseAnchor)
            .rotationEffect(.degrees(tilt), anchor: UnitPoint(x: 0.5, y: rotated ? 0.92 : 0.08))
            .animation(Motion.pickup, value: hold)
            .animation(.spring(response: 0.32, dampingFraction: 0.5), value: tilt)
            .opacity(revealed ? 1 : 0)
            .offset(lift)
            .position(x: position.x + translation.width, y: position.y + translation.height)
            .animation(token.motion, value: token.revision)
            .animation(.easeOut(duration: 0.4).delay(Double(token.square.rank) * 0.024), value: revealed)
    }

    /// Pieces grow from their base, not from the middle of the square.
    private var baseAnchor: UnitPoint {
        UnitPoint(x: 0.5, y: rotated ? 1 - PieceSprite.squareBase : PieceSprite.squareBase)
    }

    private var scale: CGFloat {
        switch hold {
        case .resting: return 1
        case .selected: return 1.05
        case .held: return 1.12
        case .dragging: return 1.16
        case .carried: return 1.12
        }
    }
}

/// The piece and its shadow. Lifting raises the piece off its shadow, which drifts further
/// from the base and grows wider and softer, as an object rising toward a lamp would.
struct PieceBody: View {
    let piece: Piece
    let size: CGFloat
    let hold: HoldState
    let rotated: Bool
    let light: CGSize
    let shadowStrength: Double
    var fallen = false
    @Environment(\.pieceSet) private var set

    /// How far the piece is off the board, 0 (standing) to 1 (carried).
    private var rise: CGFloat {
        switch hold {
        case .resting: return 0
        case .selected: return 0.3
        case .held: return 0.65
        case .dragging, .carried: return 1
        }
    }

    var body: some View {
        // Shadow drift in screen space, converted into the piece's own frame when it is turned.
        let drift = CGSize(width: light.width * size * (0.22 + 0.3 * rise),
                           height: light.height * size * (0.22 + 0.3 * rise) + size * 0.07 * rise)
        let local = rotated ? CGSize(width: -drift.width, height: -drift.height) : drift
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(shadowStrength * Double(1 - 0.45 * rise)), .black.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.36 * (1 + rise * 0.4)))
                .frame(width: size * (0.74 + rise * 0.24) * (fallen ? 1.45 : 1), height: size * (0.34 + rise * 0.14))
                .offset(x: local.width + (fallen ? size * 0.24 : 0), y: size * PieceSprite.baseOffset + local.height)
            Image(PieceSprite.imageName(piece, set: set))
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: size * PieceSprite.scale, height: size * PieceSprite.scale)
                // Tipped about the edge of its base, coming to rest on its side.
                .rotationEffect(.degrees(fallen ? 84 : 0), anchor: UnitPoint(x: 0.62, y: PieceSprite.spriteBase))
                .offset(x: fallen ? -size * 0.12 : 0,
                        y: size * PieceSprite.spriteOffset - size * 0.09 * rise - (fallen ? size * 0.1 : 0))
                .animation(fallen ? .spring(response: 0.42, dampingFraction: 0.52) : .spring(response: 0.45, dampingFraction: 0.8),
                           value: fallen)
                .id("\(set.rawValue)-\(piece.color.rawValue)-\(piece.kind.rawValue)")
                .transition(.opacity.animation(.easeInOut(duration: 0.24)))
        }
        .frame(width: size, height: size)
        .rotationEffect(rotated ? .degrees(180) : .zero)
        .allowsHitTesting(false)
    }
}
