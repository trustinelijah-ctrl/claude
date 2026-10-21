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
struct TokenView: View {
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

    var body: some View {
        PieceBody(piece: token.piece, size: size, hold: hold, rotated: rotated,
                  light: light, shadowStrength: shadowStrength)
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

    var body: some View {
        let rise: CGFloat
        switch hold {
        case .resting: rise = 0
        case .selected: rise = 0.3
        case .held: rise = 0.65
        case .dragging, .carried: rise = 1
        }
        // Shadow drift in screen space, converted into the piece's own frame when it is turned.
        let drift = CGSize(width: light.width * size * (0.22 + 0.3 * rise),
                           height: light.height * size * (0.22 + 0.3 * rise) + size * 0.07 * rise)
        let local = rotated ? CGSize(width: -drift.width, height: -drift.height) : drift
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(shadowStrength * Double(1 - 0.45 * rise)), .black.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.36 * (1 + rise * 0.4)))
                .frame(width: size * (0.74 + rise * 0.24), height: size * (0.34 + rise * 0.14))
                .offset(x: local.width, y: size * PieceSprite.baseOffset + local.height)
            Image(PieceSprite.imageName(piece))
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: size * PieceSprite.scale, height: size * PieceSprite.scale)
                .offset(y: size * PieceSprite.spriteOffset - size * 0.09 * rise)
                .id(piece)
                .transition(.opacity.animation(.easeInOut(duration: 0.24)))
        }
        .frame(width: size, height: size)
        .rotationEffect(rotated ? .degrees(180) : .zero)
        .allowsHitTesting(false)
    }
}
