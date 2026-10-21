import SwiftUI
import Observation
import ChessCore

struct PendingPromotion: Equatable {
    let from: Square
    let to: Square
    let color: PieceColor
    let tokenID: Int
}

enum DropOutcome {
    case moved, promotion, rejected, unchanged
}

/// A brief ring of light where something happened on the board.
struct Ripple: Identifiable, Equatable {
    enum Style { case pickup, land, capture }
    let id: Int
    let square: Square
    let style: Style
    let delay: Double
}

/// The game at the table: rules state, the physical pieces, selection, the computer
/// opponent, and the timing of everything that happens when a move is made.
@MainActor
@Observable
final class GameSession {
    private(set) var game: ChessGame
    private(set) var tokens: [PieceToken] = []
    private var snapshots: [[PieceToken]] = []
    private var nextID = 0

    private(set) var selection: Square?
    private(set) var targets: [Square: [Move]] = [:]
    private(set) var pendingPromotion: PendingPromotion?
    /// The token currently travelling; drawn above its neighbours.
    private(set) var movingTokenID: Int?
    /// The token an unseen hand is carrying (the computer's move).
    private(set) var ghostLiftID: Int?
    /// Incremented when someone touches a piece out of turn, to briefly emphasise whose move it is.
    private(set) var turnNudge = 0
    private(set) var ripples: [Ripple] = []
    /// True while the computer is choosing its move.
    private(set) var isThinking = false
    var isResultPresented = false

    /// The computer's side and strength, or nil when two people are playing.
    private(set) var computer: (color: PieceColor, level: BotLevel)?

    @ObservationIgnored let feedback: FeedbackCoordinator
    @ObservationIgnored private let store: GameStore
    @ObservationIgnored private var pendingWork: [Task<Void, Never>] = []
    @ObservationIgnored private var thinkTask: Task<Void, Never>?
    @ObservationIgnored private var rippleID = 0

    init(feedback: FeedbackCoordinator, store: GameStore = GameStore(), initialGame: ChessGame? = nil) {
        self.feedback = feedback
        self.store = store
        game = initialGame ?? store.load() ?? ChessGame()
        rebuildTokens()
    }

    // MARK: Queries

    var sideToMove: PieceColor { game.sideToMove }
    var isOver: Bool { game.isOver }
    var result: GameResult? { game.result }
    var lastMove: Move? { game.lastMove?.move }
    var canUndo: Bool { !game.history.isEmpty || game.hasManualResult }
    var canClaimDraw: Bool { game.canClaimDraw && !isComputerTurn }
    var isComputerTurn: Bool { computer?.color == game.sideToMove && !game.isOver }

    /// The king currently in check (or mated), if any.
    var checkedKing: Square? {
        game.position.isInCheck ? game.position.kingSquare(game.sideToMove) : nil
    }

    func token(at square: Square) -> PieceToken? {
        tokens.first { $0.square == square && !$0.isCaptured }
    }

    func canPickUp(_ square: Square) -> Bool {
        guard !game.isOver, pendingPromotion == nil, !isComputerTurn, ghostLiftID == nil,
              let p = game.position[square] else { return false }
        return p.color == game.sideToMove
    }

    /// Number of pieces in each player's tray.
    func trayCount(_ color: PieceColor) -> Int {
        tokens.filter { $0.isCaptured && $0.capturedBy == color }.count
    }

    /// Material lead for `color` based on what is still on the board (counts promotions correctly).
    func materialLead(for color: PieceColor) -> Int {
        var total = 0
        for sq in Square.all {
            guard let p = game.position[sq] else { continue }
            total += p.color == color ? p.kind.value : -p.kind.value
        }
        return total
    }

    // MARK: Opponent

    /// Called when the opponent settings change.
    func configure(computer newValue: (color: PieceColor, level: BotLevel)?) {
        let changed = newValue?.color != computer?.color || newValue?.level != computer?.level
        computer = newValue
        guard changed else { return }
        thinkTask?.cancel()
        isThinking = false
        clearSelection()
        scheduleComputerMove(after: 0.5)
    }

