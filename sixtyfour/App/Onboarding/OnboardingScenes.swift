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

/// Page two, hands-on: a corner of the board with a knight to pick up. Tap it and then a
/// glowing square, or drag it there, and hear it land. Any of its three moves counts.
struct KnightScene: View {
    let theme: BoardTheme
    let size: CGFloat
    let active: Bool
    let feedback: FeedbackCoordinator
    /// Called once, when the knight has landed.
    let landed: () -> Void

    @State private var knight = Square(file: 6, rank: 0)          // g1
    @State private var selected = false
    @State private var drag: CGSize = .zero
    @State private var dragging = false
    @State private var landing = 0
    @State private var done = false
    @State private var pulse = false

    private static let targets = [Square(file: 5, rank: 2), Square(file: 7, rank: 2), Square(file: 4, rank: 1)]   // f3, h3, e2
    private static let others: [(Square, Piece)] = [
        (Square(file: 4, rank: 0), Piece(.white, .king)), (Square(file: 7, rank: 0), Piece(.white, .rook)),
        (Square(file: 5, rank: 1), Piece(.white, .pawn)), (Square(file: 6, rank: 1), Piece(.white, .pawn)),
        (Square(file: 7, rank: 1), Piece(.white, .pawn)), (Square(file: 5, rank: 0), Piece(.white, .bishop)),
    ]

    var body: some View {
        // The board at twice the scene's size, showing only its bottom-right quarter (e1 to h4).
        let g = BoardGeometry(size: size * 2)
        let at = { (sq: Square) -> CGPoint in
            let c = g.center(sq)
            return CGPoint(x: c.x - size, y: c.y - size)
        }
        ZStack(alignment: .topLeading) {
            BoardSurface(theme: theme, geometry: g, showCoordinates: true, mirrorCoordinates: false)
                .frame(width: size * 2, height: size * 2)
                .offset(x: -size, y: -size)
            if !done {
                ForEach(Self.targets, id: \.self) { t in
                    Circle()
                        .fill(theme.hint)
                        .frame(width: g.square * 0.3, height: g.square * 0.3)
                        .overlay(Circle().strokeBorder(theme.accent.opacity(0.8), lineWidth: 2)
                            .frame(width: g.square * (pulse ? 0.8 : 0.5), height: g.square * (pulse ? 0.8 : 0.5))
                            .opacity(pulse ? 0 : 0.9))
                        .position(at(t))
                        .opacity(selected || dragging ? 1 : 0.55)
                }
            }
            if landing > 0 {
                LandingRing(color: theme.turnGlow, size: g.square)
                    .position(at(knight))
                    .id(landing)
            }
            ForEach(Self.others.indices, id: \.self) { i in
                PieceBody(piece: Self.others[i].1, size: g.square, hold: .resting, rotated: false, light: .zero,
                          shadowStrength: theme.pieceShadow)
                    .position(at(Self.others[i].0))
                    .zIndex(Double(at(Self.others[i].0).y))
            }
            PieceBody(piece: Piece(.white, .knight), size: g.square, hold: dragging ? .dragging : (selected ? .held : .resting),
                      rotated: false, light: .zero, shadowStrength: theme.pieceShadow)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: landing) { content, squash in
                    content.scaleEffect(x: 2 - squash, y: squash, anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(0.9, duration: 0.05)
                        SpringKeyframe(1.0, duration: 0.32, spring: Spring(response: 0.26, dampingRatio: 0.5))
                    }
                }
                .scaleEffect(dragging ? 1.16 : (selected ? 1.1 : 1), anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                .offset(x: drag.width, y: drag.height - (dragging ? g.square * 0.34 : 0))
                .position(at(knight))
                .zIndex(10_000)
                .animation(Motion.pickup, value: selected)
                .gesture(knightDrag(g, at: at))
                .onTapGesture { tapKnight() }
                .accessibilityElement()
                .accessibilityLabel("Knight")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("onboarding-knight")
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.04, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { location in
            guard selected, let sq = square(at: location, g) else { return }
            if Self.targets.contains(sq) { move(to: sq) } else { selected = false }
        }
        .shadow(color: .black.opacity(0.55), radius: 26, y: 14)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private func square(at p: CGPoint, _ g: BoardGeometry) -> Square? {
        g.square(at: CGPoint(x: p.x + size, y: p.y + size))
    }

    private func tapKnight() {
        guard !done else { return }
        selected.toggle()
        if selected { feedback.pickup(at: knight) }
    }

    private func knightDrag(_ g: BoardGeometry, at: @escaping (Square) -> CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                guard !done else { return }
                if !dragging {
                    dragging = true
                    if !selected { feedback.pickup(at: knight) }
                }
                drag = v.translation
            }
            .onEnded { v in
                guard !done else { return }
                let c = at(knight)
                let drop = CGPoint(x: c.x + v.translation.width, y: c.y + v.translation.height - g.square * 0.34)
                dragging = false
                if let sq = square(at: drop, g), Self.targets.contains(sq) {
                    drag = .zero
                    move(to: sq, dropped: true)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { drag = .zero }
                    selected = false
                    feedback.invalid(at: knight)
                }
            }
    }

    private func move(to sq: Square, dropped: Bool = false) {
        selected = false
        done = true
        let flight = dropped ? 0.0 : 0.38
        withAnimation(dropped ? .easeOut(duration: 0.08) : .timingCurve(0.3, 0, 0.2, 1, duration: flight)) { knight = sq }
        DispatchQueue.main.asyncAfter(deadline: .now() + flight * 0.86 + 0.02) {
            feedback.audio.play(.place, gain: 1)
            feedback.haptics.place(after: 0, weight: 0.8)
            landing += 1
            landed()
        }
    }
}

/// A ring of light running out from where a piece lands.
private struct LandingRing: View {
    let color: Color
    let size: CGFloat
    @State private var open = false

    var body: some View {
        Circle()
            .strokeBorder(color.opacity(0.85), lineWidth: 2.5)
            .frame(width: size, height: size)
            .scaleEffect(open ? 1.5 : 0.4)
            .opacity(open ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeOut(duration: 0.7)) { open = true } }
    }
}
