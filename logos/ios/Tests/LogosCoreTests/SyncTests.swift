import XCTest
@testable import LogosCore

final class SyncTests: XCTestCase {
    struct Golden: Decodable { var code: String; var id: String; var auth: String; var blob: String; var text: String }
    static let golden: Golden = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("golden-sync.json")
        return try! JSONDecoder().decode(Golden.self, from: Data(contentsOf: url))
    }()

    func testOpensWhatTheBrowserSealed() throws {
        let g = Self.golden
        let code = try XCTUnwrap(SyncCode(g.code))
        XCTAssertEqual(code.id, g.id)
        XCTAssertEqual(code.auth, g.auth)
        XCTAssertNotEqual(code.auth, code.id)
        XCTAssertEqual(String(decoding: try code.open(g.blob), as: UTF8.self), g.text)
    }

    func testSealsWhatTheBrowserCanOpen() throws {
        let code = try XCTUnwrap(SyncCode(Self.golden.code))
        let text = #"{"app":"logos","data":{"from":"swift","ß":"✓"}}"#
        let blob = try code.seal(Data(text.utf8))
        XCTAssertEqual(String(decoding: try code.open(blob), as: UTF8.self), text)
        // Left for scripts/golden-sync.mjs to open with WebCrypto.
        let out = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(".swift-sealed.json")
        try JSONSerialization.data(withJSONObject: ["code": code.normalized, "blob": blob, "text": text]).write(to: out)
    }

    func testWrongCodeFails() throws {
        let other = SyncCode.generate()
        XCTAssertThrowsError(try other.open(Self.golden.blob))
    }

    func testCodeFormat() {
        XCTAssertNil(SyncCode("too short"))
        let c = SyncCode.generate()
        XCTAssertEqual(c.normalized.count, 20)
        XCTAssertEqual(SyncCode(c.display.lowercased()), c)
        XCTAssertEqual(c.display.count, 24)
        XCTAssertEqual(c.id.count, 64)
    }

    func testPlan() {
        XCTAssertEqual(SyncPlan.decide(local: 5, remote: nil, lastSync: 0), .push)
        XCTAssertEqual(SyncPlan.decide(local: 5, remote: 5, lastSync: 5), .upToDate)
        XCTAssertEqual(SyncPlan.decide(local: 9, remote: 5, lastSync: 5), .push)
        XCTAssertEqual(SyncPlan.decide(local: 5, remote: 9, lastSync: 5), .pull)
        XCTAssertEqual(SyncPlan.decide(local: 9, remote: 8, lastSync: 5), .conflict)
    }
}
