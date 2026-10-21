import SwiftUI
import ChessCore

/// Learn: checkmate puzzles. Find the mate; the computer defends as well as it can in between.
/// Any move that keeps the forced mate counts, not only the one in the book.
struct PuzzleView: View {
    let pro: ProStore
    let feedback: FeedbackCoordinator
    let unlock: () -> Void
    let close: () -> Void

    @State private var set: Int = 1
    @State private var index: Int = 0
    @State private var position = Position.start
    @State private var tokens: [PieceToken] = []
    @State private var selection: Square?
    @State private var lastMove: Move?
    @State private var remaining = 1
    @State private var status: Status = .yourMove
    @State private var shown: Move?
    @State private var solved: Set<String> = PuzzleView.loadSolved()
    @State private var nextID = 0

    private enum Status: Equatable { case yourMove, thinking, wrong, solved }
    private let theme = BoardTheme.with(.house)
    /// Puzzles anyone can try; the rest come with 64 Pro.
    static let freeCount = 5

    private var puzzles: [Puzzle] { Puzzle.all.filter { $0.mateIn == set } }
    private var puzzle: Puzzle? { puzzles.indices.contains(index) ? puzzles[index] : nil }
    private var locked: Bool { !pro.isPro && !(set == 1 && index < Self.freeCount) }
    private var solver: PieceColor { Position(fen: puzzle?.fen ?? Position.startFEN)?.sideToMove ?? .white }

    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size
            let wide = s.width > s.height
            let tall = s.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
            let boardSize = floor(wide ? min(tall - 40, s.width * 0.6) : min(s.width - 32, tall - 300))
            ZStack {
                OnboardingBackdrop(theme: theme, page: 1)
                let layout = wide ? AnyLayout(HStackLayout(spacing: 32)) : AnyLayout(VStackLayout(spacing: 22))
                layout {
                    if !wide { header }
                    board(size: max(boardSize, 240))
                    VStack(alignment: .leading, spacing: 16) {
                        if wide { header }
                        prompt
                        controls
                    }
                    .frame(maxWidth: wide ? 360 : max(boardSize, 240))
                }
                .padding(.top, proxy.safeAreaInsets.top + 12)
                .padding(.bottom, proxy.safeAreaInsets.bottom + 12)
                .padding(.horizontal, 16)
            }
            .frame(width: s.width, height: s.height)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onAppear { load() }
        .onChange(of: set) { index = firstUnsolved(); load() }
        .onChange(of: index) { load() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("learn")
    }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    feedback.ui()
                    close()
                } label: {
                    Label("Home", systemImage: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.cream)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("learn-home")
                Spacer()
                Text("\(puzzles.filter { solved.contains($0.id) }.count) of \(puzzles.count) solved")
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Brand.cream.opacity(0.6))
            }
            Picker("Puzzles", selection: $set) {
                Text("Mate in 1").tag(1)
                Text("Mate in 2").tag(2)
                Text("Mate in 3").tag(3)
            }
            .pickerStyle(.segmented)
        }
    }

    private func board(size: CGFloat) -> some View {
        let g = BoardGeometry(size: size, flipped: solver == .black)
        return ZStack(alignment: .topLeading) {
            BoardSurface(theme: theme, geometry: g, showCoordinates: true, mirrorCoordinates: false)
            Canvas { ctx, _ in
                if let m = lastMove {
                    ctx.fill(Path(g.rect(m.from)), with: .color(theme.lastMove))
                    ctx.fill(Path(g.rect(m.to)), with: .color(theme.lastMove))
                }
                if let sel = selection {
                    ctx.fill(Path(g.rect(sel)), with: .color(theme.selection))
                    for m in position.legalMoves(from: sel) {
                        let c = g.center(m.to)
                        let r = g.square * 0.125
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(theme.hint))
                    }
                }
                if let shown { BoardMarks.arrow(ctx, g: g, move: shown, color: Color(hex: 0xD4AF66)) }
            }
            .frame(width: size, height: size)
            ForEach(tokens) { token in
                PieceBody(piece: token.piece, size: g.square, hold: token.square == selection ? .selected : .resting,
                          rotated: false, light: .zero, shadowStrength: theme.pieceShadow)
                    .opacity(token.isCaptured ? 0 : 1)
                    .position(g.center(token.square))
                    .zIndex(Double(g.center(token.square).y))
                    .animation(.timingCurve(0.3, 0, 0.2, 1, duration: 0.32), value: token.square)
                    .animation(.easeOut(duration: 0.2), value: token.isCaptured)
            }
            if locked {
                RoundedRectangle(cornerRadius: 4).fill(.ultraThinMaterial)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill").font(.system(size: 28))
                            Text("All puzzles come with 64 Pro")
                                .font(.system(size: 17, weight: .semibold))
                            Button {
                                feedback.ui()
                                unlock()
                            } label: {
                                Text(pro.trialAvailable ? "Try it free for a week" : "See plans")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Brand.brown)
                                    .padding(.horizontal, 20)
                                    .frame(height: 44)
                                    .background(GoldCapsule())
                            }
                            .buttonStyle(PressScaleStyle())
                        }
                        .foregroundStyle(Brand.cream)
                    }
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { tap(at: $0.location, g) })
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
        .accessibilityElement()
        .accessibilityIdentifier("puzzle-board")
        .accessibilityLabel("Puzzle board")
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headline)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(status == .wrong ? theme.check : Brand.cream)
            Text(detail)
                .font(.system(size: 15))
                .foregroundStyle(Brand.cream.opacity(0.7))
        }
        .animation(.easeInOut(duration: 0.2), value: status)
    }

    private var headline: String {
        switch status {
        case .solved: return "Solved"
        case .wrong: return "Not that one"
        case .thinking: return "…"
        case .yourMove: return "\(solver == .white ? "White" : "Black") to move"
        }
    }

    private var detail: String {
        switch status {
        case .solved: return "Checkmate. On to the next."
        case .wrong: return "That lets the king escape. The pieces are back; try again."
        case .thinking: return "The defence replies."
        case .yourMove: return remaining == 1 ? "Find the checkmate." : "Checkmate in \(remaining) moves."
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            button("Previous", symbol: "chevron.left", enabled: index > 0) { index -= 1 }
            button(shown == nil ? "Show me" : "Hide", symbol: "lightbulb", enabled: status == .yourMove && !locked) {
                if shown != nil { shown = nil; return }
                let p = position
                Task {
                    let e = await Task.detached { Engine.evaluate(p, seconds: 0.4) }.value
                    shown = e.best
                }
            }
            button("Next", symbol: "chevron.right", enabled: index < puzzles.count - 1) { index += 1 }
        }
    }

    private func button(_ title: String, symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            feedback.ui()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Brand.cream)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.22)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(theme.accent.opacity(0.35), lineWidth: 0.75))
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    // MARK: Play

    private func load() {
        guard let puzzle, let p = Position(fen: puzzle.fen) else { return }
        position = p
        nextID = 0
        tokens = TokenLayout.tokens(for: p, nextID: &nextID)
        selection = nil
        lastMove = nil
        shown = nil
        remaining = puzzle.mateIn
        status = .yourMove
    }

    private func firstUnsolved() -> Int {
        puzzles.firstIndex { !solved.contains($0.id) } ?? 0
    }

    private func tap(at point: CGPoint, _ g: BoardGeometry) {
        guard !locked, status == .yourMove || status == .wrong, let sq = g.square(at: point) else { return }
        if let from = selection {
            if let m = position.legalMoves(from: from).first(where: { $0.to == sq && ($0.promotion == nil || $0.promotion == .queen) }) {
                selection = nil
                play(m)
                return
            }
            selection = nil
        }
        if position[sq]?.color == position.sideToMove {
            selection = sq
            status = .yourMove
            feedback.audio.play(.pickup, gain: 0.6)
        }
    }

    private func apply(_ m: Move) {
        guard let fx = position.effect(of: m) else { return }
        TokenLayout.apply(fx, to: &tokens)
        feedback.audio.play(fx.isCapture ? .capture : .place, delay: 0.25)
        position = position.applying(m) ?? position
        lastMove = m
    }

    private func play(_ m: Move) {
        shown = nil
        let before = (position, tokens, lastMove)
        apply(m)
        if position.legalMoves().isEmpty && position.isInCheck {
            finish()
            return
        }
        status = .thinking
        let p = position
        let left = remaining
        Task {
            let e = await Task.detached { Engine.evaluate(p, seconds: 0.35) }.value
            // The defender is mated within the moves that are left: the move keeps the mate.
            if let mate = e.mateIn, mate < 0, -mate <= left - 1, let reply = e.best {
                try? await Task.sleep(for: .seconds(0.45))
                remaining = left - 1
                apply(reply)
                status = .yourMove
            } else {
                status = .wrong
                feedback.invalid(at: m.to)
                try? await Task.sleep(for: .seconds(0.7))
                (position, tokens, lastMove) = before
            }
        }
    }

    private func finish() {
        status = .solved
        if let puzzle {
            solved.insert(puzzle.id)
            UserDefaults.standard.set(Array(solved), forKey: "puzzle.solved")
        }
        feedback.audio.play(.checkmate, delay: 0.3, gain: 0.7)
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if status == .solved, index < puzzles.count - 1 { index += 1 }
        }
    }

    private static func loadSolved() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "puzzle.solved") ?? [])
    }
}
