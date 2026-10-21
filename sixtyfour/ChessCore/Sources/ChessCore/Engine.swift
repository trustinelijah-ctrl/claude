import Foundation

/// How strongly the computer opponent plays.
public enum BotLevel: String, CaseIterable, Codable, Sendable, Identifiable {
    case casual, club, master, grandmaster

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .casual: return "Casual"
        case .club: return "Club"
        case .master: return "Master"
        case .grandmaster: return "Grandmaster"
        }
    }

    /// The stronger opponents come with TABLE Pro.
    public var isPro: Bool { self == .master || self == .grandmaster }

    /// Thinking time per move, in seconds.
    var timeLimit: Double {
        switch self {
        case .casual: return 0.25
        case .club: return 0.8
        case .master: return 2.0
        case .grandmaster: return 4.5
        }
    }

    var maxDepth: Int {
        switch self {
        case .casual: return 2
        case .club: return 6
        case .master, .grandmaster: return 64
        }
    }

    /// Moves within this many centipawns of the best are considered equally, so play varies.
    var tolerance: Int {
        switch self {
        case .casual: return 110
        case .club: return 18
        case .master, .grandmaster: return 0
        }
    }
}

/// The computer opponent: an alpha-beta search over a compact, mutable board.
///
/// The rules engine (`Position`) favours clarity; this favours speed. It has its own move
/// generator, verified against the same perft reference counts, and every move it returns
/// is checked against `Position.legalMoves()` before it is played.
public enum Engine {
    /// Chooses a move for the side to move. Returns nil if the game is over.
    public static func bestMove(for game: ChessGame, level: BotLevel, seed: UInt64? = nil) -> Move? {
        guard !game.isOver else { return nil }
        var search = Search(position: game.position, history: game.positions.dropLast(),
                            level: level, seed: seed ?? UInt64.random(in: 0...UInt64.max))
        guard let m = search.run() else { return game.position.legalMoves().first }
        let legal = game.position.legalMoves()
        return legal.contains(m) ? m : legal.first
    }

    /// How good a position is for the side to move, and the move that keeps it so.
    /// Used for hints and for reviewing a finished game.
    public static func evaluate(_ position: Position, history: [Position] = [], seconds: Double) -> Evaluation {
        let legal = position.legalMoves()
        if legal.isEmpty {
            return Evaluation(best: nil, score: position.isInCheck ? -Evaluation.mateScore : 0, mateIn: position.isInCheck ? 0 : nil)
        }
        var search = Search(position: position, history: history[...], level: .master, seed: 1, timeLimit: seconds)
        guard let (m, score) = search.analyze() else { return Evaluation(best: legal.first, score: 0, mateIn: nil) }
        let best = legal.contains(m) ? m : legal.first
        let mate = abs(score) > Search.mate - 1000 ? (Search.mate - abs(score) + 1) / 2 * (score > 0 ? 1 : -1) : nil
        return Evaluation(best: best, score: score, mateIn: mate)
    }

    /// Leaf count of the engine's own move generator (for tests).
    static func perft(_ position: Position, depth: Int) -> Int {
        var b = SearchBoard(position)
        return b.perft(depth)
    }
}

/// The engine's view of a position, from the side to move.
public struct Evaluation: Sendable, Equatable {
    public static let mateScore = 30_000
    public let best: Move?
    /// Centipawns for the side to move; near ±30000 when a mate is found.
    public let score: Int
    /// Moves to mate: positive when the side to move mates, negative when it is mated.
    public let mateIn: Int?
}

// MARK: - Board

struct SMove: Equatable {
    var from: Int
    var to: Int
    var promo: Int8 = 0        // piece type 2...5 when promoting
    var flags: UInt8 = 0       // 1 capture, 2 en passant, 4 castle, 8 double push
    var order: Int = 0

    static func == (a: SMove, b: SMove) -> Bool { a.from == b.from && a.to == b.to && a.promo == b.promo }
}

private struct Undo {
    var moved: Int8
    var captured: Int8
    var capturedSquare: Int
    var castle: UInt8
    var ep: Int
    var key: UInt64
}

