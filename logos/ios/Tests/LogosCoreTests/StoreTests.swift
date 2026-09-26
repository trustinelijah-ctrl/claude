import XCTest
@testable import LogosCore

final class StoreTests: XCTestCase {
    var clock = Date(timeIntervalSince1970: 1_790_000_000)
    func makeStore(file: URL? = nil) -> AppStore {
        AppStore(corpus: CorpusTests.corpus, fileURL: file, now: { [unowned self] in self.clock })
    }

    func testFreshLearnerStartsAtTheBeginning() {
        let s = makeStore()
        XCTAssertEqual(s.pathStats.done, 0)
        XCTAssertEqual(s.pathNext?.unit.id, "u1")
        XCTAssertEqual(s.lessonOfDay(), "control")
        XCTAssertEqual(s.mastery("control"), 0)
        // Only tier-0 cards are due before anything has been learned.
        XCTAssertTrue(s.dueItems.allSatisfy { (CorpusTests.corpus.modeTier[$0.mode] ?? 0) == 0 })
        XCTAssertGreaterThan(s.lockedCount, 0)
    }

    func testScheduleMatchesWeb() {
        let s = makeStore()
        let id = CorpusTests.corpus.memorySeed[0].id
        s.schedule(id, .good)
        XCTAssertEqual(s.memState(id).interval, 1)
        s.schedule(id, .good)
        XCTAssertEqual(s.memState(id).interval, 4)
        s.schedule(id, .good)
        XCTAssertEqual(s.memState(id).interval, 10)          // round(4 * 2.5)
        s.schedule(id, .immediate)
        XCTAssertEqual(s.memState(id).ease, 2.6, accuracy: 1e-9)
        XCTAssertEqual(s.memState(id).interval, 33)          // round(10 * 2.6 * 1.25) = 32.5 -> 33
        s.schedule(id, .forgot)
        let st = s.memState(id)
        XCTAssertEqual(st.reps, 0); XCTAssertEqual(st.lapses, 1); XCTAssertEqual(st.interval, 0)
        XCTAssertEqual(st.due, s.nowMs + 6e4, accuracy: 1)
        XCTAssertEqual(st.attempts, 5); XCTAssertEqual(st.successes, 4)
    }

    func testLessonFlowRaisesMasteryOnlyOnEvidence() {
        let s = makeStore()
        s.openLesson("control")
        let les = CorpusTests.corpus.lessons["control"]!
        for _ in 0..<4 { s.lessonAdvance() }                  // to the check step
        s.updateLesson { st in for (i, q) in les.check.enumerated() { st["checks"][String(i)] = .number(Double(q.a)) } }
        s.lessonAdvance()                                    // step 5: checks scored
        XCTAssertEqual(s.mastery("control"), 1)
        s.updateLesson { $0["said"] = "Almost everything that bothers you is either yours to change or it is not, and that matters." }
        s.lessonAdvance()                                    // step 6: done, spoke
        XCTAssertEqual(s.mastery("control"), 2)
        XCTAssertTrue(s.unitDone(CorpusTests.corpus.unit("u1")!))
        XCTAssertEqual(s.pathNext?.unit.id, "u2")
        XCTAssertEqual(s.doc["evidence"]["control"]["spoke"].int, 1)
    }

    func testSavedQuoteBecomesACard() {
        let s = makeStore()
        XCTAssertTrue(s.saveQuote("jn11.35", concept: "suffering"))
        XCTAssertFalse(s.saveQuote("jn11.35", concept: "suffering"))
        let m = s.extras.first!
        XCTAssertEqual(m.mode, "memorise"); XCTAssertEqual(m.ref, "jn11.35"); XCTAssertEqual(m.qk, "jn11.35")
        XCTAssertEqual(s.memoriseLabel(m), "John 11:35")
        s.removeExtra(m.id)
        XCTAssertTrue(s.extras.isEmpty)
    }

    func testPlanCompletion() {
        let s = makeStore()
        let pl = CorpusTests.corpus.plan("providence")!
        for d in 0..<pl.days.count - 1 { XCTAssertFalse(s.completePlanDay(pl.id, day: d)) }
        XCTAssertTrue(s.completePlanDay(pl.id, day: pl.days.count - 1))
        XCTAssertTrue(s.planState(pl.id)["completed"].truthy)
        XCTAssertEqual(s.unitProgress(CorpusTests.corpus.allUnits.first { $0.ref == "providence" && $0.kind == "plan" }!), 100)
    }

    func testBackupRoundTripAndWebShape() throws {
        let s = makeStore()
        s.saveQuote("ench1", concept: "control")
        s.lang = .de
        let data = s.exportBackup()
        guard case .success(let (d, summary)) = AppStore.validateBackup(data) else { return XCTFail("invalid") }
        XCTAssertEqual(summary.cards, 1)
        XCTAssertEqual(d["lang"].string, "de")
        XCTAssertEqual(d["v"].int, 2)

        let t = makeStore()
        t.replaceDocument(d)
        XCTAssertEqual(t.lang, .de)
        XCTAssertEqual(t.extras.count, 1)
        XCTAssertTrue(t.undoRestore())
        XCTAssertEqual(t.extras.count, 0)

        XCTAssertEqual(AppStore.validateBackup(Data("{}".utf8)).failureValue, .notLogos)
        XCTAssertEqual(AppStore.validateBackup(Data("nope".utf8)).failureValue, .notJSON)
        XCTAssertEqual(AppStore.validateBackup(Data(#"{"app":"logos","data":{"extra":{}}}"#.utf8)).failureValue, .wrongType("extra"))
    }

    func testUnknownWebFieldsSurvive() {
        let s = makeStore()
        var d = s.doc
        d["somethingOnlyTheWebHas"] = ["nested": [1, 2, 3]]
        s.replaceDocument(d)
        let out = try! JSONDecoder().decode(JSONValue.self, from: s.exportBackup())
        XCTAssertEqual(out["data"]["somethingOnlyTheWebHas"]["nested"][2].int, 3)
    }

    func testPersistence() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("logos-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let s = makeStore(file: url)
        s.saveQuote("med5.20", concept: nil)
        XCTAssertTrue(s.writeNow())
        let t = makeStore(file: url)
        XCTAssertEqual(t.extras.first?.qk, "med5.20")
    }

    func testLeafOfDayIsStableWithinADay() {
        let s = makeStore()
        let a = s.leafOfDay(), b = s.leafOfDay()
        XCTAssertNotNil(a); XCTAssertEqual(a?.id, b?.id)
    }

    func testDayKeyIsUnpadded() {
        let s = makeStore()
        XCTAssertFalse(s.todayKey.contains("-0"))
    }
}

extension Result {
    var failureValue: Failure? { if case .failure(let e) = self { return e }; return nil }
}
