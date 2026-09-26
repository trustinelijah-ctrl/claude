import XCTest
@testable import LogosCore

/// Expected values were produced by running the web app's own functions
/// (optOrder, gapsFor, similarity) in Node — see scripts/golden-text.mjs.
final class TextToolsTests: XCTestCase {
    struct Golden: Decodable {
        struct Opt: Decodable { var q: String; var n: Int; var order: [Int] }
        struct Gap: Decodable { var text: String; var stage: Int; var seed: String; var gaps: [Int] }
        struct Sim: Decodable { var said: String; var text: String; var score: Int }
        var opts: [Opt]; var gaps: [Gap]; var sims: [Sim]
    }
    static let golden: Golden = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("golden-text.json")
        return try! JSONDecoder().decode(Golden.self, from: Data(contentsOf: url))
    }()

    func testOptionOrderMatchesWeb() {
        for o in Self.golden.opts {
            XCTAssertEqual(TextTools.optionOrder(question: LS(o.q, ""), count: o.n), o.order, o.q)
        }
    }
    func testGapsMatchWeb() {
        for g in Self.golden.gaps {
            XCTAssertEqual(TextTools.gaps(for: g.text, stage: g.stage, seed: g.seed), g.gaps, "\(g.seed) stage \(g.stage)")
        }
    }
    func testSimilarityMatchesWeb() {
        for s in Self.golden.sims {
            XCTAssertEqual(TextTools.similarity(said: s.said, text: s.text), s.score, s.said)
        }
    }
    func testTokeniseKeepsWhitespace() {
        XCTAssertEqual(TextTools.tokenise("Jesus  wept.\nAmen"), ["Jesus", "  ", "wept.", "\n", "Amen"])
    }
    func testCoachParse() {
        let p = TextTools.coachParse("**STRENGTH:** good\nFIX: tighten\nmore\nREWRITE: \"x\"\nDEVICE: tricolon")
        XCTAssertEqual(p?["STRENGTH"], "good")
        XCTAssertEqual(p?["FIX"], "tighten more")
        XCTAssertEqual(p?["DEVICE"], "tricolon")
        XCTAssertNil(TextTools.coachParse("just prose"))
        XCTAssertEqual(TextTools.coachParse("STÄRKE: gut")?["STRENGTH"], "gut")
    }
}