private enum Zobrist {
    static let table: [UInt64] = {
        var s: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> UInt64 {
            s &+= 0x9E37_79B9_7F4A_7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        return (0..<(13 * 64 + 16 + 65 + 1)).map { _ in next() }
    }()
    static func piece(_ p: Int8, _ sq: Int) -> UInt64 { table[(Int(p) + 6) * 64 + sq] }
    static func castle(_ c: UInt8) -> UInt64 { table[13 * 64 + Int(c)] }
    static func ep(_ sq: Int) -> UInt64 { table[13 * 64 + 16 + (sq + 1)] }
    static let side: UInt64 = table[13 * 64 + 16 + 65]
}

private let knightTargets: [[Int]] = (0..<64).map { s in
    let f = s % 8, r = s / 8
    return [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)].compactMap { df, dr in
        let nf = f + df, nr = r + dr
        return (0..<8).contains(nf) && (0..<8).contains(nr) ? nr * 8 + nf : nil
    }
}
private let kingTargets: [[Int]] = (0..<64).map { s in
    let f = s % 8, r = s / 8
    return [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)].compactMap { df, dr in
        let nf = f + df, nr = r + dr
        return (0..<8).contains(nf) && (0..<8).contains(nr) ? nr * 8 + nf : nil
    }
}
/// Rays from each square in each of 8 directions: 0-3 orthogonal, 4-7 diagonal.
private let rays: [[[Int]]] = (0..<64).map { s in
    let f = s % 8, r = s / 8
    return [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)].map { df, dr in
        var out: [Int] = []
        var nf = f + df, nr = r + dr
        while (0..<8).contains(nf) && (0..<8).contains(nr) {
            out.append(nr * 8 + nf)
            nf += df; nr += dr
        }
        return out
    }
}
/// Castling rights kept when a move touches a square.
private let castleMask: [UInt8] = (0..<64).map { s in
    switch s {
    case 0: return 0b1101      // a1: white queenside
    case 7: return 0b1110      // h1: white kingside
    case 4: return 0b1100      // e1: both white
    case 56: return 0b0111     // a8: black queenside
    case 63: return 0b1011     // h8: black kingside
    case 60: return 0b0011     // e8: both black
    default: return 0b1111
    }
}

struct SearchBoard {
    /// +1...+6 white pawn...king, negative for black, 0 empty. Index = rank * 8 + file.
    var sq: [Int8]
    var white: Bool
    var castle: UInt8          // 1 white kingside, 2 white queenside, 4 black kingside, 8 black queenside
    var ep: Int
    var key: UInt64 = 0
    private var undos: [Undo] = []

    init(_ p: Position) {
        sq = [Int8](repeating: 0, count: 64)
        for i in 0..<64 {
            guard let piece = p.board[i] else { continue }
            let t: Int8
            switch piece.kind {
            case .pawn: t = 1
            case .knight: t = 2
            case .bishop: t = 3
            case .rook: t = 4
            case .queen: t = 5
            case .king: t = 6
            }
            sq[i] = piece.color == .white ? t : -t
        }
        white = p.sideToMove == .white
        var c: UInt8 = 0
        if p.castling.contains(.whiteKingside) { c |= 1 }
        if p.castling.contains(.whiteQueenside) { c |= 2 }
        if p.castling.contains(.blackKingside) { c |= 4 }
        if p.castling.contains(.blackQueenside) { c |= 8 }
        castle = c
        ep = p.enPassant?.index ?? -1
        undos.reserveCapacity(128)
        key = computeKey()
    }

    func computeKey() -> UInt64 {
        var k: UInt64 = 0
        for i in 0..<64 where sq[i] != 0 { k ^= Zobrist.piece(sq[i], i) }
        k ^= Zobrist.castle(castle)
        k ^= Zobrist.ep(ep)
        if !white { k ^= Zobrist.side }
        return k
    }

    func kingSquare(white w: Bool) -> Int {
        let k: Int8 = w ? 6 : -6
        for i in 0..<64 where sq[i] == k { return i }
        return 0
    }

    /// Whether `s` is attacked by the side given.
    func attacked(_ s: Int, byWhite w: Bool) -> Bool {
        let sign: Int8 = w ? 1 : -1
        let f = s % 8
        // pawns attack diagonally forward, so look one rank back toward the attacker
        let back = w ? -8 : 8
        if f > 0, s + back - 1 >= 0, s + back - 1 < 64, sq[s + back - 1] == sign { return true }
        if f < 7, s + back + 1 >= 0, s + back + 1 < 64, sq[s + back + 1] == sign { return true }
        for t in knightTargets[s] where sq[t] == 2 * sign { return true }
        for t in kingTargets[s] where sq[t] == 6 * sign { return true }
        for d in 0..<8 {
            for t in rays[s][d] {
                let p = sq[t]
                if p == 0 { continue }
                if p * sign > 0 {
                    let k = abs(p)
                    if k == 5 || (d < 4 && k == 4) || (d >= 4 && k == 3) { return true }
                }
                break
            }
        }
        return false
    }

