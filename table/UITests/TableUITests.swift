import XCTest

/// Drives the real app with taps and drags, the way two people at a table would.
final class TableUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(moves: String? = nil, extra: [String] = []) {
        app.launchArguments = ["-fresh", "YES", "-soundEnabled", "NO"] + extra
        if let moves { app.launchArguments += ["-moves", moves] }
        app.launch()
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        settle()
    }

    private var board: XCUIElement { app.descendants(matching: .any)["board"].firstMatch }

    private var boardValue: String { (board.value as? String) ?? "" }

    private func settle(_ seconds: TimeInterval = 0.6) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    /// Screen point at the centre of a square, using the same geometry as the app.
    private func point(_ name: String) -> XCUICoordinate {
        let frame = board.frame
        let size = frame.width
        let rim = max(10, (size * 0.036).rounded())
        let sq = (size - 2 * rim) / 8
        let chars = Array(name)
        let file = CGFloat(Int(chars[0].asciiValue!) - 97)
        let rank = CGFloat(Int(chars[1].asciiValue!) - 49)
        let x = rim + (file + 0.5) * sq
        let y = rim + (7 - rank + 0.5) * sq
        return board.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    private func tap(_ from: String, _ to: String) {
        point(from).tap()
        settle(0.15)
        point(to).tap()
        settle(0.5)
    }

    private func drag(_ from: String, _ to: String) {
        // The app lifts a dragged piece about a third of a square above the finger so the
        // finger does not hide it; aim the finger that much below the target, as a player would.
        let size = board.frame.width
        let rim = max(10, (size * 0.036).rounded())
        let sq = (size - 2 * rim) / 8
        let isBlack = Int(Array(from)[1].asciiValue!) - 49 >= 4
        let compensate = CGVector(dx: 0, dy: (isBlack ? -1 : 1) * sq * 0.34)
        point(from).press(forDuration: 0.12, thenDragTo: point(to).withOffset(compensate))
        settle(0.5)
    }

    func testOpensStraightToAPlayableBoard() {
        launch()
        XCTAssertTrue(boardValue.hasPrefix("White to move. 0 moves played"), boardValue)
        XCTAssertTrue(app.otherElements["panel-white"].exists)
        XCTAssertTrue(app.otherElements["panel-black"].exists)
    }

    func testTapToMoveThenDragToMove() {
        launch()
        tap("e2", "e4")
        XCTAssertTrue(boardValue.contains("Black to move. 1 moves played. Last move e4."), boardValue)
        drag("e7", "e5")
        XCTAssertTrue(boardValue.contains("2 moves played. Last move e5."), boardValue)
        drag("g1", "f3")
        XCTAssertTrue(boardValue.contains("Last move Nf3."), boardValue)
    }

    func testIllegalDropIsRejected() {
        launch()
        drag("e2", "e5")
        XCTAssertTrue(boardValue.hasPrefix("White to move. 0 moves played"), boardValue)
        tap("b1", "b3")
        XCTAssertTrue(boardValue.hasPrefix("White to move. 0 moves played"), boardValue)
        // Black cannot move first.
        drag("e7", "e5")
        XCTAssertTrue(boardValue.hasPrefix("White to move. 0 moves played"), boardValue)
    }

    func testTapAgainDeselects() {
        launch()
        point("e2").tap()
        settle(0.2)
        point("e2").tap()
        settle(0.2)
        point("e4").tap()
        settle(0.4)
        XCTAssertTrue(boardValue.hasPrefix("White to move. 0 moves played"), boardValue)
    }

    func testCaptureAndUndo() {
        launch()
        tap("e2", "e4")
        tap("d7", "d5")
        tap("e4", "d5")
        XCTAssertTrue(boardValue.contains("Last move exd5."), boardValue)
        app.otherElements["panel-white"].buttons["Undo"].tap()
        settle()
        XCTAssertTrue(boardValue.contains("White to move. 2 moves played. Last move d5."), boardValue)
    }

    func testCastling() {
        launch(moves: "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6")
        drag("e1", "g1")
        XCTAssertTrue(boardValue.contains("Last move O-O."), boardValue)
    }

    func testPromotionPicker() {
        launch(moves: "a2a4 b7b5 a4b5 a7a6 b5a6 c8b7 a6b7 b8c6")
        tap("b7", "a8")
        let queen = app.buttons["Promote to queen"]
        XCTAssertTrue(queen.waitForExistence(timeout: 3))
        app.buttons["Promote to knight"].tap()
        settle()
        XCTAssertTrue(boardValue.contains("Last move bxa8=N."), boardValue)
    }

    func testCheckmateShowsResultForBothPlayers() {
        launch()
        tap("f2", "f3")
        tap("e7", "e5")
        tap("g2", "g4")
        drag("d8", "h4")
        XCTAssertTrue(boardValue.hasPrefix("Checkmate."), boardValue)
        let result = app.otherElements["result"]
        XCTAssertTrue(result.waitForExistence(timeout: 4))
        let again = result.buttons.matching(NSPredicate(format: "label == 'Play Again'"))
        XCTAssertEqual(again.count, 2, "one for each player")
        again.element(boundBy: 1).tap()
        settle(1.0)
        XCTAssertTrue(boardValue.hasPrefix("White to move. 0 moves played"), boardValue)
    }

    func testSettingsOpenForEitherPlayer() {
        launch()
        app.otherElements["panel-black"].buttons["Settings"].tap()
        XCTAssertTrue(app.otherElements["settings"].waitForExistence(timeout: 2))
        app.buttons["Ivory & Slate"].tap()
        app.buttons["Done"].tap()
        settle()
        XCTAssertFalse(app.otherElements["settings"].exists)
    }

    func testRotationKeepsTheGame() {
        launch()
        tap("e2", "e4")
        XCUIDevice.shared.orientation = .landscapeLeft
        settle(1.0)
        tap("e7", "e5")
        XCTAssertTrue(boardValue.contains("2 moves played"), boardValue)
        XCUIDevice.shared.orientation = .portrait
        settle(1.0)
        tap("g1", "f3")
        XCTAssertTrue(boardValue.contains("Last move Nf3."), boardValue)
    }

    func testRapidMoves() {
        launch()
        let moves = [("e2", "e4"), ("e7", "e5"), ("g1", "f3"), ("b8", "c6"), ("f1", "b5"), ("a7", "a6"),
                     ("b5", "a4"), ("g8", "f6"), ("e1", "g1"), ("f8", "e7")]
        for (a, b) in moves {
            point(a).tap()
            point(b).tap()
        }
        settle(1.0)
        XCTAssertTrue(boardValue.contains("10 moves played. Last move Be7."), boardValue)
    }
}
