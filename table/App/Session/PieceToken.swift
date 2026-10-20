import SwiftUI
import ChessCore

/// A physical piece on the table. Its identity survives moves, so SwiftUI can animate it
/// from square to square instead of redrawing the board.
struct PieceToken: Identifiable, Equatable {
    let id: Int
    var piece: Piece
    var square: Square
    /// Taken pieces stay briefly so they can leave gracefully, then are removed.
    var isCaptured = false
    /// How this token animates its next change (travel, settle, return, undo).
    var motion: Animation?
    /// Bumped whenever the token should animate with `motion`.
    var revision = 0

    static func == (a: PieceToken, b: PieceToken) -> Bool {
        a.id == b.id && a.piece == b.piece && a.square == b.square
            && a.isCaptured == b.isCaptured && a.revision == b.revision
    }
}

enum TokenLayout {
    /// Tokens for every piece in a position.
    static func tokens(for position: Position, nextID: inout Int) -> [PieceToken] {
        Square.all.compactMap { sq in
            guard let p = position[sq] else { return nil }
            defer { nextID += 1 }
            return PieceToken(id: nextID, piece: p, square: sq)
        }
    }

    /// The physical result of a move, without animation details.
    static func apply(_ fx: MoveEffect, to tokens: inout [PieceToken]) {
        tokens.removeAll { $0.isCaptured }
        if let cs = fx.capturedSquare, let ci = tokens.firstIndex(where: { $0.square == cs && $0.piece == fx.captured }) {
            tokens.remove(at: ci)
        }
        if let i = tokens.firstIndex(where: { $0.square == fx.move.from && $0.piece == fx.piece }) {
            tokens[i].square = fx.move.to
            if let promo = fx.promotion { tokens[i].piece = Piece(fx.piece.color, promo) }
        }
        if let rf = fx.rookFrom, let rt = fx.rookTo, let ri = tokens.firstIndex(where: { $0.square == rf }) {
            tokens[ri].square = rt
        }
    }

    /// Matches existing tokens to the squares of `position`, reusing identities by piece type
    /// (nearest first) so a reset reads as pieces gliding home rather than a cut.
    static func regather(_ tokens: [PieceToken], into position: Position, nextID: inout Int) -> [PieceToken] {
        var pool = tokens.filter { !$0.isCaptured }
        var result: [PieceToken] = []
        for sq in Square.all {
            guard let p = position[sq] else { continue }
            let candidates = pool.indices.filter { pool[$0].piece == p }
            if let best = candidates.min(by: { distance(pool[$0].square, sq) < distance(pool[$1].square, sq) }) {
                var t = pool.remove(at: best)
                t.square = sq
                result.append(t)
            } else {
                result.append(PieceToken(id: nextID, piece: p, square: sq))
                nextID += 1
            }
        }
        return result
    }

    static func distance(_ a: Square, _ b: Square) -> Double {
        let df = Double(a.file - b.file), dr = Double(a.rank - b.rank)
        return (df * df + dr * dr).squareRoot()
    }
}
