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

    private func shoot(_ name: String, args: [String], landscape: Bool = false, settle: TimeInterval = 1.2,
                       prepare: ((XCUIApplication) -> Void)? = nil) {
        let app = XCUIApplication()
        app.launchArguments = ["-soundEnabled", "NO"] + (args.contains("-onboarded") ? [] : ["-onboarded", "YES"]) + args
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        app.launch()
        _ = app.descendants(matching: .any)["board"].firstMatch.waitForExistence(timeout: 10)
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        prepare?(app)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name + (landscape ? "-landscape" : "-portrait")
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }

    func test1Opening() {
        shoot("01-opening", args: ["-fresh", "YES", "-theme", "house"])
        shoot("01-opening", args: ["-fresh", "YES", "-theme", "house"], landscape: true)
    }

    func test2MidgameSelection() {
        shoot("02-midgame-selected", args: ["-moves", midgame, "-select", "b1", "-theme", "house"])
        shoot("02-midgame-selected", args: ["-moves", midgame, "-select", "f3", "-theme", "house"], landscape: true)
    }

    func test3SlateCheck() {
        shoot("03-slate-check", args: ["-moves", "e2e4 d7d5 e4d5 d8d5 b1c3 d5a5 d2d4 c7c6 f1c4 g8f6 c1d2 a5b6 d1e2 b6d4 e2e7", "-theme", "slate"])
        shoot("03-slate-check", args: ["-moves", "e2e4 d7d5 e4d5 d8d5 b1c3 d5a5 d2d4 c7c6 f1c4 g8f6 c1d2 a5b6 d1e2 b6d4 e2e7", "-theme", "slate"], landscape: true)
    }

    func test4Checkmate() {
        shoot("04-checkmate", args: ["-moves", "e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7", "-showResult", "YES", "-theme", "house"])
        shoot("04-checkmate", args: ["-moves", "e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7", "-showResult", "YES", "-theme", "slate"], landscape: true)
    }

    func test5Settings() {
        shoot("05-settings-black", args: ["-moves", midgame, "-openSettings", "black", "-theme", "house"])
        shoot("05-settings-white", args: ["-moves", midgame, "-openSettings", "white", "-theme", "slate"], landscape: true)
    }

    func test6Promotion() {
        let moves = "a2a4 b7b5 a4b5 a7a6 b5a6 c8b7 a6b7 b8c6"
        shoot("06-promotion", args: ["-moves", moves, "-theme", "house"]) { app in
            let board = app.descendants(matching: .any)["board"].firstMatch
            let size = board.frame.width
            let rim: CGFloat = 0
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

    func test9AgainstTheComputer() {
        shoot("09-vs-table", args: ["-opponent", "computer", "-botLevel", "club", "-humanColor", "white",
                                    "-moves", "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5c6 d7c6 e1g1 f7f6 d2d4 e5d4 f3d4 c6c5"])
        shoot("09-vs-table", args: ["-opponent", "computer", "-humanColor", "black", "-theme", "walnut",
                                    "-moves", "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 d1c2 e8g8 a2a3 b4c3 c2c3"], landscape: true)
    }

    func test8NoCoordinatesFacingWhite() {
        shoot("08-plain", args: ["-moves", midgame, "-theme", "walnut", "-showCoordinates", "NO", "-pieceFacing", "white", "-showMoveHints", "NO"])
    }

    private let captures = "g1f3 e7e5 f3e5 d8g5 e5d7 c8d7 f2f4 g5g6 h1g1 g6g2 f1g2 g7g6 g2b7 a7a5 g1g6 f7f6 g6g8 h8g8 b7a8 f8d6 e1f1 d6f4 f1f2 f4h2 b2b4 a5b4 a8b7 d7c8 b7c8 h2f4 c8h3 f4d2 c1d2 h7h6 d2b4 e8f7 e2e3 c7c6 d1d3 g8c8 h3c8 b8d7 d3d7 f7g8 d7c6 h6h5 c6f6 g8h7 b4c3 h7g8 f2f1 g8h7 f6g5 h5h4 b1a3 h4h3"

    func testA1Onboarding() {
        for page in 0..<3 {
            shoot("10-welcome-\(page)", args: ["-onboarded", "NO", "-onboardingPage", "\(page)"], settle: 2.4)
        }
        shoot("10-welcome-0", args: ["-onboarded", "NO", "-onboardingPage", "0"], landscape: true, settle: 2.4)
        shoot("10-welcome-2", args: ["-onboarded", "NO", "-onboardingPage", "2"], landscape: true, settle: 2.4)
    }

    func testA5HomeAndLearn() {
        shoot("14-home", args: ["-home", "YES", "-moves", midgame], settle: 1.5)
        shoot("14-home", args: ["-home", "YES"], landscape: true, settle: 1.5)
        shoot("15-learn", args: ["-learn", "YES", "-pro", "YES"], settle: 1.5)
        shoot("15-learn-locked", args: ["-learn", "YES"], settle: 1.5) { app in
            app.buttons["Mate in 2"].tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
    }

    func testA0Clocks() {
        shoot("00-clock", args: ["-moves", midgame, "-timeControl", "blitz5"], settle: 3.0)
        shoot("00-clock", args: ["-moves", midgame, "-timeControl", "rapid10", "-theme", "tournament"], landscape: true, settle: 3.0)
        shoot("00-clock-vs-64", args: ["-opponent", "computer", "-humanColor", "white", "-timeControl", "rapid10",
                                       "-moves", "e2e4 e7e5 g1f3 b8c6"], settle: 3.0)
    }

    func testA2Captures() {
        shoot("11-tray-overflow", args: ["-moves", captures, "-theme", "house"])
        shoot("11-captures-panel", args: ["-moves", captures, "-theme", "house", "-showCaptures", "white"])
        shoot("11-tray-overflow", args: ["-moves", captures, "-theme", "walnut"], landscape: true)
    }

    func testA3ProBoards() {
        shoot("12-paywall", args: ["-moves", midgame, "-showPaywall", "YES"])
        shoot("12-marble-gilded", args: ["-pro", "YES", "-moves", midgame, "-theme", "marble", "-pieceSet", "gilded"])
        shoot("12-rosewood", args: ["-pro", "YES", "-moves", midgame, "-theme", "rosewood"])
        shoot("12-midnight", args: ["-pro", "YES", "-moves", midgame, "-theme", "midnight", "-pieceSet", "gilded"], landscape: true)
        shoot("12-ebony-wood", args: ["-pro", "YES", "-moves", midgame, "-theme", "ebony", "-pieceSet", "wood"])
        shoot("12-olive", args: ["-pro", "YES", "-moves", midgame, "-theme", "olive"])
    }

    func testA4EndingAndReplay() {
        let mate = "e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7"
        shoot("13-win-vs-table", args: ["-opponent", "computer", "-humanColor", "white", "-moves", mate, "-showResult", "YES"], settle: 2.5)
        shoot("13-replay", args: ["-moves", captures, "-seedLibrary", "YES", "-showReplay", "YES"], settle: 1.5)
        shoot("13-review", args: ["-pro", "YES", "-moves", captures, "-seedLibrary", "YES", "-showReplay", "YES"], settle: 12) { app in
            // Step to a move the review marks, so the verdict and the better move show.
            let forward = app.buttons["Forward"]
            for _ in 0..<11 where forward.exists { forward.tap() }
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        }
        shoot("13-library", args: ["-moves", mate, "-seedLibrary", "YES", "-showLibrary", "YES"])
    }
}
