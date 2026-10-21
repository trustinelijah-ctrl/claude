import SwiftUI
import ChessCore

// Live scenes for the welcome pages, built from the real board materials and piece sprites.
// Each runs only while its page is showing.

/// A piece in a scene, with a stable identity so moves animate.
private struct ScenePiece: Identifiable, Equatable {
    let id: Int
    let piece: Piece
    var square: Square
}

/// Page one: the whole board between two seats, with an opening being played across it.
struct FaceToFaceScene: View {
    let theme: BoardTheme
    let size: CGFloat
    let active: Bool
    let feedback: FeedbackCoordinator

    @State private var pieces: [ScenePiece] = FaceToFaceScene.start()
    @State private var landing: [Int: Int] = [:]

    private static let opening = ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6"]

    private static func start() -> [ScenePiece] {
        var id = 0
        return Square.all.compactMap { sq in
            guard let p = Position.start[sq] else { return nil }
            id += 1
            return ScenePiece(id: id, piece: p, square: sq)
        }
    }

    var body: some View {
        let boardSize = size * 0.84
        let g = BoardGeometry(size: boardSize)
        VStack(spacing: size * 0.025) {
            seat("Them", flipped: true)
            ZStack(alignment: .topLeading) {
                BoardSurface(theme: theme, geometry: g, showCoordinates: false, mirrorCoordinates: false)
                ForEach(pieces) { p in
                    PieceBody(piece: p.piece, size: g.square, hold: .resting, rotated: p.piece.color == .black,
                              light: .zero, shadowStrength: theme.pieceShadow)
                        .keyframeAnimator(initialValue: CGFloat(1), trigger: landing[p.id, default: 0]) { content, squash in
                            content.scaleEffect(x: 2 - squash, y: squash, anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                        } keyframes: { _ in
                            KeyframeTrack {
                                CubicKeyframe(0.92, duration: 0.05)
                                SpringKeyframe(1.0, duration: 0.3, spring: Spring(response: 0.26, dampingRatio: 0.5))
                            }
                        }
                        .position(g.center(p.square))
                        .zIndex(Double(g.center(p.square).y) + (p.piece.color == .black ? 0 : 1000))
                }
            }
            .frame(width: boardSize, height: boardSize)
            .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
            seat("You", flipped: false)
        }
        .frame(width: size, height: size)
        .task(id: active) { await play() }
    }

    private func seat(_ label: String, flipped: Bool) -> some View {
        Text(label)
            .font(.system(size: max(12, size * 0.034), weight: .semibold))
            .foregroundStyle(theme.accent.opacity(0.9))
            .rotationEffect(flipped ? .degrees(180) : .zero)
    }

    private func play() async {
        guard active else { return }
        while !Task.isCancelled {
            for uci in Self.opening {
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled, let m = Move(uci: uci),
                      let i = pieces.firstIndex(where: { $0.square == m.from }) else { return }
                withAnimation(.timingCurve(0.3, 0.0, 0.2, 1, duration: 0.42)) { pieces[i].square = m.to }
                let id = pieces[i].id
                try? await Task.sleep(for: .seconds(0.4))
                landing[id, default: 0] += 1
                feedback.audio.play(.place, gain: 0.35)
            }
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { pieces = Self.start() }
        }
    }
}

/// Page two: the pieces themselves, on a pool of light, with a gleam passing over them.
struct CraftScene: View {
    let theme: BoardTheme
    let size: CGFloat
    let active: Bool

    @State private var gleam = false
    @State private var lifted = -1

    private let row: [Piece] = [Piece(.white, .pawn), Piece(.black, .knight), Piece(.white, .bishop),
                                Piece(.black, .rook), Piece(.white, .queen), Piece(.black, .king)]

    var body: some View {
        VStack(spacing: size * 0.02) {
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFE2A8).opacity(0.3), .clear], center: .center,
                                         startRadius: 0, endRadius: size * 0.36))
                    .frame(width: size * 0.9, height: size * 0.36)
                    .offset(y: size * 0.2)
                HStack(spacing: -size * 0.12) {
                    hero(Piece(.black, .queen), size: size * 0.5)
                        .offset(y: -size * 0.01)
                    hero(Piece(.white, .king), size: size * 0.6)
                        .zIndex(1)
                }
            }
            .frame(height: size * 0.62)
            HStack(spacing: size * 0.005) {
                ForEach(Array(row.enumerated()), id: \.offset) { i, p in
                    PieceBody(piece: p, size: size * 0.15, hold: lifted == i ? .held : .resting, rotated: false,
                              light: CGSize(width: Double(i - 3) * 0.1, height: 0.1), shadowStrength: 0.55)
                        .scaleEffect(lifted == i ? 1.1 : 1, anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                        .animation(Motion.pickup, value: lifted)
                }
            }
        }
        .frame(width: size, height: size)
        .task(id: active) {
            guard active else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: false)) { gleam = true }
            var i = 0
            while !Task.isCancelled {
                lifted = i % row.count
                try? await Task.sleep(for: .seconds(0.55))
                lifted = -1
                try? await Task.sleep(for: .seconds(0.15))
                i += 1
            }
        }
    }

    /// A large piece with a band of light sweeping across its surface.
    private func hero(_ piece: Piece, size s: CGFloat) -> some View {
        StandingPiece(piece: piece, size: s, shadow: 0.55)
            .overlay(
                LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: s * 0.3)
                    .rotationEffect(.degrees(18))
                    .offset(x: gleam ? s * 0.8 : -s * 0.8)
                    .blendMode(.plusLighter)
                    .mask(PieceGlyph(piece: piece).frame(width: s, height: s))
            )
    }
}
