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
            seat("Across the table", flipped: true)
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
            .font(Typeface.italic(size * 0.042))
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
            Text("32 PIECES · MODELLED · LIT · RENDERED IN-HOUSE")
                .font(.system(size: max(9, size * 0.024), weight: .semibold))
                .tracking(2)
                .foregroundStyle(theme.accent.opacity(0.75))
                .padding(.top, size * 0.03)
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

/// Page three: a knight picked up, carried, and set down: the lift, the shadow, the landing.
struct FeelScene: View {
    let theme: BoardTheme
    let size: CGFloat
    let active: Bool
    let feedback: FeedbackCoordinator

    @State private var at = CGPoint(x: 0, y: 2)
    @State private var hold: HoldState = .resting
    @State private var landed = 0

    var body: some View {
        let sq = size / 3
        let center = CGPoint(x: (at.x + 0.5) * sq, y: (at.y + 0.5) * sq)
        ZStack(alignment: .topLeading) {
            // A three-by-three corner of the board, a1 to c3.
            Image(theme.surfaceImage)
                .resizable()
                .interpolation(.high)
                .frame(width: size * 8 / 3, height: size * 8 / 3)
                .frame(width: size, height: size, alignment: .bottomLeading)
                .clipped()
            // The landing ripples and the knock, spreading from where it lands.
            ForEach(0..<3, id: \.self) { k in
                Circle()
                    .strokeBorder(theme.accent, lineWidth: 1.5)
                    .frame(width: sq, height: sq)
                    .keyframeAnimator(initialValue: CGFloat(0), trigger: landed) { content, t in
                        content.scaleEffect(0.6 + t * (1.2 + CGFloat(k) * 0.5)).opacity(t == 0 ? 0 : Double(1 - t) * 0.8)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(0.001, duration: 0.01)
                            CubicKeyframe(1, duration: 0.7 + Double(k) * 0.15)
                            LinearKeyframe(0, duration: 0.01)
                        }
                    }
                    .position(x: center.x, y: center.y + sq * 0.2)
            }
            PieceBody(piece: Piece(.white, .knight), size: sq, hold: hold, rotated: false,
                      light: CGSize(width: (at.x - 1) * 0.2, height: (at.y - 1) * 0.2), shadowStrength: theme.pieceShadow)
                .scaleEffect(hold == .resting ? 1 : 1.14, anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                .animation(Motion.pickup, value: hold)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: landed) { content, squash in
                    content.scaleEffect(x: 2 - squash, y: squash, anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(0.9, duration: 0.05)
                        SpringKeyframe(1.0, duration: 0.34, spring: Spring(response: 0.26, dampingRatio: 0.45))
                    }
                }
                .position(center)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.04, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
            .strokeBorder(theme.inlay.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
        .task(id: active) {
            guard active else { return }
            var forward = true
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.9))
                guard !Task.isCancelled else { return }
                hold = .held
                feedback.audio.play(.pickup, gain: 0.6)
                try? await Task.sleep(for: .seconds(0.3))
                hold = .dragging
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    at = forward ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: 2)
                }
                try? await Task.sleep(for: .seconds(0.55))
                hold = .resting
                landed += 1
                feedback.audio.play(.place, gain: 0.8)
                feedback.haptics.place(after: 0)
                forward.toggle()
            }
        }
    }
}

/// Page four: TABLE's own pieces moving by themselves, as if carried by an unseen hand.
struct GhostScene: View {
    let theme: BoardTheme
    let size: CGFloat
    let active: Bool

    @State private var at = CGPoint(x: 1, y: 0)
    @State private var carried = false
    @State private var thinking = false
    @State private var landed = 0