    private func scheduleComputerMove(after minimum: Double = 0.55) {
        guard let computer, computer.color == game.sideToMove, !game.isOver,
              pendingPromotion == nil, thinkTask == nil || thinkTask?.isCancelled == true else { return }
        let snapshot = game
        let plies = game.history.count
        isThinking = true
        thinkTask = Task { @MainActor [weak self] in
            let started = ContinuousClock.now
            let move = await Task.detached(priority: .userInitiated) {
                Engine.bestMove(for: snapshot, level: computer.level)
            }.value
            // A short, natural pause, so the reply never feels instantaneous.
            let elapsed = Double((ContinuousClock.now - started).components.attoseconds) / 1e18
                + Double((ContinuousClock.now - started).components.seconds)
            if elapsed < minimum { try? await Task.sleep(for: .seconds(minimum - elapsed)) }
            guard let self, !Task.isCancelled else { return }
            self.thinkTask = nil
            self.isThinking = false
            guard let move, self.game.history.count == plies, !self.game.isOver else { return }
            self.ghostMove(move)
        }
    }

    /// The computer's move, made by an unseen hand: the piece lifts, glides and settles.
    private func ghostMove(_ move: Move) {
        guard let t = token(at: move.from) else { return }
        ghostLiftID = t.id
        if let i = tokens.firstIndex(where: { $0.id == t.id }) {
            tokens[i].motion = Motion.lift
            tokens[i].revision += 1
        }
        feedback.pickup(at: move.from)
        after(0.26) { s in s.commit(move, style: .ghost) }
    }

    // MARK: Selection

    func select(_ square: Square) {
        guard canPickUp(square) else { return }
        selection = square
        targets = Dictionary(grouping: game.legalMoves(from: square), by: \.to)
        ripple(at: square, .pickup)
    }

    func clearSelection() {
        selection = nil
        targets = [:]
    }

    /// A touch landed on a piece that cannot move now.
    func touchedOutOfTurn(_ square: Square) {
        turnNudge += 1
        feedback.invalid(at: square)
    }

    // MARK: Moving

    /// Attempts to move the selected piece to `square`.
    @discardableResult
    func move(from: Square, to: Square, dragged: Bool) -> DropOutcome {
        guard from != to else { return .unchanged }
        guard let moves = targets[to], selection == from, !moves.isEmpty else {
            if let id = token(at: from)?.id { settleBack(id) }
            feedback.invalid(at: from)
            return .rejected
        }
        if moves.contains(where: { $0.promotion != nil }), let t = token(at: from) {
            offerPromotion(from: from, to: to, token: t, dragged: dragged)
            return .promotion
        }
        commit(moves[0], style: dragged ? .dropped : .tapped)
        return .moved
    }

    /// The piece leaves the board surface: its lift toward the player animates in, while the
    /// finger tracking that follows is applied without animation.
    func beginDrag(_ tokenID: Int) {
        guard let i = tokens.firstIndex(where: { $0.id == tokenID }) else { return }
        tokens[i].motion = Motion.lift
        tokens[i].revision += 1
    }

    /// Animates a token back to its square, e.g. after an illegal drop or a drop on its own square.
    func settleBack(_ tokenID: Int) {
        guard let i = tokens.firstIndex(where: { $0.id == tokenID }) else { return }
        tokens[i].motion = Motion.returnHome
        tokens[i].revision += 1
        let id = tokens[i].id
        after(0.16) { s in s.land(id) }
    }

    private func offerPromotion(from: Square, to: Square, token: PieceToken, dragged: Bool) {
        guard let i = tokens.firstIndex(where: { $0.id == token.id }) else { return }
        let path = travel(from: from, to: to)
        tokens[i].square = to
        tokens[i].motion = dragged ? Motion.settle : path.animation
        tokens[i].revision += 1
        movingTokenID = token.id
        clearSelection()
        pendingPromotion = PendingPromotion(from: from, to: to, color: token.piece.color, tokenID: token.id)
        feedback.audio.play(.place, delay: dragged ? Motion.settleLanding : path.landing, gain: 0.6)
    }

    func choosePromotion(_ kind: PieceKind) {
        guard let p = pendingPromotion else { return }
        // The pawn is already standing on the promotion square; put it back on its origin in the
        // model so the move applies normally, without moving it on screen.
        if let i = tokens.firstIndex(where: { $0.id == p.tokenID }) { tokens[i].square = p.from }
        pendingPromotion = nil
        commit(Move(from: p.from, to: p.to, promotion: kind), style: .alreadyThere)
    }

    func cancelPromotion() {
        guard let p = pendingPromotion else { return }
        pendingPromotion = nil
        if let i = tokens.firstIndex(where: { $0.id == p.tokenID }) {
            tokens[i].square = p.from
            tokens[i].motion = Motion.returnHome
            tokens[i].revision += 1
        }
        feedback.putBack(at: p.from)
    }

