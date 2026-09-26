import XCTest
@testable import LogosCore

final class CorpusTests: XCTestCase {
    static let corpusURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("content/corpus.json")

    static let corpus: Corpus = {
        let data = try! Data(contentsOf: corpusURL)
        return try! Corpus(data: data)
    }()

    func testEveryDatasetDecodes() {
        let c = Self.corpus
        XCTAssertEqual(c.failures, [], "datasets failed to decode")
        XCTAssertEqual(c.path.count, 8)
        XCTAssertEqual(c.allUnits.count, 29)
        XCTAssertEqual(c.lessons.count, 21)
        XCTAssertEqual(c.lessonIDs.first, "control")
        XCTAssertEqual(c.voices.count, 19)
        XCTAssertEqual(c.figures.count, 9)
        XCTAssertEqual(c.plans.count, 7)
        XCTAssertEqual(c.modules.count, 2)
        XCTAssertGreaterThan(c.scripture.count, 80)
        XCTAssertFalse(c.version.isEmpty)
    }

    func testEveryReferenceResolves() {
        let c = Self.corpus
        for u in c.allUnits {
            switch u.kind {
            case "lesson": XCTAssertNotNil(c.lessons[u.ref], u.ref)
            case "module": XCTAssertNotNil(c.modules[u.ref], u.ref)
            case "plan": XCTAssertNotNil(c.plan(u.ref), u.ref)
            default: XCTFail("unknown unit kind \(u.kind)")
            }
            for a in u.assumes { XCTAssertNotNil(c.unit(a), "\(u.id) assumes \(a)") }
        }
        for (id, l) in c.lessons {
            for k in l.christian.quotes + l.stoic.quotes {
                XCTAssertTrue(c.scripture[k] != nil || c.passages[k] != nil, "\(id) quote \(k)")
            }
            for q in l.check { XCTAssertTrue(q.opts.indices.contains(q.a), "\(id) answer index") }
        }
        for p in c.plans {
            for (di, d) in p.days.enumerated() {
                for s in d.steps {
                    switch s.t {
                    case "teach": XCTAssertNotNil(s.lesson.flatMap { c.lessons[$0] }, "\(p.id):\(di) teach")
                    case "planq": XCTAssertNotNil(s.key.flatMap { c.planQ[$0] }, "\(p.id):\(di) planq")
                    case "think": XCTAssertNotNil(s.key.flatMap { c.planThink[$0] }, "\(p.id):\(di) think")
                    case "memorise":
                        let k = s.key ?? ""
                        XCTAssertTrue(c.scripture[k] != nil || c.passages[k] != nil, "\(p.id):\(di) memorise \(k)")
                    case "quotes":
                        for k in s.keys ?? [] { XCTAssertTrue(c.scripture[k] != nil || c.passages[k] != nil, "\(p.id):\(di) quote \(k)") }
                    case "speak": XCTAssertTrue(s.q != nil || s.lesson != nil, "\(p.id):\(di) speak")
                    default: break
                    }
                }
            }
        }
    }
}
