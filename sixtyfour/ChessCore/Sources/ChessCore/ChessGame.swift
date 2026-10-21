// A game record: positions, played moves, and the rules for how a game ends.

public enum DrawReason: String, Codable, Sendable {
    case stalemate
    case insufficientMaterial
    case threefoldRepetition
    case fivefoldRepetition
    case fiftyMoveRule
    case seventyFiveMoveRule
    case agreement
    /// A flag fell, but the other side has too little left to ever mate.
    case timeoutVsInsufficientMaterial
}

public enum GameResult: Hashable, Codable, Sendable {
    case checkmate(winner: PieceColor)
    case resignation(winner: PieceColor)
    /// The loser's clock ran out.
    case timeout(winner: PieceColor)
    case draw(DrawReason)

    public var winner: PieceColor? {
        switch self {
        case .checkmate(let w), .resignation(let w), .timeout(let w): return w
        case .draw: return nil
        }
    }
}

public struct PlayedMove: Hashable, Sendable {
    public let effect: MoveEffect
    public let san: String
    public let givesCheck: Bool
    public let isCheckmate: Bool
    public var move: Move { effect.move }
}

public struct ChessGame: Sendable {
    public private(set) var positions: [Position]
    public private(set) var history: [PlayedMove] = []
    public private(set) var result: GameResult?
    private var repetitionKeys: [String]

    public init(position: Position = .start) {
        positions = [position]
        repetitionKeys = [position.repetitionKey]
        result = Self.automaticResult(position: position, repetitions: 1)
    }

    public var initialPosition: Position { positions[0] }
    public var position: Position { positions[positions.count - 1] }
    public var sideToMove: PieceColor { position.sideToMove }
    public var isOver: Bool { result != nil }
    public var lastMove: PlayedMove? { history.last }

    public func legalMoves(from square: Square) -> [Move] {
        isOver ? [] : position.legalMoves(from: square)
    }

    /// Plays a move if it is legal and the game is still in progress.
    @discardableResult
    public mutating func play(_ move: Move) -> PlayedMove? {
        guard !isOver, position.isLegal(move), let fx = position.effect(of: move) else { return nil }
        let san = position.san(for: move)
        let next = position.applyingUnchecked(move)
        let check = next.isInCheck
        let mate = check && next.legalMoves().isEmpty
        let played = PlayedMove(effect: fx, san: san, givesCheck: check, isCheckmate: mate)

        positions.append(next)
        history.append(played)
        repetitionKeys.append(next.repetitionKey)
        result = Self.automaticResult(position: next, repetitions: repetitionCount)
        return played
    }

    /// True when the game ended by resignation, agreement or a claimed draw rather than by the position itself.
    public var hasManualResult: Bool {
        result != nil && result != Self.automaticResult(position: position, repetitions: repetitionCount)
    }

    /// Takes back the last move and any result it produced.
    /// A resignation, agreement or claimed draw is withdrawn first, without taking back a move.
    @discardableResult
    public mutating func undo() -> PlayedMove? {
        if hasManualResult {
            clearManualResult()
            return nil
        }
        guard let last = history.popLast() else { return nil }
        positions.removeLast()
        repetitionKeys.removeLast()
        result = Self.automaticResult(position: position, repetitions: repetitionCount)
        return last
    }

    // MARK: Draws

    /// How many times the current position has occurred (including now).
    public var repetitionCount: Int {
        let key = repetitionKeys[repetitionKeys.count - 1]
        return repetitionKeys.reduce(0) { $0 + ($1 == key ? 1 : 0) }
    }

    public var canClaimThreefold: Bool { !isOver && repetitionCount >= 3 }
    public var canClaimFiftyMoveRule: Bool { !isOver && position.halfmoveClock >= 100 }
    public var canClaimDraw: Bool { canClaimThreefold || canClaimFiftyMoveRule }

    /// Claims a draw for the side to move when the rules allow it.
    @discardableResult
    public mutating func claimDraw() -> Bool {
        if canClaimThreefold {
            result = .draw(.threefoldRepetition)
        } else if canClaimFiftyMoveRule {
            result = .draw(.fiftyMoveRule)
        } else {
            return false
        }
        return true
    }

    public mutating func resign(_ color: PieceColor) {
        guard !isOver else { return }
        result = .resignation(winner: color.opposite)
    }

    /// `color`'s clock has run out. They lose, unless the opponent could never deliver mate,
    /// in which case the game is drawn.
    public mutating func flag(_ color: PieceColor) {
        guard !isOver else { return }
        result = Self.canNeverMate(position, color.opposite) ? .draw(.timeoutVsInsufficientMaterial)
                                                             : .timeout(winner: color.opposite)
    }

    /// A lone king, or a king with a single bishop or knight, cannot force or even help mate.
    static func canNeverMate(_ position: Position, _ color: PieceColor) -> Bool {
        var minors = 0
        for sq in Square.all {
            guard let p = position[sq], p.color == color else { continue }
            switch p.kind {
            case .king: continue
            case .bishop, .knight: minors += 1
            default: return false
            }
        }
        return minors <= 1
    }

    public mutating func agreeDraw() {
        guard !isOver else { return }
        result = .draw(.agreement)
    }

    /// Clears a result that was claimed or agreed rather than forced by the position.
    public mutating func clearManualResult() {
        result = Self.automaticResult(position: position, repetitions: repetitionCount)
    }

    static func automaticResult(position: Position, repetitions: Int) -> GameResult? {
        let hasMoves = !position.legalMoves().isEmpty
        if !hasMoves {
            return position.isInCheck ? .checkmate(winner: position.sideToMove.opposite) : .draw(.stalemate)
        }
        if position.hasInsufficientMaterial { return .draw(.insufficientMaterial) }
        if repetitions >= 5 { return .draw(.fivefoldRepetition) }
        if position.halfmoveClock >= 150 { return .draw(.seventyFiveMoveRule) }
        return nil
    }
}

// MARK: Persistence

extension ChessGame: Codable {
    private enum CodingKeys: String, CodingKey { case initialFEN, moves, result }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(initialPosition.fen, forKey: .initialFEN)
        try c.encode(history.map { $0.move.description }, forKey: .moves)
        try c.encodeIfPresent(result, forKey: .result)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fen = try c.decode(String.self, forKey: .initialFEN)
        guard let start = Position(fen: fen) else {
            throw DecodingError.dataCorruptedError(forKey: .initialFEN, in: c, debugDescription: "Invalid FEN")
        }
        self.init(position: start)
        for uci in try c.decode([String].self, forKey: .moves) {
            guard let m = Move(uci: uci), play(m) != nil else {
                throw DecodingError.dataCorruptedError(forKey: .moves, in: c, debugDescription: "Illegal move \(uci)")
            }
        }
        if let saved = try c.decodeIfPresent(GameResult.self, forKey: .result) {
            result = saved
        }
    }
}