    var inCheck: Bool { attacked(kingSquare(white: white), byWhite: !white) }

    // MARK: Generation

    func generate(into moves: inout [SMove], capturesOnly: Bool) {
        let sign: Int8 = white ? 1 : -1
        for s in 0..<64 {
            let p = sq[s] * sign
            guard p > 0 else { continue }
            switch p {
            case 1: pawnMoves(s, into: &moves, capturesOnly: capturesOnly)
            case 2:
                for t in knightTargets[s] { add(s, t, into: &moves, capturesOnly: capturesOnly) }
            case 6:
                for t in kingTargets[s] { add(s, t, into: &moves, capturesOnly: capturesOnly) }
                if !capturesOnly { castling(s, into: &moves) }
            default:
                let dirs = p == 3 ? 4..<8 : (p == 4 ? 0..<4 : 0..<8)
                for d in dirs {
                    for t in rays[s][d] {
                        let q = sq[t]
                        if q == 0 {
                            if !capturesOnly { moves.append(SMove(from: s, to: t)) }
                            continue
                        }
                        if q * sign < 0 { moves.append(SMove(from: s, to: t, flags: 1)) }
                        break
                    }
                }
            }
        }
    }

    private func add(_ s: Int, _ t: Int, into moves: inout [SMove], capturesOnly: Bool) {
        let q = sq[t]
        let sign: Int8 = white ? 1 : -1
        if q == 0 {
            if !capturesOnly { moves.append(SMove(from: s, to: t)) }
        } else if q * sign < 0 {
            moves.append(SMove(from: s, to: t, flags: 1))
        }
    }

    private func pawnMoves(_ s: Int, into moves: inout [SMove], capturesOnly: Bool) {
        let dir = white ? 8 : -8
        let rank = s / 8
        let startRank = white ? 1 : 6
        let lastRank = white ? 6 : 1
        let f = s % 8
        let sign: Int8 = white ? 1 : -1
        let one = s + dir
        func push(_ t: Int, _ flags: UInt8) {
            if rank == lastRank {
                for promo: Int8 in [5, 2, 4, 3] {
                    if capturesOnly && promo != 5 && flags & 1 == 0 { continue }
                    moves.append(SMove(from: s, to: t, promo: promo, flags: flags))
                }
            } else {
                moves.append(SMove(from: s, to: t, flags: flags))
            }
        }
        if sq[one] == 0 && (!capturesOnly || rank == lastRank) {
            push(one, 0)
            if !capturesOnly && rank == startRank && sq[one + dir] == 0 {
                moves.append(SMove(from: s, to: one + dir, flags: 8))
            }
        }
        for df in [-1, 1] {
            let nf = f + df
            guard (0..<8).contains(nf) else { continue }
            let t = one + df
            if sq[t] * sign < 0 {
                push(t, 1)
            } else if t == ep {
                moves.append(SMove(from: s, to: t, flags: 1 | 2))
            }
        }
    }

    private func castling(_ s: Int, into moves: inout [SMove]) {
        let w = white
        let base = w ? 0 : 56
        guard s == base + 4 else { return }
        let ks: UInt8 = w ? 1 : 4, qs: UInt8 = w ? 2 : 8
        let rook: Int8 = w ? 4 : -4
        if castle & ks != 0, sq[base + 5] == 0, sq[base + 6] == 0, sq[base + 7] == rook,
           !attacked(base + 4, byWhite: !w), !attacked(base + 5, byWhite: !w), !attacked(base + 6, byWhite: !w) {
            moves.append(SMove(from: s, to: base + 6, flags: 4))
        }
        if castle & qs != 0, sq[base + 3] == 0, sq[base + 2] == 0, sq[base + 1] == 0, sq[base] == rook,
           !attacked(base + 4, byWhite: !w), !attacked(base + 3, byWhite: !w), !attacked(base + 2, byWhite: !w) {
            moves.append(SMove(from: s, to: base + 2, flags: 4))
        }
    }

    // MARK: Make / unmake