    private func travel(from: Square, to: Square, ghost: Bool = false) -> (animation: Animation, landing: Double) {
        let squares = TokenLayout.distance(from, to)
        if ghost {
            // An unhurried, deliberate carry: ease in and out, as a hand would move it.
            let d = min(0.62, 0.34 + 0.035 * squares)
            return (.timingCurve(0.45, 0.0, 0.2, 1.0, duration: d), d * 0.86)
        }
        let d = Motion.travelDuration(squares: squares)
        let c = Motion.travelCurve
        return (.timingCurve(c.0, c.1, c.2, c.3, duration: d), d * Motion.landingFraction)
    }

    private enum CommitStyle { case tapped, dropped, alreadyThere, ghost }

    private func commit(_ move: Move, style: CommitStyle) {
        let before = tokens
        guard let played = game.play(move) else { ghostLiftID = nil; return }
        snapshots.append(before)
        clearSelection()

        let fx = played.effect
        let timing: (animation: Animation, landing: Double)
        switch style {
        case .alreadyThere: timing = (Motion.settle, 0.02)
        case .dropped: timing = (Motion.settle, Motion.settleLanding)
        case .tapped: timing = travel(from: move.from, to: move.to)
        case .ghost: timing = travel(from: move.from, to: move.to, ghost: true)
        }
        let animation = timing.animation
        let landing = timing.landing

        var next = tokens
        var flight: (id: Int, arrival: Double)?
        if let cs = fx.capturedSquare,
           let ci = next.firstIndex(where: { $0.square == cs && !$0.isCaptured && $0.piece == fx.captured }) {
            // The taken piece is lifted off as the attacker arrives and carried to the tray.
            let mover = fx.piece.color
            next[ci].isCaptured = true
            next[ci].capturedBy = mover
            next[ci].trayIndex = next.filter { $0.isCaptured && $0.capturedBy == mover && $0.id != next[ci].id }.count
            next[ci].motion = Motion.toTray.delay(max(0, landing - 0.02))
            next[ci].revision += 1
            flight = (next[ci].id, landing + Motion.toTrayLanding)
        }
        var moverID: Int?
        if let i = next.firstIndex(where: { $0.square == move.from && $0.piece == fx.piece && !$0.isCaptured }) {
            next[i].square = move.to
            if let promo = fx.promotion { next[i].piece = Piece(fx.piece.color, promo) }
            next[i].motion = animation
            next[i].revision += 1
            movingTokenID = next[i].id
            moverID = next[i].id
        }
        var rookLanding: Double?
        var rookID: Int?
        if let rf = fx.rookFrom, let rt = fx.rookTo, let ri = TokenLayout.onBoard(next, at: rf) {
            let rook = travel(from: rf, to: rt)
            let delay = landing + Motion.castleRookDelay * 0.4
            next[ri].square = rt
            next[ri].motion = rook.animation.delay(delay)
            next[ri].revision += 1
            rookLanding = delay + rook.landing
            rookID = next[ri].id
        }
        tokens = next

        feedback.moveCommitted(played, landing: landing, rookLanding: rookLanding, result: game.result)

        // Landings: the settle, a ring of light, and for a ghost move, the hand letting go.
        after(landing) { s in
            if let moverID { s.land(moverID) }
            if style == .ghost { s.ghostLiftID = nil }
            s.ripple(at: move.to, fx.isCapture ? .capture : .land)
        }
        if let rookLanding, let rookID, let rt = fx.rookTo {
            after(rookLanding) { s in
                s.land(rookID)
                s.ripple(at: rt, .land)
            }
        }
        if let flight {
            after(flight.arrival) { s in
                s.land(flight.id)
                s.feedback.trayLanding()
            }
        }

        if let result = game.result {
            let wait: Double
            if case .checkmate = result { wait = 1.05 } else { wait = 0.9 }
            after(max(landing, rookLanding ?? 0) + wait) { s in
                if s.game.result != nil { s.isResultPresented = true }
            }
        } else {
            scheduleComputerMove(after: max(0.55, landing + 0.25))
        }
        save()
    }

    private func land(_ tokenID: Int) {
        guard let i = tokens.firstIndex(where: { $0.id == tokenID }) else { return }
        tokens[i].landing += 1
    }

    private func ripple(at square: Square, _ style: Ripple.Style) {
        rippleID += 1
        let r = Ripple(id: rippleID, square: square, style: style, delay: 0)
        ripples.append(r)
        after(0.8) { s in s.ripples.removeAll { $0.id == r.id } }
    }

