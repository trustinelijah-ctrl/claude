// A complete chess position with fully legal move generation.

public struct Position: Hashable, Codable, Sendable {
    public private(set) var board: [Piece?]
    public private(set) var sideToMove: PieceColor
    public private(set) var castling: CastlingRights
    /// The square a pawn skipped over on the previous double step, as in FEN.
    public private(set) var enPassant: Square?
    public private(set) var halfmoveClock: Int
    public private(set) var fullmoveNumber: Int

    public static let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    public static let start = Position(fen: startFEN)!

    public subscript(_ square: Square) -> Piece? { board[square.index] }

    // MARK: FEN

    public init?(fen: String) {
        let fields = fen.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard fields.count >= 4 else { return nil }

        var board = [Piece?](repeating: nil, count: 64)
        let ranks = fields[0].split(separator: "/", omittingEmptySubsequences: false)
        guard ranks.count == 8 else { return nil }
        for (i, row) in ranks.enumerated() {
            let rank = 7 - i
            var file = 0
            for ch in row {
                if let n = ch.wholeNumberValue {
                    guard (1...8).contains(n) else { return nil }
                    file += n
                } else {
                    guard let kind = PieceKind(fenLetter: ch), file < 8 else { return nil }
                    board[rank * 8 + file] = Piece(ch.isUppercase ? .white : .black, kind)
                    file += 1
                }
                if file > 8 { return nil }
            }
            guard file == 8 else { return nil }
        }

        let side: PieceColor
        switch fields[1] {
        case "w": side = .white
        case "b": side = .black
        default: return nil
        }

        var rights: CastlingRights = []
        if fields[2] != "-" {
            for ch in fields[2] {
                switch ch {
                case "K": rights.insert(.whiteKingside)
                case "Q": rights.insert(.whiteQueenside)
                case "k": rights.insert(.blackKingside)
                case "q": rights.insert(.blackQueenside)
                default: return nil
                }
            }
        }

        var ep: Square?
        if fields[3] != "-" {
            guard let sq = Square(fields[3]) else { return nil }
            ep = sq
        }

        self.board = board
        self.sideToMove = side
        self.castling = rights
        self.enPassant = ep
        self.halfmoveClock = fields.count > 4 ? Int(fields[4]) ?? 0 : 0
        self.fullmoveNumber = fields.count > 5 ? Int(fields[5]) ?? 1 : 1
        sanitizeCastlingRights()

        guard kingSquare(.white) != nil, kingSquare(.black) != nil else { return nil }
    }

    public var fen: String {
        var rows: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var row = ""
            var empty = 0
            for file in 0..<8 {
                if let p = board[rank * 8 + file] {
                    if empty > 0 { row += String(empty); empty = 0 }
                    row.append(p.fenLetter)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += String(empty) }
            rows.append(row)
        }
        var c = ""
        if castling.contains(.whiteKingside) { c += "K" }
        if castling.contains(.whiteQueenside) { c += "Q" }
        if castling.contains(.blackKingside) { c += "k" }
        if castling.contains(.blackQueenside) { c += "q" }
        if c.isEmpty { c = "-" }
        return [rows.joined(separator: "/"), sideToMove == .white ? "w" : "b", c,
                enPassant?.name ?? "-", String(halfmoveClock), String(fullmoveNumber)].joined(separator: " ")
    }

    /// Drops castling rights that the piece placement can no longer support.
    private mutating func sanitizeCastlingRights() {
        for color in PieceColor.allCases {
            let home = color.homeRank
            if board[home * 8 + 4] != Piece(color, .king) {
                castling.remove(.kingside(color))
                castling.remove(.queenside(color))
            }
            if board[home * 8 + 7] != Piece(color, .rook) { castling.remove(.kingside(color)) }
            if board[home * 8 + 0] != Piece(color, .rook) { castling.remove(.queenside(color)) }
        }
    }

    // MARK: Queries

    public func kingSquare(_ color: PieceColor) -> Square? {
        let king = Piece(color, .king)
        guard let i = board.firstIndex(where: { $0 == king }) else { return nil }
        return Square(index: i)
    }

