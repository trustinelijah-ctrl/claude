import XCTest
@testable import ChessCore

final class PerftTests: XCTestCase {
    /// Counts leaf nodes of the legal move tree; compared against published reference values.
    private func perft(_ pos: Position, _ depth: Int) -> Int {
        let moves = pos.legalMoves()
        if depth == 1 { return moves.count }
        return moves.reduce(0) { $0 + perft(pos.applyingUnchecked($1), depth - 1) }
    }

    private func check(_ fen: String, _ expected: [Int], file: StaticString = #filePath, line: UInt = #line) {
        let pos = Position(fen: fen)!
        for (i, n) in expected.enumerated() {
            XCTAssertEqual(perft(pos, i + 1), n, "perft(\(i + 1)) of \(fen)", file: file, line: line)
        }
    }

    func testStartPosition() { check(Position.startFEN, [20, 400, 8902, 197281]) }

    func testKiwipete() {
        check("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", [48, 2039, 97862])
    }

    func testEndgameEnPassantPins() {
        check("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", [14, 191, 2812, 43238])
    }

    func testPromotionsAndCastlingRights() {
        check("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", [6, 264, 9467])
    }

    func testPosition5() {
        check("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", [44, 1486, 62379])
    }

    func testPosition6() {
        check("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10", [46, 2079, 89890])
    }
}

final class RuleTests: XCTestCase {
    private func game(_ moves: String, from fen: String = Position.startFEN) -> ChessGame {
        var g = ChessGame(position: Position(fen: fen)!)
        for m in moves.split(separator: " ") {
            XCTAssertNotNil(g.play(Move(uci: String(m))!), "illegal \(m)")
        }
        return g
    }

    func testFENRoundTrip() {
        let fens = [Position.startFEN,
                    "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
                    "8/8/8/3pP3/8/8/8/k6K w - d6 0 3"]
        for f in fens { XCTAssertEqual(Position(fen: f)?.fen, f) }
        XCTAssertNil(Position(fen: "not a fen"))
        XCTAssertNil(Position(fen: "8/8/8/8/8/8/8/8 w - - 0 1"), "positions need both kings")
    }

    func testWhiteMovesFirstAndTurnsAlternate() {
        var g = ChessGame()
        XCTAssertEqual(g.sideToMove, .white)
        XCTAssertNil(g.play(Move(uci: "e7e5")!), "black cannot move first")
        XCTAssertNotNil(g.play(Move(uci: "e2e4")!))
        XCTAssertEqual(g.sideToMove, .black)
        XCTAssertNil(g.play(Move(uci: "d2d4")!), "white cannot move twice")
    }

    func testIllegalMovesRejected() {
        var g = ChessGame()
        XCTAssertNil(g.play(Move(uci: "e2e5")!))
        XCTAssertNil(g.play(Move(uci: "b1b3")!))
        XCTAssertNil(g.play(Move(uci: "f1c4")!), "bishop is blocked")
        XCTAssertNil(g.play(Move(uci: "e1e2")!), "own piece on target")
    }

    func testPinnedPieceCannotMove() {
        let pos = Position(fen: "4k3/4r3/8/8/8/8/4B3/4K3 w - - 0 1")!
        XCTAssertTrue(pos.legalMoves(from: Square("e2")!).isEmpty)
    }

    func testMustAnswerCheck() {
        let pos = Position(fen: "4k3/8/8/8/8/8/3P4/r3K3 w - - 0 1")!
        XCTAssertTrue(pos.isInCheck)
        XCTAssertTrue(pos.legalMoves().allSatisfy { pos[$0.from]?.kind == .king })
    }

    func testFoolsMate() {
        let g = game("f2f3 e7e5 g2g4 d8h4")
        XCTAssertEqual(g.result, .checkmate(winner: .black))
        XCTAssertTrue(g.lastMove!.isCheckmate)
        XCTAssertEqual(g.lastMove!.san, "Qh4#")
        XCTAssertTrue(g.legalMoves(from: Square("e2")!).isEmpty, "no moves after the game ends")
    }