    var body: some View {
        let sq = size * 0.84 / 3
        let center = CGPoint(x: (at.x + 0.5) * sq, y: (at.y + 0.5) * sq)
        VStack(spacing: size * 0.04) {
            HStack(spacing: 12) {
                Text("TABLE")
                    .font(Typeface.display(size * 0.06))
                    .tracking(6)
                    .foregroundStyle(theme.accent)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(theme.accent).frame(width: 6, height: 6)
                            .opacity(thinking ? 1 : 0.2)
                            .animation(thinking ? .easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.15) : .default,
                                       value: thinking)
                    }
                }
            }
            ZStack(alignment: .topLeading) {
                // The top corner of the board, f8 to h6, where TABLE's pieces wait.
                Image(theme.surfaceImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: sq * 8, height: sq * 8)
                    .frame(width: sq * 3, height: sq * 3, alignment: .topTrailing)
                    .clipped()
                PieceBody(piece: Piece(.black, .pawn), size: sq, hold: .resting, rotated: false,
                          light: .zero, shadowStrength: theme.pieceShadow)
                    .position(x: 2.5 * sq, y: 1.5 * sq)
                // A faint glow under the piece while the unseen hand carries it.
                Circle()
                    .fill(RadialGradient(colors: [theme.accent.opacity(0.45), .clear], center: .center,
                                         startRadius: 0, endRadius: sq * 0.5))
                    .frame(width: sq, height: sq)
                    .opacity(carried ? 1 : 0)
                    .position(x: center.x, y: center.y + sq * 0.2)
                PieceBody(piece: Piece(.black, .knight), size: sq, hold: carried ? .carried : .resting, rotated: false,
                          light: .zero, shadowStrength: theme.pieceShadow)
                    .scaleEffect(carried ? 1.12 : 1, anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                    .opacity(carried ? 0.78 : 1)
                    .animation(Motion.pickup, value: carried)
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: landed) { content, squash in
                        content.scaleEffect(x: 2 - squash, y: squash, anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(0.92, duration: 0.05)
                            SpringKeyframe(1.0, duration: 0.3, spring: Spring(response: 0.26, dampingRatio: 0.5))
                        }
                    }
                    .position(center)
            }
            .frame(width: sq * 3, height: sq * 3)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.035, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.035, style: .continuous)
                .strokeBorder(theme.inlay.opacity(0.7), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
            HStack(spacing: 8) {
                ForEach(BotLevel.allCases) { level in
                    HStack(spacing: 4) {
                        Text(level.title)
                        if level.isPro {
                            Text("PRO").font(.system(size: 9, weight: .heavy)).foregroundStyle(theme.accent)
                        }
                    }
                    .font(.system(size: max(10, size * 0.028), weight: .semibold))
                    .foregroundStyle(theme.ink.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(Capsule().strokeBorder(theme.accent.opacity(0.4), lineWidth: 0.75))
                }
            }
        }
        .frame(width: size, height: size)
        .task(id: active) {
            guard active else { return }
            var forward = true
            while !Task.isCancelled {
                thinking = true
                try? await Task.sleep(for: .seconds(1.3))
                guard !Task.isCancelled else { return }
                thinking = false
                carried = true
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.timingCurve(0.35, 0, 0.2, 1, duration: 0.8)) {
                    at = forward ? CGPoint(x: 0, y: 2) : CGPoint(x: 1, y: 0)
                }
                try? await Task.sleep(for: .seconds(0.8))
                carried = false
                landed += 1
                forward.toggle()
                try? await Task.sleep(for: .seconds(0.6))
            }
        }
    }
}

/// The last page's crest: the two kings under the lamp, with the name in gold.
struct WelcomeCrest: View {
    let theme: BoardTheme
    let active: Bool

    @State private var glow = false

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFE2A8).opacity(0.35), .clear], center: .center,
                                         startRadius: 0, endRadius: h * 0.6))
                    .frame(width: h * 1.4, height: h * 1.4)
                    .scaleEffect(glow ? 1.06 : 0.94)
                HStack(spacing: -h * 0.26) {
                    StandingPiece(piece: Piece(.white, .king), size: h * 0.9, shadow: 0.5)
                    StandingPiece(piece: Piece(.black, .king), size: h * 0.9, shadow: 0.5)
                        .scaleEffect(x: -1)
                }
            }
            .frame(width: proxy.size.width, height: h)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever()) { glow = true }
        }
        .accessibilityHidden(true)
    }
}