    public var isInCheck: Bool {
        guard let k = kingSquare(sideToMove) else { return false }
        return isAttacked(k, by: sideToMove.opposite)
    }

    private static let knightSteps = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    private static let kingSteps = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    private static let rookDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    private static let bishopDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

    /// Whether `square` is attacked by any piece of `attacker`.
    public func isAttacked(_ square: Square, by attacker: PieceColor) -> Bool {
        // Pawns attack diagonally forward, so look backwards from the target.
        let pawnRank = -attacker.forward
        for df in [-1, 1] {
            if let s = square.offset(file: df, rank: pawnRank), self[s] == Piece(attacker, .pawn) { return true }
        }
        for (df, dr) in Self.knightSteps {
            if let s = square.offset(file: df, rank: dr), self[s] == Piece(attacker, .knight) { return true }
        }
        for (df, dr) in Self.kingSteps {
            if let s = square.offset(file: df, rank: dr), self[s] == Piece(attacker, .king) { return true }
        }
        for (dirs, kind) in [(Self.rookDirs, PieceKind.rook), (Self.bishopDirs, PieceKind.bishop)] {
            for (df, dr) in dirs {
                var cur = square.offset(file: df, rank: dr)
                while let s = cur {
                    if let p = self[s] {
                        if p.color == attacker && (p.kind == kind || p.kind == .queen) { return true }
                        break
                    }
                    cur = s.offset(file: df, rank: dr)
                }
            }
        }
        return false
    }

    // MARK: Move generation

    /// All moves that obey piece movement rules, ignoring whether the mover's king is left in check.
    func pseudoLegalMoves() -> [Move] {
        var moves: [Move] = []
        moves.reserveCapacity(48)
        let us = sideToMove
        for i in 0..<64 {
            guard let p = board[i], p.color == us else { continue }
            let from = Square(index: i)
            switch p.kind {
            case .pawn:
                addPawnMoves(from: from, into: &moves)
            case .knight:
                addSteps(Self.knightSteps, from: from, into: &moves)
            case .king:
                addSteps(Self.kingSteps, from: from, into: &moves)
                addCastling(into: &moves)
            case .bishop:
                addSlides(Self.bishopDirs, from: from, into: &moves)
            case .rook:
                addSlides(Self.rookDirs, from: from, into: &moves)
            case .queen:
                addSlides(Self.bishopDirs, from: from, into: &moves)
                addSlides(Self.rookDirs, from: from, into: &moves)
            }
        }
        return moves
    }

    private func addSteps(_ steps: [(Int, Int)], from: Square, into moves: inout [Move]) {
        for (df, dr) in steps {
            guard let to = from.offset(file: df, rank: dr) else { continue }
            if let q = self[to], q.color == sideToMove { continue }
            moves.append(Move(from: from, to: to))
        }
    }

    private func addSlides(_ dirs: [(Int, Int)], from: Square, into moves: inout [Move]) {
        for (df, dr) in dirs {
            var cur = from.offset(file: df, rank: dr)
            while let to = cur {
                if let q = self[to] {
                    if q.color != sideToMove { moves.append(Move(from: from, to: to)) }
                    break
                }
                moves.append(Move(from: from, to: to))
                cur = to.offset(file: df, rank: dr)
            }
        }
    }

    private func addPawnMoves(from: Square, into moves: inout [Move]) {
        let us = sideToMove
        let fwd = us.forward

        func add(_ to: Square) {
            if to.rank == us.promotionRank {
                for k in PieceKind.promotionChoices { moves.append(Move(from: from, to: to, promotion: k)) }
            } else {
                moves.append(Move(from: from, to: to))
            }
        }

        if let one = from.offset(file: 0, rank: fwd), self[one] == nil {
            add(one)
            if from.rank == us.pawnStartRank, let two = from.offset(file: 0, rank: 2 * fwd), self[two] == nil {
                moves.append(Move(from: from, to: two))
            }
        }
        for df in [-1, 1] {
            guard let to = from.offset(file: df, rank: fwd) else { continue }
            if let q = self[to], q.color != us {
                add(to)
            } else if to == enPassant {
                moves.append(Move(from: from, to: to))
            }
        }
    }

