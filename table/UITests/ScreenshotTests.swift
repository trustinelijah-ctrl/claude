import XCTest

/// Captures the app in representative states for visual review. Run on several iPad sizes in CI.
final class ScreenshotTests: XCTestCase {
    private let midgame = "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d4 e5d4 c3d4 c5b4"

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    private func shoot(_ name: String, args: [String], landscape: Bool = false,
                       prepare: ((XCUIApplication) -> Void)? = nil) {
        let app = XCUIApplication()
        app.launchArguments = ["-soundEnabled", "NO"] + args
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        app.launch()
        _ = app.descendants(matching: .any)["board"].firstMatch.waitForExistence(timeout: 10)
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        prepare?(app)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name + (landscape ? "-landscape" : "-portrait")
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }

    func test1Opening() {
        shoot("01-opening", args: ["-fresh", "YES", "-theme", "walnut"])
        shoot("01-opening", args: ["-fresh", "YES", "-theme", "walnut"], landscape: true)
    }

    func test2MidgameSelection() {
        shoot("02-midgame-selected", args: ["-moves", midgame, "-select", "b1", "-theme", "walnut"])
        shoot("02-midgame-selected", args: ["-moves", midgame, "-select", "f3", "-theme", "walnut"], landscape: true)
    }

    func test3SlateCheck() {
        shoot("03-slate-check", args: ["-moves", "e2e4 d7d5 e4d5 d8d5 b1c3 d5a5 d2d4 c7c6 f1c4 g8f6 c1d2 a5b6 d1e2 b6d4 e2e7", "-theme", "slate"])
        shoot("03-slate-check", args: ["-moves", "e2e4 d7d5 e4d5 d8d5 b1c3 d5a5 d2d4 c7c6 f1c4 g8f6 c1d2 a5b6 d1e2 b6d4 e2e7", "-theme", "slate"], landscape: true)
    }

    func test4Checkmate() {
        shoot("04-checkmate", args: ["-moves", "e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7", "-showResult", "YES", "-theme", "walnut"])
        shoot("04-checkmate", args: ["-moves", "e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7", "-showResult", "YES", "-theme", "slate"], landscape: true)
    }

    func test5Settings() {
        shoot("05-settings-black", args: ["-moves", midgame, "-openSettings", "black", "-theme", "walnut"])
        shoot("05-settings-white", args: ["-moves", midgame, "-openSettings", "white", "-theme", "slate"], landscape: true)
    }

    func test6Promotion() {
        let moves = "a2a4 b7b5 a4b5 a7a6 b5a6 c8b7 a6b7 b8c6"
        shoot("06-promotion", args: ["-moves", moves, "-theme", "walnut"]) { app in
            let board = app.descendants(matching: .any)["board"].firstMatch
            let size = board.frame.width
            let rim = max(10, (size * 0.036).rounded())
            let sq = (size - 2 * rim) / 8
            func at(_ f: CGFloat, _ r: CGFloat) -> XCUICoordinate {
                board.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: rim + (f + 0.5) * sq, dy: rim + (7 - r + 0.5) * sq))
            }
            at(1, 6).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            at(0, 7).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
    }

    func test7NarrowWindows() {
        // Split View and Stage Manager sizes, simulated by constraining the root view.
        shoot("07-split-half", args: ["-moves", midgame, "-simulateWindow", "half"])
        shoot("07-split-third", args: ["-moves", midgame, "-simulateWindow", "third"], landscape: true)
        shoot("07-stage-square", args: ["-moves", midgame, "-simulateWindow", "square", "-theme", "slate"], landscape: true)
    }

    func test8NoCoordinatesFacingWhite() {
        shoot("08-plain", args: ["-moves", midgame, "-showCoordinates", "NO", "-pieceFacing", "white", "-showMoveHints", "NO"])
    }
}