    // MARK: Game control

    func undo() {
        thinkTask?.cancel()
        thinkTask = nil
        isThinking = false
        ghostLiftID = nil
        cancelPromotion()
        clearSelection()
        cancelPendingWork()
        if game.hasManualResult {
            game.undo()
            isResultPresented = false
            save()
            return
        }
        guard let undone = undoOne() else { return }
        // Against the computer, take back its reply too, so it is the person's move again.
        var shown = undone
        if let computer, computer.color == game.sideToMove, !game.history.isEmpty, let earlier = undoOne() {
            shown = earlier
        }
        feedback.undo(landing: 0.16, square: shown.move.from)
        save()
        scheduleComputerMove(after: 0.8)
    }

    @discardableResult
    private func undoOne() -> PlayedMove? {
        guard let undone = game.undo(), let previous = snapshots.popLast() else { return nil }
        isResultPresented = false
        let current = Dictionary(uniqueKeysWithValues: tokens.map { ($0.id, $0) })
        var restored = previous
        for i in restored.indices {
            let old = current[restored[i].id]
            let moved = old?.square != restored[i].square || old?.piece != restored[i].piece
                || old?.isCaptured != restored[i].isCaptured
            restored[i].landing = old?.landing ?? 0
            if moved {
                restored[i].motion = old?.isCaptured == true && !restored[i].isCaptured ? Motion.fromTray : Motion.undo
                restored[i].revision = (old?.revision ?? restored[i].revision) + 1
            } else if let old {
                restored[i].revision = old.revision
            }
        }
        movingTokenID = restored.first { $0.square == undone.move.from && !$0.isCaptured }?.id
        withAnimation(Motion.undo) { tokens = restored }
        return undone
    }

    func newGame() {
        thinkTask?.cancel()
        thinkTask = nil
        isThinking = false
        ghostLiftID = nil
        cancelPendingWork()
        pendingPromotion = nil
        clearSelection()
        isResultPresented = false
        game = ChessGame()
        snapshots = []
        var regathered = TokenLayout.regather(tokens, into: game.position, nextID: &nextID)
        for i in regathered.indices {
            // Pieces return home in a gentle wave from White's side to Black's.
            let delay = Double(regathered[i].square.rank) * 0.02 + Double(regathered[i].square.file) * 0.005
            regathered[i].motion = .spring(response: 0.5, dampingFraction: 0.86).delay(delay)
            regathered[i].revision += 1
        }
        movingTokenID = nil
        withAnimation(.easeOut(duration: 0.3)) { tokens = regathered }
        feedback.newGame()
        save()
        scheduleComputerMove(after: 1.2)
    }

    func claimDraw() {
        guard game.claimDraw() else { return }
        feedback.gameEndedByChoice()
        presentResultSoon()
    }

    func resign(_ color: PieceColor) {
        thinkTask?.cancel()
        isThinking = false
        game.resign(color)
        feedback.gameEndedByChoice()
        presentResultSoon()
    }

    func agreeDraw() {
        thinkTask?.cancel()
        isThinking = false
        game.agreeDraw()
        feedback.gameEndedByChoice()
        presentResultSoon()
    }

    func dismissResult() {
        isResultPresented = false
    }

    private func presentResultSoon() {
        clearSelection()
        save()
        after(0.35) { s in s.isResultPresented = s.game.result != nil }
    }

    // MARK: Lifecycle

    func save() {
        store.save(game)
    }

    private func rebuildTokens() {
        var t = TokenLayout.tokens(for: game.initialPosition, nextID: &nextID)
        snapshots = []
        for played in game.history {
            snapshots.append(t)
            TokenLayout.apply(played.effect, to: &t)
        }
        tokens = t
    }

    private func after(_ seconds: Double, _ body: @escaping @MainActor (GameSession) -> Void) {
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            body(self)
        }
        pendingWork.append(task)
        pendingWork.removeAll { $0.isCancelled }
    }

    private func cancelPendingWork() {
        pendingWork.forEach { $0.cancel() }
        pendingWork = []
        ripples = []
    }
}

/// Keeps the game across launches.
struct GameStore {
    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("game.json")
    }()
    private static let queue = DispatchQueue(label: "table.store", qos: .utility)

    func load() -> ChessGame? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ChessGame.self, from: data)
    }

    func save(_ game: ChessGame) {
        let url = url
        Self.queue.async {
            guard let data = try? JSONEncoder().encode(game) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
