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

/// The game at the table: rules state, the physical pieces, selection and the timing of
/// everything that happens when a move is made.
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
    /// Incremented when someone touches a piece out of turn, to briefly emphasise whose move it is.
    private(set) var turnNudge = 0
    var isResultPresented = false

    @ObservationIgnored let feedback: FeedbackCoordinator
    @ObservationIgnored private let store: GameStore
    @ObservationIgnored private var pendingWork: [Task<Void, Never>] = []

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
    var canClaimDraw: Bool { game.canClaimDraw }

    /// The king currently in check (or mated), if any.
    var checkedKing: Square? {
        game.position.isInCheck ? game.position.kingSquare(game.sideToMove) : nil
    }

    func token(at square: Square) -> PieceToken? {
        tokens.first { $0.square == square && !$0.isCaptured }
    }

    func canPickUp(_ square: Square) -> Bool {
        guard !game.isOver, pendingPromotion == nil, let p = game.position[square] else { return false }
        return p.color == game.sideToMove
    }

    /// Pieces each side has taken, most valuable first.
    func captures(by color: PieceColor) -> [Piece] {
        game.history.compactMap { $0.effect.piece.color == color ? $0.effect.captured : nil }
            .sorted { $0.kind.value > $1.kind.value }
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

    // MARK: Selection

    func select(_ square: Square) {
        guard canPickUp(square) else { return }
        selection = square
        targets = Dictionary(grouping: game.legalMoves(from: square), by: \.to)
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
        commit(moves[0], dragged: dragged)
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
    }

    private func offerPromotion(from: Square, to: Square, token: PieceToken, dragged: Bool) {
        guard let i = tokens.firstIndex(where: { $0.id == token.id }) else { return }
        tokens[i].square = to
        tokens[i].motion = dragged ? Motion.settle : travel(from: from, to: to).animation
        tokens[i].revision += 1
        movingTokenID = token.id
        clearSelection()
        pendingPromotion = PendingPromotion(from: from, to: to, color: token.piece.color, tokenID: token.id)
        let landing = dragged ? Motion.settleLanding : travel(from: from, to: to).landing
        feedback.audio.play(.place, delay: landing, gain: 0.6)
    }

    func choosePromotion(_ kind: PieceKind) {
        guard let p = pendingPromotion else { return }
        // The pawn is already standing on the promotion square; put it back on its origin in the
        // model so the move applies normally, without moving it on screen.
        if let i = tokens.firstIndex(where: { $0.id == p.tokenID }) { tokens[i].square = p.from }
        pendingPromotion = nil
        commit(Move(from: p.from, to: p.to, promotion: kind), dragged: true, alreadyThere: true)
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

    private func travel(from: Square, to: Square) -> (animation: Animation, landing: Double) {
        let d = Motion.travelDuration(squares: TokenLayout.distance(from, to))
        let c = Motion.travelCurve
        return (.timingCurve(c.0, c.1, c.2, c.3, duration: d), d * Motion.landingFraction)
    }

    private func commit(_ move: Move, dragged: Bool, alreadyThere: Bool = false) {
        tokens.removeAll { $0.isCaptured }
        let before = tokens
        guard let played = game.play(move) else { return }
        snapshots.append(before)
        clearSelection()

        let fx = played.effect
        let timing: (animation: Animation, landing: Double)
        if alreadyThere {
            timing = (Motion.settle, 0.02)
        } else if dragged {
            timing = (Motion.settle, Motion.settleLanding)
        } else {
            timing = travel(from: move.from, to: move.to)
        }
        let animation = timing.animation
        let landing = timing.landing

        var next = tokens
        if let cs = fx.capturedSquare,
           let ci = next.firstIndex(where: { $0.square == cs && $0.piece == fx.captured }) {
            next[ci].isCaptured = true
            next[ci].motion = .easeOut(duration: Motion.capture).delay(max(0, landing - 0.06))
            next[ci].revision += 1
        }
        if let i = next.firstIndex(where: { $0.square == move.from && $0.piece == fx.piece && !$0.isCaptured }) {
            next[i].square = move.to
            if let promo = fx.promotion { next[i].piece = Piece(fx.piece.color, promo) }
            next[i].motion = animation
            next[i].revision += 1
            movingTokenID = next[i].id
        }
        var rookLanding: Double?
        if let rf = fx.rookFrom, let rt = fx.rookTo, let ri = next.firstIndex(where: { $0.square == rf }) {
            let rook = travel(from: rf, to: rt)
            let delay = (dragged ? Motion.settleLanding : landing) + Motion.castleRookDelay * 0.4
            next[ri].square = rt
            next[ri].motion = rook.animation.delay(delay)
            next[ri].revision += 1
            rookLanding = delay + rook.landing
        }
        tokens = next

        feedback.moveCommitted(played, landing: landing, rookLanding: rookLanding, result: game.result)
        after(landing + Motion.capture + 0.15) { s in s.tokens.removeAll { $0.isCaptured } }
        if let result = game.result {
            let wait: Double
            if case .checkmate = result { wait = 1.05 } else { wait = 0.9 }
            after(max(landing, rookLanding ?? 0) + wait) { s in
                if s.game.result != nil { s.isResultPresented = true }
            }
        }
        save()
    }

    // MARK: Game control

    func undo() {
        cancelPromotion()
        clearSelection()
        cancelPendingWork()
        if game.hasManualResult {
            game.undo()
            isResultPresented = false
            save()
            return
        }
        guard let undone = game.undo(), let previous = snapshots.popLast() else { return }
        isResultPresented = false
        let current = Dictionary(uniqueKeysWithValues: tokens.filter { !$0.isCaptured }.map { ($0.id, $0) })
        var restored = previous
        for i in restored.indices {
            let old = current[restored[i].id]
            if old?.square != restored[i].square || old?.piece != restored[i].piece {
                restored[i].motion = Motion.undo
                restored[i].revision = (old?.revision ?? restored[i].revision) + 1
            } else if let old {
                restored[i].revision = old.revision
            }
        }
        movingTokenID = restored.first { $0.square == undone.move.from }?.id
        withAnimation(Motion.undo) { tokens = restored }
        feedback.undo(landing: 0.14, square: undone.move.from)
        save()
    }

    func newGame() {
        cancelPendingWork()
        pendingPromotion = nil
        clearSelection()
        isResultPresented = false
        game = ChessGame()
        snapshots = []
        var regathered = TokenLayout.regather(tokens, into: game.position, nextID: &nextID)
        for i in regathered.indices {
            // Pieces return home in a gentle wave from White's side to Black's.
            let delay = Double(regathered[i].square.rank) * 0.018 + Double(regathered[i].square.file) * 0.004
            regathered[i].motion = .spring(response: 0.42, dampingFraction: 0.9).delay(delay)
            regathered[i].revision += 1
        }
        movingTokenID = nil
        withAnimation(.easeOut(duration: 0.3)) { tokens = regathered }
        feedback.newGame()
        save()
    }

    func claimDraw() {
        guard game.claimDraw() else { return }
        feedback.gameEndedByChoice()
        presentResultSoon()
    }

    func resign(_ color: PieceColor) {
        game.resign(color)
        feedback.gameEndedByChoice()
        presentResultSoon()
    }

    func agreeDraw() {
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
        tokens.removeAll { $0.isCaptured }
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