    private func addCastling(into moves: inout [Move]) {
        let us = sideToMove
        let r = us.homeRank
        let kingFrom = Square(file: 4, rank: r)
        guard self[kingFrom] == Piece(us, .king) else { return }
        let them = us.opposite

        if castling.contains(.kingside(us)),
           self[Square(file: 7, rank: r)] == Piece(us, .rook),
           self[Square(file: 5, rank: r)] == nil, self[Square(file: 6, rank: r)] == nil,
           !isAttacked(kingFrom, by: them),
           !isAttacked(Square(file: 5, rank: r), by: them),
           !isAttacked(Square(file: 6, rank: r), by: them) {
            moves.append(Move(from: kingFrom, to: Square(file: 6, rank: r)))
        }
        if castling.contains(.queenside(us)),
           self[Square(file: 0, rank: r)] == Piece(us, .rook),
           self[Square(file: 1, rank: r)] == nil, self[Square(file: 2, rank: r)] == nil,
           self[Square(file: 3, rank: r)] == nil,
           !isAttacked(kingFrom, by: them),
           !isAttacked(Square(file: 3, rank: r), by: them),
           !isAttacked(Square(file: 2, rank: r), by: them) {
            moves.append(Move(from: kingFrom, to: Square(file: 2, rank: r)))
        }
    }

    /// Every legal move for the side to move.
    public func legalMoves() -> [Move] {
        let us = sideToMove
        return pseudoLegalMoves().filter { move in
            let next = applyingUnchecked(move)
            guard let k = next.kingSquare(us) else { return false }
            return !next.isAttacked(k, by: us.opposite)
        }
    }

    public func legalMoves(from square: Square) -> [Move] {
        guard let p = self[square], p.color == sideToMove else { return [] }
        return legalMoves().filter { $0.from == square }
    }

    public func isLegal(_ move: Move) -> Bool {
        legalMoves().contains(move)
    }

    // MARK: Making moves

    /// Describes the physical consequences of a move on the board.
    public func effect(of move: Move) -> MoveEffect? {
        guard let piece = self[move.from] else { return nil }
        var captured: Piece? = self[move.to]
        var capturedSquare: Square? = captured == nil ? nil : move.to
        var rookMove: (from: Square, to: Square)?
        var isEnPassant = false

        if piece.kind == .pawn, move.to == enPassant, move.from.file != move.to.file, self[move.to] == nil {
            isEnPassant = true
            let s = Square(file: move.to.file, rank: move.from.rank)
            captured = self[s]
            capturedSquare = s
        }
        if piece.kind == .king, abs(move.to.file - move.from.file) == 2 {
            let r = move.from.rank
            rookMove = move.to.file == 6
                ? (Square(file: 7, rank: r), Square(file: 5, rank: r))
                : (Square(file: 0, rank: r), Square(file: 3, rank: r))
        }
        return MoveEffect(move: move, piece: piece, captured: captured, capturedSquare: capturedSquare,
                          rookFrom: rookMove?.from, rookTo: rookMove?.to,
                          isEnPassant: isEnPassant, promotion: move.promotion)
    }

    /// Applies a move without checking legality. Callers must only pass pseudo-legal moves.
    func applyingUnchecked(_ move: Move) -> Position {
        var next = self
        guard let fx = effect(of: move) else { return next }
        let us = sideToMove

        if let cs = fx.capturedSquare { next.board[cs.index] = nil }
        next.board[move.from.index] = nil
        next.board[move.to.index] = move.promotion.map { Piece(us, $0) } ?? fx.piece
        if let rf = fx.rookFrom, let rt = fx.rookTo {
            next.board[rt.index] = next.board[rf.index]
            next.board[rf.index] = nil
        }

        // Castling rights: a king move forfeits both, any move from or to a rook corner forfeits that side.
        if fx.piece.kind == .king {
            next.castling.remove(.kingside(us))
            next.castling.remove(.queenside(us))
        }
        for sq in [move.from, move.to] {
            switch (sq.file, sq.rank) {
            case (0, 0): next.castling.remove(.whiteQueenside)
            case (7, 0): next.castling.remove(.whiteKingside)
            case (0, 7): next.castling.remove(.blackQueenside)
            case (7, 7): next.castling.remove(.blackKingside)
            default: break
            }
        }

        next.enPassant = nil
        if fx.piece.kind == .pawn, abs(move.to.rank - move.from.rank) == 2 {
            next.enPassant = Square(file: move.from.file, rank: (move.from.rank + move.to.rank) / 2)
        }

        next.halfmoveClock = (fx.piece.kind == .pawn || fx.captured != nil) ? 0 : halfmoveClock + 1
        if us == .black { next.fullmoveNumber += 1 }
        next.sideToMove = us.opposite
        return next
    }

