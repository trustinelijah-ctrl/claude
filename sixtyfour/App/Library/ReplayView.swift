import SwiftUI
import ChessCore

/// A finished game played back on its own board: step through it, scrub, or let it play
/// itself with the sound of every move. With 64 Pro, the engine reviews it move by move.
struct ReplayView: View {
    let saved: SavedGame
    let theme: BoardTheme
    let feedback: FeedbackCoordinator
    let pro: ProStore
    var unlock: () -> Void = {}
    let close: () -> Void

    @State private var review: GameReview?
    @State private var reviewProgress: Double?

    /// Every position of the game as tokens, so pieces glide from frame to frame.
    private let frames: [[PieceToken]]
    @State private var index: Int
    @State private var playing = false

    init(saved: SavedGame, theme: BoardTheme, feedback: FeedbackCoordinator, pro: ProStore,
         unlock: @escaping () -> Void = {}, close: @escaping () -> Void) {
        self.saved = saved
        self.theme = theme
        self.feedback = feedback
        self.pro = pro
        self.unlock = unlock
        self.close = close
        var nextID = 0
        var tokens = TokenLayout.tokens(for: saved.game.initialPosition, nextID: &nextID)
        var frames = [tokens]
        for played in saved.game.history {
            TokenLayout.apply(played.effect, to: &tokens)
            frames.append(tokens)
        }
        self.frames = frames
        _index = State(initialValue: 0)
    }

    private var history: [PlayedMove] { saved.game.history }
    private var flipped: Bool { saved.humanColor == .black }

