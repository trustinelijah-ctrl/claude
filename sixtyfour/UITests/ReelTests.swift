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

    func test1House() {
        film(["-theme", "house"], seconds: 24)
    }

    func test2RosewoodGilded() {
        film(["-pro", "YES", "-theme", "rosewood", "-pieceSet", "gilded"], seconds: 24)
    }
}