    func testScholarsMateSAN() {
        let g = game("e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7")
        XCTAssertEqual(g.history.map(\.san), ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"])
        XCTAssertEqual(g.result, .checkmate(winner: .white))
    }

    func testStalemate() {
        var g = ChessGame(position: Position(fen: "7k/5Q2/6K1/8/8/8/8/8 w - - 0 1")!)
        g.play(Move(uci: "f7f6")!)
        XCTAssertNil(g.result)
        g = ChessGame(position: Position(fen: "7k/8/6K1/8/8/8/8/5Q2 w - - 0 1")!)
        g.play(Move(uci: "f1f7")!)
        XCTAssertEqual(g.result, .draw(.stalemate))
    }

    // MARK: Castling

    func testCastlingBothSides() {
        let fen = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1"
        var g = game("e1g1", from: fen)
        XCTAssertEqual(g.position[Square("g1")!], Piece(.white, .king))
        XCTAssertEqual(g.position[Square("f1")!], Piece(.white, .rook))
        XCTAssertNil(g.position[Square("h1")!])
        XCTAssertTrue(g.lastMove!.effect.isCastle)
        XCTAssertEqual(g.lastMove!.san, "O-O")
        g.play(Move(uci: "e8c8")!)
        XCTAssertEqual(g.position[Square("d8")!], Piece(.black, .rook))
        XCTAssertEqual(g.lastMove!.san, "O-O-O")
        XCTAssertEqual(g.position.castling, [])
    }

    func testCannotCastleOutOfThroughOrIntoCheck() {
        // Out of check.
        var p = Position(fen: "4r1k1/8/8/8/8/8/8/R3K2R w KQ - 0 1")!
        XCTAssertFalse(p.legalMoves().contains(Move(uci: "e1g1")!))
        XCTAssertFalse(p.legalMoves().contains(Move(uci: "e1c1")!))
        // Through check (f1 attacked).
        p = Position(fen: "5rk1/8/8/8/8/8/8/R3K2R w KQ - 0 1")!
        XCTAssertFalse(p.legalMoves().contains(Move(uci: "e1g1")!))
        XCTAssertTrue(p.legalMoves().contains(Move(uci: "e1c1")!))
        // Into check (c1 attacked).
        p = Position(fen: "2r3k1/8/8/8/8/8/8/R3K2R w KQ - 0 1")!
        XCTAssertFalse(p.legalMoves().contains(Move(uci: "e1c1")!))
        XCTAssertTrue(p.legalMoves().contains(Move(uci: "e1g1")!))
        // b1 attacked does not prevent queenside castling.
        p = Position(fen: "1r4k1/8/8/8/8/8/8/R3K2R w KQ - 0 1")!
        XCTAssertTrue(p.legalMoves().contains(Move(uci: "e1c1")!))
    }

    func testCannotCastleThroughPieces() {
        let p = Position(fen: "4k3/8/8/8/8/8/8/RN2K1NR w KQ - 0 1")!
        XCTAssertFalse(p.legalMoves().contains(Move(uci: "e1g1")!))
        XCTAssertFalse(p.legalMoves().contains(Move(uci: "e1c1")!))
    }

    func testCastlingRightsLostAfterKingOrRookMoves() {
        let fen = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1"
        var g = game("h1g1 a8b8 g1h1 b8a8", from: fen)
        XCTAssertFalse(g.position.legalMoves().contains(Move(uci: "e1g1")!), "rook went away and came back")
        XCTAssertTrue(g.position.legalMoves().contains(Move(uci: "e1c1")!))
        g = game("e1f1 e8f8 f1e1 f8e8", from: fen)
        XCTAssertEqual(g.position.castling, [])
    }

    func testCastlingRightLostWhenRookCaptured() {
        let g = game("b2g7 a7a6 g7h8", from: "r3k2r/p5pp/8/8/8/8/1B6/4K3 w kq - 0 1")
        XCTAssertFalse(g.position.castling.contains(.blackKingside))
        XCTAssertTrue(g.position.castling.contains(.blackQueenside))
    }

    // MARK: En passant

    func testEnPassantCapture() {
        var g = game("e2e4 a7a6 e4e5 d7d5")
        XCTAssertEqual(g.position.enPassant, Square("d6"))
        let played = g.play(Move(uci: "e5d6")!)
        XCTAssertNotNil(played)
        XCTAssertTrue(played!.effect.isEnPassant)
        XCTAssertEqual(played!.effect.capturedSquare, Square("d5"))
        XCTAssertNil(g.position[Square("d5")!])
        XCTAssertEqual(played!.san, "exd6")
    }

    func testEnPassantOnlyImmediately() {
        var g = game("e2e4 a7a6 e4e5 d7d5 h2h3 h7h6")
        XCTAssertNil(g.play(Move(uci: "e5d6")!))
    }

    func testEnPassantIllegalWhenItExposesKing() {
        // Capturing would remove both pawns from the fifth rank and expose the king to the rook.
        let p = Position(fen: "8/8/8/KPp4r/8/8/8/7k w - c6 0 1")!
        XCTAssertFalse(p.legalMoves().contains(Move(uci: "b5c6")!))
    }

    // MARK: Promotion

    func testPromotionChoices() {
        let p = Position(fen: "8/P6k/8/8/8/8/8/K7 w - - 0 1")!
        let promos = p.legalMoves(from: Square("a7")!)
        XCTAssertEqual(Set(promos.compactMap(\.promotion)), Set(PieceKind.promotionChoices))
        XCTAssertFalse(p.isLegal(Move(uci: "a7a8")!), "promotion piece is required")
        var g = ChessGame(position: p)
        let played = g.play(Move(uci: "a7a8n")!)
        XCTAssertEqual(g.position[Square("a8")!], Piece(.white, .knight))
        XCTAssertEqual(played?.san, "a8=N")
    }

    func testCapturePromotionWithCheck() {
        var g = ChessGame(position: Position(fen: "1r5k/P7/8/8/8/8/8/K7 w - - 0 1")!)
        let played = g.play(Move(uci: "a7b8q")!)
        XCTAssertEqual(played?.san, "axb8=Q+")
        XCTAssertEqual(played?.effect.captured, Piece(.black, .rook))
    }

    // MARK: Draws

    func testInsufficientMaterial() {
        XCTAssertTrue(Position(fen: "8/8/8/4k3/8/8/8/4K3 w - - 0 1")!.hasInsufficientMaterial)
        XCTAssertTrue(Position(fen: "8/8/8/4k3/8/8/8/2B1K3 w - - 0 1")!.hasInsufficientMaterial)
        XCTAssertTrue(Position(fen: "8/8/8/4k3/8/8/8/1N2K3 w - - 0 1")!.hasInsufficientMaterial)
        XCTAssertTrue(Position(fen: "8/8/8/2b1k3/8/8/8/2B1K3 w - - 0 1")!.hasInsufficientMaterial,
                      "bishops on the same colour")
        XCTAssertFalse(Position(fen: "8/8/8/1b2k3/8/8/8/2B1K3 w - - 0 1")!.hasInsufficientMaterial,
                       "bishops on opposite colours")
        XCTAssertFalse(Position(fen: "8/8/8/4k3/8/8/8/1NN1K3 w - - 0 1")!.hasInsufficientMaterial)
        XCTAssertFalse(Position(fen: "8/8/8/4k3/8/8/4P3/4K3 w - - 0 1")!.hasInsufficientMaterial)
    }

    func testCaptureIntoInsufficientMaterialEndsGame() {
        var g = ChessGame(position: Position(fen: "8/8/8/8/8/8/6k1/4K2R b - - 0 1")!)
        XCTAssertNil(g.result)
        g.play(Move(uci: "g2h1")!)
        XCTAssertEqual(g.result, .draw(.insufficientMaterial))
    }

    func testThreefoldIsClaimableAndFivefoldIsAutomatic() {
        var g = ChessGame()
        let cycle = ["g1f3", "g8f6", "f3g1", "f6g8"]
        for m in cycle { g.play(Move(uci: m)!) }
        XCTAssertEqual(g.repetitionCount, 2)
        XCTAssertFalse(g.canClaimThreefold)
        for m in cycle { g.play(Move(uci: m)!) }
        XCTAssertEqual(g.repetitionCount, 3)
        XCTAssertTrue(g.canClaimThreefold)
        XCTAssertNil(g.result, "threefold is a claim, not automatic")

        var claimed = g
        XCTAssertTrue(claimed.claimDraw())
        XCTAssertEqual(claimed.result, .draw(.threefoldRepetition))

        for m in cycle + cycle { g.play(Move(uci: m)!) }
        XCTAssertEqual(g.result, .draw(.fivefoldRepetition))
    }

    func testRepetitionIgnoresUncapturableEnPassantSquare() {
        // After 1.e4 the e3 square is not capturable, so the position after 1.e4 counts as repeated
        // even though FEN records an en-passant square only the first time.
        let g = game("e2e4 g8f6 g1f3 f6g8 f3g1 g8f6 g1f3 f6g8 f3g1")
        XCTAssertEqual(g.repetitionCount, 3)
        XCTAssertTrue(g.canClaimThreefold)
    }

    func testFiftyAndSeventyFiveMoveRules() {
        var g = ChessGame(position: Position(fen: "8/8/3k4/8/8/2RK4/8/8 w - - 99 80")!)
        XCTAssertFalse(g.canClaimFiftyMoveRule)
        g.play(Move(uci: "c3c4")!)
        XCTAssertTrue(g.canClaimFiftyMoveRule)
        XCTAssertNil(g.result)
        XCTAssertTrue(g.claimDraw())
        XCTAssertEqual(g.result, .draw(.fiftyMoveRule))

        g = ChessGame(position: Position(fen: "8/8/3k4/8/8/2RK4/8/8 w - - 149 80")!)
        g.play(Move(uci: "c3c4")!)
        XCTAssertEqual(g.result, .draw(.seventyFiveMoveRule))
    }

    func testCheckmateTakesPrecedenceOverSeventyFiveMoves() {
        var g = ChessGame(position: Position(fen: "k7/8/1K6/8/8/8/8/7R w - - 149 90")!)
        g.play(Move(uci: "h1h8")!)
        XCTAssertEqual(g.result, .checkmate(winner: .white))
    }

    // MARK: Undo, resignation, persistence

    func testUndoRestoresEverything() {
        var g = game("e2e4 d7d5 e4d5 d8d5")
        let before = g.positions[2]
        g.undo(); g.undo()
        XCTAssertEqual(g.position, before)
        XCTAssertEqual(g.history.count, 2)
        while g.undo() != nil {}
        XCTAssertEqual(g.position, .start)
    }

    func testUndoAfterCheckmateReopensGame() {
        var g = game("f2f3 e7e5 g2g4 d8h4")
        XCTAssertTrue(g.isOver)
        g.undo()
        XCTAssertFalse(g.isOver)
        XCTAssertEqual(g.sideToMove, .black)
    }

    func testResignationAndWithdrawal() {
        var g = game("e2e4")
        g.resign(.black)
        XCTAssertEqual(g.result, .resignation(winner: .white))
        XCTAssertNil(g.play(Move(uci: "e7e5")!))
        XCTAssertNil(g.undo(), "first undo withdraws the resignation")
        XCTAssertNil(g.result)
        XCTAssertEqual(g.history.count, 1)
    }

    func testCodableRoundTrip() throws {
        var g = game("e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 e1g1")
        g.resign(.black)
        let data = try JSONEncoder().encode(g)
        let back = try JSONDecoder().decode(ChessGame.self, from: data)
        XCTAssertEqual(back.position, g.position)
        XCTAssertEqual(back.history, g.history)
        XCTAssertEqual(back.result, g.result)
    }

    func testDisambiguationSAN() {
        let p = Position(fen: "4k3/8/8/8/8/8/8/R4RK1 w - - 0 1")!
        XCTAssertEqual(p.san(for: Move(uci: "a1d1")!), "Rad1")
        let q = Position(fen: "4k3/8/8/R7/8/8/8/R3K3 w - - 0 1")!
        XCTAssertEqual(q.san(for: Move(uci: "a1a3")!), "R1a3")
        let n = Position(fen: "7k/2N5/8/8/8/2N1N3/8/4K3 w - - 0 1")!
        XCTAssertEqual(n.san(for: Move(uci: "c3d5")!), "Nc3d5")
    }
}
