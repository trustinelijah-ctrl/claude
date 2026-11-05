import SwiftUI
import ChessCore

/// Free play: no rules, no opponent, no clock. Pick up any piece, set it down anywhere,
/// knock another off the board, and listen. The board as a thing to touch.
struct SandboxView: View {
    let settings: SettingsStore
    let feedback: FeedbackCoordinator
    let close: () -> Void

    @State private var tokens: [PieceToken] = {
        var id = 0
        return TokenLayout.tokens(for: .start, nextID: &id)
    }()
    @State private var nextID = 64
    @State private var held: Int?
    @State private var origin: Square?
    @State private var drag: CGSize = .zero
    @State private var hover: Square?
    @State private var selected: Int?
    @State private var ripples: [Ripple] = []
    @State private var rippleID = 0
    @State private var resetWave = 0

    private var theme: BoardTheme { settings.theme }

    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size
            let safe = proxy.safeAreaInsets
            let boardSize = floor(min(s.width - 24, s.height - safe.top - safe.bottom - 210))
            ZStack {
                OnboardingBackdrop(theme: theme, page: 1)
                VStack(spacing: 18) {
                    header
                    board(size: boardSize)
                    controls
                }
                .padding(.top, safe.top + 12)
                .padding(.bottom, safe.bottom + 12)
            }
            .frame(width: s.width, height: s.height)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sandbox")
    }

    // MARK: Parts

    private var header: some View {
        VStack(spacing: 6) {
            Text("Free play")
                .font(Typeface.display(30, bold: true))
                .foregroundStyle(Brand.cream)
            Text("No rules. Just the pieces and the sound they make.")
                .font(Typeface.voice(16))
                .foregroundStyle(Brand.cream.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            pill("Home", symbol: "house.fill") { close() }
            pill("Set up again", symbol: "arrow.counterclockwise") { setUp() }
        }
    }

    private func pill(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            feedback.ui()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Brand.cream)
                .padding(.horizontal, 18)
                .frame(minHeight: 46)
                .background(Capsule().fill(Color.black.opacity(0.32)))
                .overlay(Capsule().strokeBorder(theme.accent.opacity(0.45), lineWidth: 0.75))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func board(size: CGFloat) -> some View {
        let g = BoardGeometry(size: size)
        return ZStack(alignment: .topLeading) {
            BoardSurface(theme: theme, geometry: g, showCoordinates: false, mirrorCoordinates: false)
            BoardGloss(size: size)
            if let hover, held != nil {
                Rectangle().fill(theme.selection).frame(width: g.square, height: g.square)
                    .position(g.center(hover))
            }
            RippleLayer(ripples: ripples, geometry: g, theme: theme)
            ForEach(tokens) { token in
                let isHeld = token.id == held
                let lift = isHeld ? g.liftOffset(for: .white) : .zero
                let p = g.center(token.square)
                PieceBody(piece: token.piece, size: g.square,
                          hold: isHeld ? .dragging : (token.id == selected ? .selected : .resting),
                          rotated: false,
                          light: CGSize(width: (p.x - size / 2) / size, height: (p.y - size / 2) / size),
                          shadowStrength: theme.pieceShadow)
                    .scaleEffect(isHeld ? 1.14 : 1, anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: token.landing) { content, squash in
                        content.scaleEffect(x: 2 - squash, y: squash, anchor: UnitPoint(x: 0.5, y: PieceSprite.squareBase))
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(0.92, duration: 0.05)
                            SpringKeyframe(1.0, duration: 0.32, spring: Spring(response: 0.26, dampingRatio: 0.5))
                        }
                    }
                    .offset(x: isHeld ? drag.width + lift.width : 0, y: isHeld ? drag.height + lift.height : 0)
                    .position(p)
                    .zIndex(isHeld ? 10_000 : Double(p.y))
                    .animation(.spring(response: 0.34, dampingFraction: 0.78)
                        .delay(resetWave > 0 ? Double(7 - token.square.rank) * 0.05 : 0), value: token.square)
                    .animation(Motion.pickup, value: isHeld)
                    .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.6).combined(with: .opacity)))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.55), radius: 26, y: 12)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { changed($0, g) }
            .onEnded { ended($0, g) })
        .accessibilityElement()
        .accessibilityLabel("Free play board")
        .accessibilityIdentifier("sandbox-board")
    }

    // MARK: Touch

    private func changed(_ v: DragGesture.Value, _ g: BoardGeometry) {
        if held == nil && origin == nil {
            guard let sq = g.square(at: v.startLocation), let t = tokens.first(where: { $0.square == sq }) else { return }
            origin = sq
            if hypot(v.translation.width, v.translation.height) < 6 { return }
            pick(t, at: sq)
        }
        guard let origin else { return }
        if held == nil, hypot(v.translation.width, v.translation.height) >= 6,
           let t = tokens.first(where: { $0.square == origin }) {
            pick(t, at: origin)
        }
        guard held != nil else { return }
        drag = v.translation
        let c = g.center(origin)
        let lift = g.liftOffset(for: .white)
        let now = g.square(at: CGPoint(x: c.x + drag.width + lift.width, y: c.y + drag.height + lift.height))
        if let now, now != hover, hover != nil || now != origin { feedback.crossed(now) }
        hover = now
    }

    private func pick(_ t: PieceToken, at sq: Square) {
        held = t.id
        selected = nil
        feedback.pickup(at: sq)
    }

    private func ended(_ v: DragGesture.Value, _ g: BoardGeometry) {
        defer { origin = nil; hover = nil }
        if let id = held, let i = tokens.firstIndex(where: { $0.id == id }) {
            let target = hover ?? tokens[i].square
            place(i, on: target)
            return
        }
        // A tap: choose a piece, or send the chosen one to the tapped square.
        guard let sq = g.square(at: v.location) else { return }
        if let sel = selected, let i = tokens.firstIndex(where: { $0.id == sel }) {
            selected = nil
            if tokens[i].square != sq { place(i, on: sq) }
        } else if let t = tokens.first(where: { $0.square == sq }) {
            selected = t.id
            feedback.pickup(at: sq)
        }
    }

    private func place(_ i: Int, on target: Square) {
        let token = tokens[i]
        let moved = token.square != target
        var landing: TimeInterval = 0.14
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            if moved, let j = tokens.firstIndex(where: { $0.square == target && $0.id != token.id }) {
                tokens.remove(at: j)
                feedback.audio.play(.capture, delay: 0.1)
                feedback.haptics.capture(after: 0.1)
                ripple(at: target, .capture, weight: 0.9)
                landing = 0.1
            }
            if let k = tokens.firstIndex(where: { $0.id == token.id }) {
                tokens[k].square = target
                tokens[k].landing += 1
            }
            held = nil
            drag = .zero
        }
        guard moved else {
            feedback.putBack(at: target)
            return
        }
        let kind = token.piece.kind
        if landing > 0.1 {
            feedback.audio.play(FeedbackCoordinator.placement(for: kind), delay: landing)
            feedback.haptics.place(after: landing, weight: FeedbackCoordinator.weight(of: kind))
            ripple(at: target, .land, weight: FeedbackCoordinator.weight(of: kind))
        }
    }

    private func ripple(at sq: Square, _ style: Ripple.Style, weight: Float) {
        rippleID += 1
        let r = Ripple(id: rippleID, square: sq, style: style, delay: 0, weight: weight)
        ripples.append(r)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { ripples.removeAll { $0.id == r.id } }
    }

    /// Every piece goes home, the back ranks first, with a run of small clicks.
    private func setUp() {
        resetWave += 1
        selected = nil
        withAnimation {
            tokens = TokenLayout.regather(tokens, into: .start, nextID: &nextID)
        }
        feedback.newGame()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { resetWave = 0 }
    }
}