    mutating func make(_ m: SMove) {
        let moved = sq[m.from]
        var captured = sq[m.to]
        var capSq = m.to
        if m.flags & 2 != 0 {
            capSq = m.to + (white ? -8 : 8)
            captured = sq[capSq]
        }
        undos.append(Undo(moved: moved, captured: captured, capturedSquare: capSq, castle: castle, ep: ep, key: key))

        key ^= Zobrist.castle(castle) ^ Zobrist.ep(ep) ^ Zobrist.side
        if captured != 0 {
            key ^= Zobrist.piece(captured, capSq)
            sq[capSq] = 0
        }
        let placed: Int8 = m.promo != 0 ? (white ? m.promo : -m.promo) : moved
        key ^= Zobrist.piece(moved, m.from) ^ Zobrist.piece(placed, m.to)
        sq[m.from] = 0
        sq[m.to] = placed
        if m.flags & 4 != 0 {
            let base = white ? 0 : 56
            let (rf, rt) = m.to == base + 6 ? (base + 7, base + 5) : (base, base + 3)
            let rook = sq[rf]
            key ^= Zobrist.piece(rook, rf) ^ Zobrist.piece(rook, rt)
            sq[rt] = rook
            sq[rf] = 0
        }
        castle &= castleMask[m.from] & castleMask[m.to]
        ep = m.flags & 8 != 0 ? (m.from + m.to) / 2 : -1
        key ^= Zobrist.castle(castle) ^ Zobrist.ep(ep)
        white.toggle()
    }

    mutating func unmake(_ m: SMove) {
        guard let u = undos.popLast() else { return }
        white.toggle()
        sq[m.from] = u.moved
        sq[m.to] = 0
        if u.captured != 0 { sq[u.capturedSquare] = u.captured }
        if m.flags & 4 != 0 {
            let base = white ? 0 : 56
            let (rf, rt) = m.to == base + 6 ? (base + 7, base + 5) : (base, base + 3)
            sq[rf] = sq[rt]
            sq[rt] = 0
        }
        castle = u.castle
        ep = u.ep
        key = u.key
    }

    mutating func perft(_ depth: Int) -> Int {
        var moves: [SMove] = []
        generate(into: &moves, capturesOnly: false)
        var n = 0
        let mover = white
        for m in moves {
            make(m)
            if !attacked(kingSquare(white: mover), byWhite: !mover) {
                n += depth == 1 ? 1 : perft(depth - 1)
            }
            unmake(m)
        }
        return n
    }

    // MARK: Evaluation

    static let value: [Int] = [0, 100, 320, 330, 500, 900, 0]

    /// Static evaluation from the side to move's point of view, in centipawns.
    func evaluate() -> Int {
        var mg = 0, eg = 0, phase = 0
        var bishops = [0, 0]
        for i in 0..<64 {
            let p = sq[i]
            if p == 0 { continue }
            let t = Int(abs(p))
            let isWhite = p > 0
            let f = i % 8, r = i / 8
            let idx = isWhite ? (7 - r) * 8 + f : r * 8 + f
            let s = isWhite ? 1 : -1
            let base = SearchBoard.value[t]
            switch t {
            case 1: mg += s * (base + pawnTable[idx]); eg += s * (base + pawnTable[idx] + (isWhite ? r : 7 - r) * 8)
            case 2: mg += s * (base + knightTable[idx]); eg += s * (base + knightTable[idx]); phase += 1
            case 3: mg += s * (base + bishopTable[idx]); eg += s * (base + bishopTable[idx]); phase += 1
                bishops[isWhite ? 0 : 1] += 1
            case 4: mg += s * (base + rookTable[idx]); eg += s * (base + rookTable[idx]); phase += 2
            case 5: mg += s * (base + queenTable[idx]); eg += s * (base + queenTable[idx]); phase += 4
            default: mg += s * kingMidTable[idx]; eg += s * kingEndTable[idx]
            }
        }
        if bishops[0] >= 2 { mg += 30; eg += 40 }
        if bishops[1] >= 2 { mg -= 30; eg -= 40 }
        let ph = min(phase, 24)
        let score = (mg * ph + eg * (24 - ph)) / 24
        return white ? score : -score
    }
}

// Piece-square tables (after Tomasz Michniewski's simplified evaluation), indexed from
// the piece owner's side with a8 = 0 for White.
private let pawnTable = [
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
]
private let knightTable = [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
]
private let bishopTable = [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
]
private let rookTable = [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
]
private let queenTable = [
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
]
private let kingMidTable = [
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
]
private let kingEndTable = [
    -50, -40, -30, -20, -20, -30, -40, -50,
    -30, -20, -10, 0, 0, -10, -20, -30,
    -30, -10, 20, 30, 30, 20, -10, -30,
    -30, -10, 30, 40, 40, 30, -10, -30,
    -30, -10, 30, 40, 40, 30, -10, -30,
    -30, -10, 20, 30, 30, 20, -10, -30,
    -30, -30, 0, 0, 0, 0, -30, -30,
    -50, -30, -30, -30, -30, -30, -30, -50,
]

