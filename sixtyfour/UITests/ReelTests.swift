import XCTest

/// Not a test: plays scripted games while CI records the simulator screen, for social videos.
/// Runs only when a commit asks for it ([reel]).
final class ReelTests: XCTestCase {
    /// The Blackburne Shilling trap: four captures and a knight mate in fourteen moves.
    private let trap = "e2e4 e7e5 g1f3 b8c6 f1c4 c6d4 f3e5 d8g5 e5f7 g5g2 h1f1 g2e4 c4e2 d4f3"

    private func film(_ args: [String], seconds: TimeInterval) {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarded", "YES", "-fresh", "YES", "-home", "NO", "-showMoveHints", "NO",
                               "-demoMoves", trap, "-demoInterval", "0.95", "-demoStart", "2.5"] + args
        app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        app.terminate()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }

    // MARK: Walkthrough

    private func wait(_ s: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func tapIfThere(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 4) {
        let e = element(app, id)
        if e.waitForExistence(timeout: timeout) { e.tap() }
    }

    /// The centre of a square on a board element, white at the bottom.
    private func point(_ board: XCUIElement, _ name: String) -> XCUICoordinate {
        let sq = board.frame.width / 8
        let c = Array(name)
        let file = CGFloat(Int(c[0].asciiValue!) - 97), rank = CGFloat(Int(c[1].asciiValue!) - 49)
        return board.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: (file + 0.5) * sq, dy: (7 - rank + 0.5) * sq))
    }

    /// Picks a piece up and carries it, aiming a little low as a player does (the app lifts
    /// a carried piece above the finger).
    private func carry(_ board: XCUIElement, _ from: String, _ to: String) {
        let lift = CGVector(dx: 0, dy: board.frame.width / 8 * 0.34)
        point(board, from).press(forDuration: 0.25, thenDragTo: point(board, to).withOffset(lift),
                                 withVelocity: .slow, thenHoldForDuration: 0.15)
    }

    /// A tour of the app on the phone, filmed for the owner to watch: home, a game against
    /// 64, the options, free play and Learn.
    func test0Walkthrough() {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarded", "YES", "-fresh", "YES", "-home", "YES", "-pro", "YES",
                               "-opponent", "computer", "-botLevel", "casual", "-humanColor", "white"]
        app.launch()
        wait(4)
        // Play 64: choose a strength, then begin.
        tapIfThere(app, "home-computer")
        wait(2)
        tapIfThere(app, "home-start")
        let board = element(app, "board")
        guard board.waitForExistence(timeout: 20) else { return }
        wait(2.5)
        for (from, to) in [("e2", "e4"), ("g1", "f3"), ("f1", "c4"), ("d2", "d3"), ("b1", "c3")] {
            carry(board, from, to)
            wait(3.2)
        }
        // The options.
        let options = app.otherElements["panel-white"].buttons["Settings"]
        if options.exists {
            options.tap()
            wait(2.5)
            tapIfThere(app, "tab-board")
            wait(1.5)
            let rosewood = app.buttons["Rosewood"]
            if rosewood.exists { rosewood.tap(); wait(1.5) }
            if app.buttons["Done"].exists { app.buttons["Done"].tap() }
            wait(3)
            carry(board, "e1", "g1")
            wait(3.5)
        }
        // Home, then free play.
        tapIfThere(app, "pin-home-white")
        wait(3)
        tapIfThere(app, "home-free-play")
        let sandbox = element(app, "sandbox-board")
        if sandbox.waitForExistence(timeout: 8) {
            wait(2)
            for (from, to) in [("e2", "e5"), ("d8", "h4"), ("g1", "f6"), ("h4", "f6")] {
                carry(sandbox, from, to)
                wait(1.6)
            }
            if app.buttons["Set up again"].exists { app.buttons["Set up again"].tap() }
            wait(2.5)
            if app.buttons["Home"].exists { app.buttons["Home"].tap() }
            wait(2.5)
        }
        // Learn.
        tapIfThere(app, "home-learn")
        wait(4)
        tapIfThere(app, "learn-home")
        wait(3)
        app.terminate()
        wait(1.5)
    }

    func test1House() {
        film(["-theme", "house", "-tiltSweep", "YES"], seconds: 24)
    }

    func test2RosewoodGilded() {
        film(["-pro", "YES", "-theme", "rosewood", "-pieceSet", "gilded", "-tiltSweep", "YES"], seconds: 24)
    }
}
