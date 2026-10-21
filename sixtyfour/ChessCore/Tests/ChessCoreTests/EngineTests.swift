import XCTest
@testable import ChessCore

final class EngineTests: XCTestCase {
    /// The engine's own generator and make/unmake must agree with the reference perft counts.
    func testSearchBoardPerft() {
        let cases: [(String, [Int])] = [
            (Position.startFEN, [20, 400, 8902]),
            ("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", [48, 2039, 97862]),
            ("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", [14, 191, 2812, 43238]),
            ("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", [6, 264, 9467]),
            ("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", [44, 1486, 62379]),
        ]
        for (fen, counts) in cases {
            let p = Position(fen: fen)!
            for (i, n) in counts.enumerated() {
                XCTAssertEqual(Engine.perft(p, depth: i + 1), n, "perft(\(i + 1)) \(fen)")
            }
        }
    }

    func testFindsMateInOne() {
        for level in BotLevel.allCases {
            let g = ChessGame(position: Position(fen: "6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1")!)
            XCTAssertEqual(Engine.bestMove(for: g, level: level, seed: 1), Move(uci: "d1d8"), level.rawValue)
        }
    }

    func testTakesHangingQueen() {
        let g = ChessGame(position: Position(fen: "4k3/8/8/3q4/8/8/3R4/4K3 w - - 0 1")!)
        XCTAssertEqual(Engine.bestMove(for: g, level: .club, seed: 2), Move(uci: "d2d5"))
    }

    func testDoesNotHangQueen() {
        // Black's queen on g4 is attacked by the f3 pawn; the engine moves it.
        let attacked = ChessGame(position: Position(fen: "rnb1kbnr/pppp1ppp/8/4p3/3P2q1/5P2/PPP1P1PP/RNBQKBNR b KQkq - 0 3")!)
        let m = Engine.bestMove(for: attacked, level: .club, seed: 3)!
        XCTAssertEqual(m.from, Square("g4"), "the attacked queen moves")
    }

    func testAlwaysReturnsLegalMoves() {
        var game = ChessGame()
        var plies = 0
        while !game.isOver && plies < 60 {
            let level: BotLevel = plies % 2 == 0 ? .casual : .club
            guard let m = Engine.bestMove(for: game, level: level, seed: UInt64(plies)) else {
                XCTFail("no move in a live game"); return
            }
            XCTAssertTrue(game.position.isLegal(m), "illegal \(m) in \(game.position.fen)")
            game.play(m)
            plies += 1
        }
    }

    func testPromotesWhenItWins() {
        let g = ChessGame(position: Position(fen: "8/P6k/8/8/8/8/8/K7 w - - 0 1")!)
        // Whatever the seed and however deep the search gets, the pawn promotes at once.
        for seed in UInt64(1)...30 {
            XCTAssertEqual(Engine.bestMove(for: g, level: .club, seed: seed), Move(uci: "a7a8q"), "seed \(seed)")
        }
    }

    func testNoMoveWhenGameOver() {
        var g = ChessGame()
        for m in ["f2f3", "e7e5", "g2g4", "d8h4"] { g.play(Move(uci: m)!) }
        XCTAssertNil(Engine.bestMove(for: g, level: .casual))
    }

    func testEvaluationSeesMateAndMaterial() {
        // White mates in one with Qxf7#.
        let mate = Position(fen: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")!
        let e = Engine.evaluate(mate, seconds: 1.0)
        XCTAssertEqual(e.best, Move(uci: "h5f7"))
        XCTAssertEqual(e.mateIn, 1)
        // Black to move, a queen down.
        let down = Position(fen: "4k3/8/8/8/8/8/8/3QK3 b - - 0 1")!
        XCTAssertLessThan(Engine.evaluate(down, seconds: 0.6).score, -600)
    }
}