// MARK: - Search

private struct Search {
    var board: SearchBoard
    let level: BotLevel
    var rng: SplitMix
    var history: [UInt64]          // keys of earlier positions in the game and on the current line
    var killers = [[SMove]](repeating: [], count: 128)
    var nodes = 0
    var stopped = false
    /// Deepest iteration fully completed so far.
    var depthReached = 0
    let deadline: ContinuousClock.Instant
    let clock = ContinuousClock()

    static let mate = 30_000

    init(position: Position, history: ArraySlice<Position>, level: BotLevel, seed: UInt64, timeLimit: Double? = nil) {
        board = SearchBoard(position)
        self.level = level
        rng = SplitMix(seed)
        self.history = history.map { SearchBoard($0).key }
        deadline = clock.now + .milliseconds(Int((timeLimit ?? level.timeLimit) * 1000))
    }

    mutating func run() -> Move? {
        let rootMoves = legalRootMoves()
        guard !rootMoves.isEmpty else { return nil }
        if rootMoves.count == 1 { return export(rootMoves[0].move) }
        return export(choose(from: deepen(rootMoves)))
    }

    /// The best move and its exact score, for analysis.
    mutating func analyze() -> (Move, Int)? {
        let rootMoves = legalRootMoves()
        guard !rootMoves.isEmpty else { return nil }
        let scored = deepen(rootMoves)
        return (export(scored[0].move), scored[0].score)
    }

    /// Iterative deepening over the root moves; returns them best first.
    private mutating func deepen(_ moves: [(move: SMove, score: Int)]) -> [(move: SMove, score: Int)] {
        var rootMoves = moves

        var completed: [(move: SMove, score: Int)] = []
        var depth = 1
        while depth <= level.maxDepth {
            var scored: [(move: SMove, score: Int)] = []
            var alpha = -Search.mate - 1
            for entry in rootMoves {
                board.make(entry.move)
                history.append(board.key)
                // a wider window for move variety at lower levels; exact scores matter there
                let floor = level.tolerance > 0 ? -Search.mate - 1 : alpha
                let raw = -negamax(depth - 1, -Search.mate - 1, -floor, ply: 1, extensions: 0)
                history.removeLast()
                board.unmake(entry.move)
                if stopped { break }
                // with a narrowed window, a move that fails low only proves it is no better than
                // the best so far; record it strictly below so it can never tie with the best
                let score = level.tolerance == 0 && !scored.isEmpty && raw <= alpha ? min(raw, alpha - 1) : raw
                scored.append((entry.move, score))
                alpha = max(alpha, score)
            }
            if stopped { break }
            scored.sort { $0.score > $1.score }
            completed = scored
            depthReached = depth
            rootMoves = scored.map { (move: $0.move, score: $0.score) }
            if scored[0].score > Search.mate - 100 { break }      // forced mate found
            if depth >= 2, clock.now > deadline { break }
            depth += 1
        }
        if completed.isEmpty { completed = rootMoves.map { ($0.move, $0.score) } }
        return completed
    }

    private mutating func choose(from scored: [(move: SMove, score: Int)]) -> SMove {
        let best = scored[0].score
        let tolerance = abs(best) > Search.mate - 1000 ? 0 : level.tolerance
        let candidates = scored.filter { $0.score >= best - tolerance }
        guard candidates.count > 1 else { return scored[0].move }
        // Variety never stretches to putting off a queen promotion that is among the best moves:
        // a deep search can score "promote now" and "promote next move" alike, but nobody plays that way.
        if let promotion = candidates.first(where: { $0.move.promo == 5 }) { return promotion.move }
        // prefer better moves, but let close ones through
        let weights = candidates.map { Double(tolerance + 1 - (best - $0.score)) }
        var pick = rng.nextDouble() * weights.reduce(0, +)
        for (i, w) in weights.enumerated() {
            pick -= w
            if pick <= 0 { return candidates[i].move }
        }
        return candidates[0].move
    }