    /// Applies a legal move, or returns nil if the move is illegal.
    public func applying(_ move: Move) -> Position? {
        guard isLegal(move) else { return nil }
        return applyingUnchecked(move)
    }

    // MARK: Draw helpers

    /// Identity used for repetition: placement, side, castling rights and a *capturable* en-passant square.
    public var repetitionKey: String {
        var key = ""
        key.reserveCapacity(80)
        for p in board { key.append(p?.fenLetter ?? ".") }
        key.append(sideToMove == .white ? "w" : "b")
        key.append(String(castling.rawValue))
        if let ep = enPassant, legalMoves().contains(where: { $0.to == ep && self[$0.from]?.kind == .pawn }) {
            key.append(ep.name)
        }
        return key
    }

    /// True when neither side can possibly deliver checkmate.
    public var hasInsufficientMaterial: Bool {
        var minors: [(Piece, Square)] = []
        for (i, p) in board.enumerated() {
            guard let p else { continue }
            switch p.kind {
            case .king: continue
            case .pawn, .rook, .queen: return false
            case .knight, .bishop: minors.append((p, Square(index: i)))
            }
        }
        if minors.count <= 1 { return true }
        // Any number of bishops, all on squares of one colour, can never mate.
        if minors.allSatisfy({ $0.0.kind == .bishop }) {
            let shade = minors[0].1.isLight
            return minors.allSatisfy { $0.1.isLight == shade }
        }
        return false
    }

    // MARK: Notation

    /// Standard Algebraic Notation for a legal move in this position.
    public func san(for move: Move) -> String {
        guard let fx = effect(of: move) else { return move.description }
        var s: String
        if fx.isCastle {
            s = move.to.file == 6 ? "O-O" : "O-O-O"
        } else {
            s = fx.piece.kind.sanLetter
            if fx.piece.kind == .pawn {
                if fx.captured != nil { s += String(Array("abcdefgh")[move.from.file]) }
            } else {
                let rivals = legalMoves().filter {
                    $0.to == move.to && $0.from != move.from && self[$0.from] == fx.piece
                }
                if !rivals.isEmpty {
                    let sameFile = rivals.contains { $0.from.file == move.from.file }
                    let sameRank = rivals.contains { $0.from.rank == move.from.rank }
                    if !sameFile {
                        s += String(Array("abcdefgh")[move.from.file])
                    } else if !sameRank {
                        s += String(move.from.rank + 1)
                    } else {
                        s += move.from.name
                    }
                }
            }
            if fx.captured != nil { s += "x" }
            s += move.to.name
            if let promo = move.promotion { s += "=" + promo.sanLetter }
        }
        let next = applyingUnchecked(move)
        if next.isInCheck {
            s += next.legalMoves().isEmpty ? "#" : "+"
        }
        return s
    }
}

/// What a move physically does: which pieces move, which (if any) leaves the board.
public struct MoveEffect: Hashable, Codable, Sendable {
    public let move: Move
    public let piece: Piece
    public let captured: Piece?
    public let capturedSquare: Square?
    public let rookFrom: Square?
    public let rookTo: Square?
    public let isEnPassant: Bool
    public let promotion: PieceKind?

    public var isCastle: Bool { rookFrom != nil }
    public var isCapture: Bool { captured != nil }
}
