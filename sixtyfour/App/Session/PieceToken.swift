import SwiftUI
import ChessCore

/// A physical piece on the table. Its identity survives moves, captures and undo, so SwiftUI
/// can animate it from square to square, into a player's tray, and back again.
struct PieceToken: Identifiable, Equatable {
    let id: Int
    var piece: Piece
    var square: Square
    /// Taken pieces leave the board and stand in the capturing player's tray.
    var isCaptured = false
    var capturedBy: PieceColor?
    /// Position in that tray, in order of capture.
    var trayIndex = 0
    /// How this token animates its next change (travel, settle, return, undo).
    var motion: Animation?
    /// Bumped whenever the token should animate with `motion`.
    var revision = 0
    /// Bumped at the moment the piece lands, to play its settle.
    var landing = 0

    static func == (a: PieceToken, b: PieceToken) -> Bool {
        a.id == b.id && a.piece == b.piece && a.square == b.square && a.isCaptured == b.isCaptured
            && a.capturedBy == b.capturedBy && a.trayIndex == b.trayIndex
            && a.revision == b.revision && a.landing == b.landing
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

    static func onBoard(_ tokens: [PieceToken], at square: Square) -> Int? {
        tokens.firstIndex { $0.square == square && !$0.isCaptured }
    }

    /// The physical result of a move, without animation details.
    static func apply(_ fx: MoveEffect, to tokens: inout [PieceToken]) {
        if let cs = fx.capturedSquare, let ci = tokens.firstIndex(where: { $0.square == cs && !$0.isCaptured && $0.piece == fx.captured }) {
            let mover = fx.piece.color
            tokens[ci].isCaptured = true
            tokens[ci].capturedBy = mover
            tokens[ci].trayIndex = tokens.filter { $0.isCaptured && $0.capturedBy == mover && $0.id != tokens[ci].id }.count
        }
        if let i = tokens.firstIndex(where: { $0.square == fx.move.from && !$0.isCaptured && $0.piece == fx.piece }) {
            tokens[i].square = fx.move.to
            if let promo = fx.promotion { tokens[i].piece = Piece(fx.piece.color, promo) }
        }
        if let rf = fx.rookFrom, let rt = fx.rookTo, let ri = onBoard(tokens, at: rf) {
            tokens[ri].square = rt
        }
    }

    /// Matches every token (taken ones included) to the squares of `position`, reusing
    /// identities by piece type, nearest first, so a reset reads as the pieces going home.
    static func regather(_ tokens: [PieceToken], into position: Position, nextID: inout Int) -> [PieceToken] {
        var pool = tokens
        var result: [PieceToken] = []
        for sq in Square.all {
            guard let p = position[sq] else { continue }
            let candidates = pool.indices.filter { pool[$0].piece == p }
            let best = candidates.min { a, b in
                (pool[a].isCaptured ? 1 : 0, distance(pool[a].square, sq)) < (pool[b].isCaptured ? 1 : 0, distance(pool[b].square, sq))
            }
            if let best {
                var t = pool.remove(at: best)
                t.square = sq
                t.isCaptured = false
                t.capturedBy = nil
                t.trayIndex = 0
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