    private mutating func legalRootMoves() -> [(move: SMove, score: Int)] {
        var moves: [SMove] = []
        board.generate(into: &moves, capturesOnly: false)
        let mover = board.white
        var out: [(move: SMove, score: Int)] = []
        for m in moves {
            board.make(m)
            let ok = !board.attacked(board.kingSquare(white: mover), byWhite: !mover)
            board.unmake(m)
            if ok { out.append((m, 0)) }
        }
        // shuffle so equal moves don't always resolve the same way, then order captures first
        for i in stride(from: out.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            out.swapAt(i, j)
        }
        return out.sorted { mvvLva($0.move) > mvvLva($1.move) }
    }

    private func mvvLva(_ m: SMove) -> Int {
        var score = 0
        if m.flags & 1 != 0 {
            let victim = m.flags & 2 != 0 ? 1 : Int(abs(board.sq[m.to]))
            score = 10 * SearchBoard.value[victim] - SearchBoard.value[Int(abs(board.sq[m.from]))] / 10 + 100_000
        }
        if m.promo == 5 { score += 90_000 }
        return score
    }

    private mutating func checkTime() {
        nodes += 1
        // The first full pass (depth 1 and 2) always completes, however slow the device, so
        // there is always a properly scored move to choose from.
        if nodes & 1023 == 0, depthReached >= 2, clock.now > deadline { stopped = true }
    }

    private mutating func negamax(_ depth: Int, _ alphaIn: Int, _ beta: Int, ply: Int, extensions: Int) -> Int {
        checkTime()
        if stopped { return 0 }
        if history.dropLast().contains(board.key) { return 0 }        // repetition
        if depth <= 0 { return quiesce(alphaIn, beta, ply: ply) }

        var alpha = alphaIn
        var moves: [SMove] = []
        moves.reserveCapacity(48)
        board.generate(into: &moves, capturesOnly: false)
        for i in moves.indices {
            var o = mvvLva(moves[i])
            if o == 0, ply < killers.count, killers[ply].contains(moves[i]) { o = 50_000 }
            moves[i].order = o
        }
        moves.sort { $0.order > $1.order }

        let mover = board.white
        let inCheck = board.inCheck
        var legal = 0
        var best = -Search.mate - 1
        for m in moves {
            board.make(m)
            if board.attacked(board.kingSquare(white: mover), byWhite: !mover) {
                board.unmake(m)
                continue
            }
            legal += 1
            history.append(board.key)
            let givesCheck = board.inCheck
            let ext = givesCheck && extensions < 4 ? 1 : 0
            let score = -negamax(depth - 1 + ext, -beta, -alpha, ply: ply + 1, extensions: extensions + ext)
            history.removeLast()
            board.unmake(m)
            if stopped { return 0 }
            if score > best { best = score }
            if score > alpha { alpha = score }
            if alpha >= beta {
                if m.flags & 1 == 0, ply < killers.count {
                    killers[ply].insert(m, at: 0)
                    if killers[ply].count > 2 { killers[ply].removeLast() }
                }
                break
            }
        }
        if legal == 0 { return inCheck ? -Search.mate + ply : 0 }
        return best
    }

    private mutating func quiesce(_ alphaIn: Int, _ beta: Int, ply: Int) -> Int {
        checkTime()
        if stopped { return 0 }
        let stand = board.evaluate()
        if stand >= beta { return stand }
        var alpha = max(alphaIn, stand)
        if ply > 40 { return stand }

        var moves: [SMove] = []
        board.generate(into: &moves, capturesOnly: true)
        for i in moves.indices { moves[i].order = mvvLva(moves[i]) }
        moves.sort { $0.order > $1.order }
        let mover = board.white
        for m in moves {
            board.make(m)
            if board.attacked(board.kingSquare(white: mover), byWhite: !mover) {
                board.unmake(m)
                continue
            }
            let score = -quiesce(-beta, -alpha, ply: ply + 1)
            board.unmake(m)
            if stopped { return 0 }
            if score >= beta { return score }
            if score > alpha { alpha = score }
        }
        return alpha
    }

    private func export(_ m: SMove) -> Move {
        let promo: PieceKind?
        switch m.promo {
        case 2: promo = .knight
        case 3: promo = .bishop
        case 4: promo = .rook
        case 5: promo = .queen
        default: promo = nil
        }
        return Move(from: Square(index: m.from), to: Square(index: m.to), promotion: promo)
    }
}

/// A small, fast, seedable random generator.
private struct SplitMix {
    var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