    var body: some View {
        GeometryReader { proxy in
            content(size: proxy.size, safe: proxy.safeAreaInsets)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .task(id: playing) {
            guard playing else { return }
            if index >= frames.count - 1 { go(to: 0) ; try? await Task.sleep(for: .seconds(0.6)) }
            while playing && !Task.isCancelled && index < frames.count - 1 {
                go(to: index + 1)
                try? await Task.sleep(for: .seconds(0.95))
            }
            playing = false
        }
        .task {
            // Pro reviews start straight away; the board is usable while it runs.
            if pro.isPro { await startReview() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("replay")
    }

    private func startReview() async {
        guard review == nil, reviewProgress == nil, !history.isEmpty else { return }
        reviewProgress = 0
        let result = await GameReview.run(saved.game) { p in reviewProgress = p }
        withAnimation(.easeInOut(duration: 0.3)) {
            review = result
            reviewProgress = nil
        }
    }

    /// The review: a button until it runs, progress while it runs, then the balance and a verdict.
    @ViewBuilder
    private var reviewPanel: some View {
        if let review {
            VStack(alignment: .leading, spacing: 10) {
                BalanceGraph(balance: review.balance, moves: review.moves, index: index, theme: theme) { i in
                    playing = false
                    go(to: i, quiet: true)
                }
                .frame(height: 64)
                HStack(alignment: .firstTextBaseline) {
                    verdict(review)
                    Spacer()
                    if let w = review.accuracy[.white], let b = review.accuracy[.black] {
                        Text("Accuracy  White \(w) · Black \(b)")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(theme.inkSecondary)
                    }
                }
            }
        } else if let p = reviewProgress {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: p).tint(theme.accent)
                Text("Reviewing the game…")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.inkSecondary)
            }
        } else if !history.isEmpty {
            Button {
                feedback.ui()
                if pro.isPro { Task { await startReview() } } else { unlock() }
            } label: {
                Label(pro.isPro ? "Review this game" : "Review this game with 64 Pro",
                      systemImage: pro.isPro ? "magnifyingglass" : "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Brand.brown)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(GoldCapsule())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("review-game")
        }
    }

    @ViewBuilder
    private func verdict(_ review: GameReview) -> some View {
        if index > 0, index - 1 < review.moves.count {
            let m = review.moves[index - 1]
            let san = history[index - 1].san
            VStack(alignment: .leading, spacing: 2) {
                Text("\(san): \(m.grade.word.lowercased())")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(m.grade.color)
                if let better = m.betterSAN {
                    Text("Better was \(better)")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.ink.opacity(0.75))
                }
            }
        } else {
            Text("Step through to see each move judged.")
                .font(.system(size: 13))
                .foregroundStyle(theme.inkSecondary)
        }
    }

    // MARK: Parts

    private func content(size s: CGSize, safe: EdgeInsets) -> some View {
        let wide = s.width > s.height
        let boardSize = boardSide(size: s, safe: safe, wide: wide)
        let layout: AnyLayout = wide ? AnyLayout(HStackLayout(spacing: 32)) : AnyLayout(VStackLayout(spacing: 20))
        return ZStack {
            OnboardingBackdrop(theme: theme, page: 1)
            layout {
                if !wide { header }
                board(size: boardSize)
                sidePanel(wide: wide)
            }
            .padding(.top, safe.top + 12)
            .padding(.bottom, safe.bottom + 12)
            .padding(.horizontal, 16)
        }
        .frame(width: s.width, height: s.height)
    }

    private func boardSide(size s: CGSize, safe: EdgeInsets, wide: Bool) -> CGFloat {
        let tall = s.height - safe.top - safe.bottom
        let side: CGFloat = wide ? min(tall - 40, s.width * 0.6) : min(s.width - 32, tall - 330)
        return floor(max(side, 200))
    }

    private func sidePanel(wide: Bool) -> some View {
        VStack(spacing: 18) {
            if wide { header }
            reviewPanel
            moveList
            controls
        }
        .frame(maxWidth: wide ? 360 : 640)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(saved.game.result.map(ResultText.headline) ?? "Unfinished")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text("\(saved.opponentTitle) · \(saved.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.ink.opacity(0.6))
            }
            Spacer()
            if pro.isPro {
                ShareLink(item: PGN.text(for: saved), preview: SharePreview("64 game.pgn")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .accessibilityLabel("Share PGN")
            }
            Button {
                feedback.ui()
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Close")
        }
    }

    private func board(size: CGFloat) -> some View {
        let g = BoardGeometry(size: size, flipped: flipped)
        let last = index > 0 ? history[index - 1].effect.move : nil
        return ZStack(alignment: .topLeading) {
            BoardSurface(theme: theme, geometry: g, showCoordinates: true, mirrorCoordinates: false)
            if let last {
                ForEach([last.from, last.to], id: \.self) { sq in
                    Rectangle().fill(theme.lastMove)
                        .frame(width: g.square, height: g.square)
                        .position(g.center(sq))
                }
            }
            if let review, index > 0, index - 1 < review.moves.count, let better = review.moves[index - 1].better {
                Canvas { ctx, _ in BoardMarks.arrow(ctx, g: g, move: better, color: Color(hex: 0x9CC27A)) }
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)
                    .zIndex(100)
            }
            ForEach(frames[index]) { token in
                PieceBody(piece: token.piece, size: g.square, hold: .resting, rotated: false,
                          light: .zero, shadowStrength: theme.pieceShadow)
                    .opacity(token.isCaptured ? 0 : 1)
                    .scaleEffect(token.isCaptured ? 0.6 : 1)
                    .position(g.center(token.square))
                    .zIndex(Double(g.center(token.square).y))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.6), radius: 30, y: 14)
        .accessibilityElement()
        .accessibilityLabel("Replay board")
        .accessibilityValue(index == 0 ? "Starting position" : "After \(history[index - 1].san)")
    }

    private var moveList: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(history.enumerated()), id: \.offset) { i, played in
                        Button {
                            playing = false
                            go(to: i + 1)
                        } label: {
                            HStack(spacing: 3) {
                                if i % 2 == 0 {
                                    Text("\(i / 2 + 1).").foregroundStyle(theme.ink.opacity(0.45))
                                }
                                Text(played.san)
                                if let grade = review?.moves[i].grade, !grade.mark.isEmpty {
                                    Text(grade.mark).foregroundStyle(i + 1 == index ? Color(hex: 0x2A1D0A) : grade.color)
                                }
                            }
                            .font(.system(size: 15, weight: i + 1 == index ? .bold : .regular))
                            .foregroundStyle(i + 1 == index ? Color(hex: 0x2A1D0A) : theme.ink)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(Capsule().fill(i + 1 == index ? theme.accent : .white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: index) {
                withAnimation(.easeInOut(duration: 0.3)) { reader.scrollTo(max(0, index - 1), anchor: .center) }
            }
        }
        .frame(height: 40)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            Slider(value: Binding(get: { Double(index) },
                                  set: { playing = false; go(to: Int($0.rounded()), quiet: true) }),
                   in: 0...Double(max(frames.count - 1, 1)), step: 1)
                .tint(theme.accent)
                .disabled(frames.count < 2)
            HStack(spacing: 22) {
                control("backward.end.fill", "Start") { go(to: 0) }
                control("backward.fill", "Back") { go(to: index - 1) }
                Button {
                    feedback.ui()
                    playing.toggle()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: 0x2A1D0A))
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(LinearGradient(colors: [Color(hex: 0xF7E6B4), Color(hex: 0xD4AF66), Color(hex: 0xA27A3A)],
                                                                 startPoint: .top, endPoint: .bottom)))
                        .shadow(color: Color(hex: 0xD4AF66).opacity(0.4), radius: 12, y: 3)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(playing ? "Pause" : "Play")
                control("forward.fill", "Forward") { go(to: index + 1) }
                control("forward.end.fill", "End") { go(to: frames.count - 1) }
            }
            Text("Move \((index + 1) / 2) of \((history.count + 1) / 2)")
                .font(.system(size: 14))
                .foregroundStyle(theme.ink.opacity(0.6))
                .monospacedDigit()
        }
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button {
            playing = false
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.ink)
                .frame(width: 48, height: 48)
                .background(Circle().fill(.white.opacity(0.08)))
                .overlay(Circle().strokeBorder(theme.accent.opacity(0.3), lineWidth: 0.6))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }

    private func go(to target: Int, quiet: Bool = false) {
        let next = min(max(target, 0), frames.count - 1)
        guard next != index else { return }
        let forward = next == index + 1
        withAnimation(.timingCurve(0.3, 0, 0.2, 1, duration: forward ? 0.42 : 0.3)) { index = next }
        if !quiet && next > 0 {
            let played = history[next - 1]
            feedback.audio.play(played.effect.isCapture ? .capture : .place, delay: forward ? 0.36 : 0, gain: 0.8)
        }
    }
}
