import Foundation
import Observation

/// The learner's state. It is the web app's `S.d` document, kept verbatim as
/// JSON so a backup or a sync round-trips between the browser and the phone
/// without losing anything. Every rule here is a port of the web version.
@Observable
public final class AppStore {
    public var corpus: Corpus
    public private(set) var doc: JSONValue
    public var lang: Lang { didSet { if doc["lang"].string != lang.rawValue { doc["lang"] = .string(lang.rawValue); save() } } }
    /// The last restore, so it can be undone from the same screen.
    public private(set) var rollback: JSONValue?
    public private(set) var lastSaveFailed = false

    @ObservationIgnored public var now: () -> Date = Date.init
    @ObservationIgnored let fileURL: URL?
    @ObservationIgnored private var saveWork: DispatchWorkItem?

    public static let day: Double = 864e5

    public init(corpus: Corpus, fileURL: URL?, now: @escaping () -> Date = Date.init) {
        self.corpus = corpus
        self.fileURL = fileURL
        self.now = now
        var loaded: JSONValue? = nil
        if let url = fileURL, let data = try? Data(contentsOf: url) {
            loaded = try? JSONDecoder().decode(JSONValue.self, from: data)
        }
        self.doc = .null
        self.lang = .en
        if let l = loaded, l["v"].int == 2 { doc = l } else { doc = blank() }
        blankFill()
        lang = Lang(rawValue: doc["lang"].string) ?? .en
    }

    // MARK: time

    public var nowMs: Double { now().timeIntervalSince1970 * 1000 }

    /// "2026-9-26": the web's key, unpadded, in local time.
    public func dayKey(_ date: Date? = nil) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date ?? now())
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }
    public var todayKey: String { dayKey() }

    // MARK: document lifecycle

    func blank() -> JSONValue {
        let t = nowMs
        var mem: [String: JSONValue] = [:]
        for m in corpus.memorySeed {
            mem[m.id] = ["due": .number(t), "ease": 2.5, "interval": 0, "reps": 0, "lapses": 0,
                         "attempts": 0, "successes": 0, "last": nil, "seeded": true]
        }
        var mast: [String: JSONValue] = [:]
        for c in corpus.concepts { mast[c.id] = 0 }
        let caps: [JSONValue] = corpus.captureSeed.map { c in
            ["id": .string(c.id), "kind": .string(c.kind), "title": .string(c.title), "body": .string(c.body),
             "concept": c.concept.map(JSONValue.string) ?? nil, "lang": c.lang.map(JSONValue.string) ?? nil,
             "tags": .array((c.tags ?? []).map(JSONValue.string)), "ts": nil, "example": true]
        }
        return ["v": 2, "lang": "en", "mastery": .object(mast), "memory": .object(mem), "extra": [],
                "captures": .array(caps), "reflections": [], "sessions": [], "lastConcept": "control",
                "evidence": [:], "evidenceLang": [:], "planWork": [:], "lessons": [:], "modulesDone": [:],
                "mute": false, "seedFixed": true, "passagesExact": true, "passagesExact2": true]
    }

    /// Fills fields an older or foreign document lacks, without touching any it has.
    func blankFill() {
        let b = blank()
        for (k, v) in b.object where doc[k].isNull { doc[k] = v }
        if doc["v"].isNull { doc["v"] = 2 }
    }

    /// Debounced write; the document also records when it last changed, which sync uses.
    public func save(immediately: Bool = false) {
        doc["modified"] = .number(nowMs)
        saveWork?.cancel()
        if immediately { writeNow(); return }
        let w = DispatchWorkItem { [weak self] in self?.writeNow() }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: w)
    }

    @discardableResult
    public func writeNow() -> Bool {
        guard let url = fileURL else { return true }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(doc)
            try data.write(to: url, options: [.atomic])
            lastSaveFailed = false
            return true
        } catch {
            lastSaveFailed = true
            return false
        }
    }

    // MARK: backup (same file format as the web's "Export a backup")

    public func exportBackup() -> Data {
        let iso = ISO8601DateFormatter().string(from: now())
        let payload: JSONValue = ["app": "logos", "version": 2, "exported": .string(iso), "data": doc]
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(payload)) ?? Data()
    }

    public struct BackupSummary: Equatable { public var notes, cards, sessions, reflections, plans: Int }
    public enum BackupError: Error, Equatable { case notJSON, notObject, notLogos, noData, wrongType(String) }

    public static func validateBackup(_ data: Data) -> Result<(JSONValue, BackupSummary), BackupError> {
        guard let parsed = try? JSONDecoder().decode(JSONValue.self, from: data) else { return .failure(.notJSON) }
        guard parsed.objectValue != nil else { return .failure(.notObject) }
        guard parsed["app"].string == "logos" else { return .failure(.notLogos) }
        let d = parsed["data"]
        guard d.objectValue != nil else { return .failure(.noData) }
        let shapes = ["mastery": "object", "lessons": "object", "extra": "array", "captures": "array", "sessions": "array"]
        for (k, kind) in shapes where !d[k].isNull {
            if kind == "array" && d[k].arrayValue == nil { return .failure(.wrongType(k)) }
            if kind == "object" && d[k].objectValue == nil { return .failure(.wrongType(k)) }
        }
        return .success((d, BackupSummary(notes: d["captures"].array.count, cards: d["extra"].array.count,
                                          sessions: d["sessions"].array.count, reflections: d["reflections"].array.count,
                                          plans: d["plans"].object.count)))
    }

    /// Replaces the document, keeping the previous one for undo.
    public func replaceDocument(_ d: JSONValue, keepRollback: Bool = true) {
        if keepRollback { rollback = doc }
        doc = d
        blankFill()
        lang = Lang(rawValue: doc["lang"].string) ?? lang
        writeNow()
    }

    public func undoRestore() -> Bool {
        guard let r = rollback else { return false }
        doc = r; rollback = nil
        lang = Lang(rawValue: doc["lang"].string) ?? lang
        writeNow()
        return true
    }

    // MARK: settings

    public var mute: Bool {
        get { doc["mute"].boolValue ?? false }
        set { doc["mute"] = .bool(newValue); save() }
    }
    /// "plain" (World English Bible / plain German) or "classic" (KJV / Luther 1912).
    public var translation: String {
        get { doc["trans"].string == "classic" ? "classic" : "plain" }
        set { doc["trans"] = .string(newValue); save() }
    }
    public func pick(_ s: LS?) -> String { s?(lang) ?? "" }
    public func L(_ en: String, _ de: String) -> String { lang == .de ? de : en }

    // MARK: texts

    public func scriptureText(_ k: String) -> String {
        guard let s = corpus.scripture[k] else { return "" }
        if translation == "plain", let v = (lang == .de ? s.pde : s.pen), !v.isEmpty { return v }
        return lang == .de ? s.de : s.en
    }
    public func scriptureRef(_ k: String) -> String {
        guard let s = corpus.scripture[k] else { return k }
        return lang == .de ? (s.refDe ?? s.ref) : s.ref
    }
    public func authorName(_ a: String) -> String {
        guard lang == .de else { return a }
        return ["Epictetus": "Epiktet", "Marcus Aurelius": "Mark Aurel"][a] ?? a
    }
    /// The text and label for any quote key: scripture or a Stoic passage.
    public func quote(_ k: String) -> (text: String, label: String, isScripture: Bool)? {
        if corpus.scripture[k] != nil { return (scriptureText(k), scriptureRef(k), true) }
        if let p = corpus.passages[k] {
            return (lang == .de ? p.de : p.en, authorName(p.author) + " · " + (p.ref ?? p.cite ?? ""), false)
        }
        return nil
    }
    public var translationName: String {
        let t = corpus.translations[translation]
        return lang == .de ? (t?.de ?? "") : (t?.en ?? "")
    }
    public func conceptTitle(_ id: String?) -> String { pick(corpus.concept(id)?.t) }

    // MARK: memory & spaced repetition

    /// Saved cards, read straight from the tree (views call this often).
    public var extras: [MemoryItem] {
        doc["extra"].array.compactMap { j in
            guard let id = j["id"].stringValue else { return nil }
            func ls(_ v: JSONValue) -> LS { v.stringValue.map { LS($0, $0) } ?? LS(v["en"].string, v["de"].string) }
            return MemoryItem(id: id, mode: j["mode"].stringValue ?? "memorise", concept: j["concept"].stringValue,
                              ref: j["ref"].stringValue, q: ls(j["q"]), a: ls(j["a"]), src: j["src"].stringValue,
                              qk: j["qk"].stringValue, own: j["own"].boolValue)
        }
    }
    public var allMemory: [MemoryItem] { corpus.memorySeed + extras }
    public func memoryItem(_ id: String) -> MemoryItem? { allMemory.first { $0.id == id } }

    public struct MemState: Equatable {
        public var due: Double, ease: Double, interval: Double, reps: Int, lapses: Int, attempts: Int, successes: Int
        public var last: Double?, stage: Int
    }

    public func memState(_ id: String) -> MemState {
        let m = doc["memory"][id]
        if m.isNull {
            return MemState(due: nowMs, ease: 2.5, interval: 0, reps: 0, lapses: 0, attempts: 0, successes: 0, last: nil, stage: 0)
        }
        return MemState(due: m["due"].doubleValue ?? nowMs, ease: m["ease"].doubleValue ?? 2.5, interval: m["interval"].double,
                        reps: m["reps"].int, lapses: m["lapses"].int, attempts: m["attempts"].int,
                        successes: m["successes"].int, last: m["last"].doubleValue, stage: m["stage"].int)
    }

    func putMemState(_ id: String, _ s: MemState) {
        var m = doc["memory"][id]
        if m.isNull { m = [:] }
        m["due"] = .number(s.due); m["ease"] = .number(s.ease); m["interval"] = .number(s.interval)
        m["reps"] = .number(Double(s.reps)); m["lapses"] = .number(Double(s.lapses))
        m["attempts"] = .number(Double(s.attempts)); m["successes"] = .number(Double(s.successes))
        m["last"] = s.last.map(JSONValue.number) ?? nil
        m["stage"] = .number(Double(s.stage))
        doc["memory"][id] = m
    }

    public enum Rating: String, CaseIterable { case forgot, hard, good, immediate }

    /// SM-2 variant, identical to the web's `schedule()`.
    public func schedule(_ id: String, _ rating: Rating) {
        var st = memState(id)
        let t = nowMs
        st.attempts += 1; st.last = t
        if rating == .forgot {
            st.reps = 0; st.lapses += 1; st.ease = max(1.3, st.ease - 0.2); st.interval = 0
            st.due = t + 6e4
        } else {
            st.successes += 1
            switch rating {
            case .hard:
                st.ease = max(1.3, st.ease - 0.15)
                st.interval = st.reps == 0 ? 1 : max(1, (st.interval * 1.25).rounded(.toNearestOrAwayFromZero))
            case .good:
                st.interval = st.reps == 0 ? 1 : (st.reps == 1 ? 4 : (st.interval * st.ease).rounded(.toNearestOrAwayFromZero))
            default:
                st.ease = min(2.9, st.ease + 0.1)
                st.interval = st.reps == 0 ? 2 : (st.reps == 1 ? 6 : (st.interval * st.ease * 1.25).rounded(.toNearestOrAwayFromZero))
            }
            st.reps += 1
            st.interval = min(365, st.interval)
            st.due = t + st.interval * Self.day
        }
        putMemState(id, st)
        save()
    }

    public func setMemoriseStage(_ id: String, _ stage: Int) {
        var st = memState(id); st.stage = stage; putMemState(id, st); save()
    }

    public func unlocked(_ m: MemoryItem) -> Bool {
        guard let c = m.concept, !c.isEmpty else { return true }
        return (corpus.modeTier[m.mode] ?? 0) <= mastery(c)
    }
    public var dueItems: [MemoryItem] { let t = nowMs; return allMemory.filter { memState($0.id).due <= t && unlocked($0) } }
    public var lockedCount: Int { let t = nowMs; return allMemory.filter { memState($0.id).due <= t && !unlocked($0) }.count }

    public struct ReviewStats {
        public var all, due, own, saved, seeded, unseen, soon, locked: Int
        public var struggling: [MemoryItem]
    }
    public var reviewStats: ReviewStats {
        let t = nowMs, all = allMemory, ex = extras
        let struggling = all.filter { let s = memState($0.id); return s.attempts >= 3 && Double(s.successes) / Double(s.attempts) < 0.6 }
            .sorted { let a = memState($0.id), b = memState($1.id); return Double(a.successes) / Double(a.attempts) < Double(b.successes) / Double(b.attempts) }
        return ReviewStats(all: all.count, due: dueItems.count, own: ex.filter { $0.own == true }.count,
                           saved: ex.filter { $0.own != true }.count, seeded: all.count - ex.count,
                           unseen: all.filter { memState($0.id).attempts == 0 }.count,
                           soon: all.filter { let d = memState($0.id).due; return d > t && d <= t + Self.day * 2 }.count,
                           locked: lockedCount, struggling: Array(struggling.prefix(3)))
    }

    public func isSaved(_ k: String) -> Bool { extras.contains { $0.qk == k } }

    func appendExtra(_ m: MemoryItem) {
        var arr = doc["extra"].array
        arr.append(JSONValue.from(m))
        doc["extra"] = .array(arr)
        doc["memory"][m.id] = ["due": .number(nowMs), "ease": 2.5, "interval": 0, "reps": 0, "lapses": 0,
                               "attempts": 0, "successes": 0, "last": nil, "stage": 0]
    }

    /// Saves a scripture or passage to the review queue. False if already there.
    @discardableResult
    public func saveQuote(_ k: String, concept cid: String?) -> Bool {
        if isSaved(k) { return false }
        let m: MemoryItem
        if let s = corpus.scripture[k] {
            m = MemoryItem(id: TextTools.uid(now: now()), mode: "memorise", concept: cid, ref: k,
                           q: LS("Recite " + s.ref, (s.refDe ?? s.ref) + " aufsagen"), a: LS(s.en, s.de),
                           src: scriptureRef(k), qk: k, own: nil)
        } else if let p = corpus.passages[k] {
            let r = p.ref ?? ""
            m = MemoryItem(id: TextTools.uid(now: now()), mode: "memorise", concept: cid, ref: nil,
                           q: LS("Recite " + p.author + ", " + r, p.author + ", " + r + " aufsagen"), a: LS(p.en, p.de),
                           src: p.author + " · " + r, qk: k, own: nil)
        } else { return false }
        appendExtra(m)
        save()
        return true
    }

    /// A voice's quotation as a memorise card.
    @discardableResult
    public func saveVoiceQuote(_ v: Voice) -> Bool {
        let key = "voice:" + v.id
        if isSaved(key) { return false }
        let en = v.quote.en ?? "", de = (v.quote.de?.isEmpty == false ? v.quote.de! : en)
        let m = MemoryItem(id: TextTools.uid(now: now()), mode: "memorise", concept: v.concepts?.first, ref: nil,
                           q: LS("Recite " + v.name + ", " + (v.quote.src ?? ""), v.name + ", " + (v.quote.src ?? "") + " aufsagen"),
                           a: LS(en, de), src: v.name + " · " + (v.quote.src ?? ""), qk: key, own: nil)
        appendExtra(m); save(); return true
    }

    /// A card in the learner's own words.
    public func addOwnCard(question: String, answer: String, concept: String?) {
        let m = MemoryItem(id: TextTools.uid(now: now()), mode: "explanation", concept: nil, ref: nil,
                           q: LS(question, question), a: LS(answer, answer), src: conceptTitle(concept), qk: nil, own: true)
        appendExtra(m); save()
    }

    public func removeExtra(_ id: String) {
        doc["extra"] = .array(doc["extra"].array.filter { $0["id"].string != id })
        var mem = doc["memory"].object; mem.removeValue(forKey: id); doc["memory"] = .object(mem)
        save()
    }

    /// The text a memorise card asks for, in the current language and translation.
    public func memoriseText(_ m: MemoryItem) -> String {
        if let r = m.ref, corpus.scripture[r] != nil { return scriptureText(r) }
        return pick(m.a)
    }
    public func memoriseLabel(_ m: MemoryItem) -> String {
        if let r = m.ref, corpus.scripture[r] != nil { return scriptureRef(r) }
        return m.src ?? ""
    }

    // MARK: mastery & evidence

    public func mastery(_ cid: String) -> Int { doc["mastery"][cid].int }

    @discardableResult
    public func raiseMastery(_ cid: String?, to: Int) -> Bool {
        guard let cid, !cid.isEmpty else { return false }
        if mastery(cid) < to { doc["mastery"][cid] = .number(Double(to)); save(); return true }
        return false
    }
    public func setMastery(_ cid: String, _ v: Int) { doc["mastery"][cid] = .number(Double(max(0, min(5, v)))); save() }
    public func masteryName(_ l: Int) -> String { pick(corpus.mastery.indices.contains(l) ? corpus.mastery[l] : corpus.mastery.first) }

    public struct Evidence { public var recalls, explained, spoke, hard, taught, notes: Int }
    public func evidence(_ cid: String) -> Evidence {
        var recalls = 0, explained = 0
        for m in allMemory where m.concept == cid {
            let st = memState(m.id)
            recalls += st.successes
            if st.successes > 0 && ["explanation", "comparison", "argument"].contains(m.mode) { explained += 1 }
        }
        let ev = doc["evidence"][cid]
        let notes = doc["captures"].array.filter { $0["concept"].string == cid }.count
        return Evidence(recalls: recalls, explained: explained, spoke: ev["spoke"].int, hard: ev["hard"].int, taught: ev["taught"].int, notes: notes)
    }
    public func nextLevelReady(_ cid: String) -> Bool {
        let l = mastery(cid), e = evidence(cid)
        switch l {
        case 0: return e.notes > 0 || e.recalls > 0
        case 1: return e.recalls >= 3
        case 2: return e.explained >= 1 || e.spoke >= 1
        case 3: return e.hard >= 1
        case 4: return e.taught >= 1
        default: return false
        }
    }
    public func noteEvidence(_ cid: String?, _ key: String, lang lg: Lang? = nil) {
        guard let cid, !cid.isEmpty else { return }
        if doc["evidence"][cid].isNull { doc["evidence"][cid] = ["spoke": 0, "hard": 0, "taught": 0] }
        doc["evidence"][cid][key] = .number(doc["evidence"][cid][key].double + 1)
        let l = (lg ?? lang).rawValue
        if doc["evidenceLang"][cid].isNull {
            doc["evidenceLang"][cid] = ["en": ["spoke": 0, "hard": 0, "taught": 0], "de": ["spoke": 0, "hard": 0, "taught": 0]]
        }
        doc["evidenceLang"][cid][l][key] = .number(doc["evidenceLang"][cid][l][key].double + 1)
        save()
    }

    // MARK: path

    public func unitDone(_ u: PathUnit) -> Bool {
        switch u.kind {
        case "lesson":
            return doc["lessons"].object.values.contains { $0["id"].string == u.ref && $0["done"].truthy } || mastery(u.ref) >= 2
        case "module": return doc["modulesDone"][u.ref].truthy
        case "plan": return planState(u.ref)["completed"].truthy
        default: return false
        }
    }
    public func unitReady(_ u: PathUnit) -> Bool { u.assumes.allSatisfy { corpus.unit($0).map(unitDone) ?? false } }
    public func unitMissing(_ u: PathUnit) -> [String] {
        u.assumes.compactMap(corpus.unit).filter { !unitDone($0) }.map(unitTitle)
    }
    public func unitProgress(_ u: PathUnit) -> Int {
        if u.kind == "plan", let pl = corpus.plan(u.ref), !pl.days.isEmpty {
            return Int((Double(planState(u.ref)["doneDays"].int) / Double(pl.days.count) * 100).rounded())
        }
        return unitDone(u) ? 100 : 0
    }
    public var pathNext: (stage: PathStage, unit: PathUnit)? {
        for s in corpus.path { for u in s.units where !unitDone(u) && unitReady(u) { return (s, u) } }
        return nil
    }
    public var pathStats: (done: Int, total: Int, pct: Int) {
        let all = corpus.allUnits
        let done = all.filter(unitDone).count
        return (done, all.count, all.isEmpty ? 0 : Int((Double(done) / Double(all.count) * 100).rounded()))
    }
    public func unitTitle(_ u: PathUnit) -> String {
        switch u.kind {
        case "lesson": return corpus.concept(u.ref).map { pick($0.t) } ?? u.ref
        case "module": return corpus.modules[u.ref].map { pick($0.title) } ?? u.ref
        default: return corpus.plan(u.ref).map { pick($0.title) } ?? u.ref
        }
    }
    public func unitKindName(_ u: PathUnit) -> String {
        let kind = ["lesson": L("Lesson", "Lektion"), "module": L("Deep unit", "Vertiefung"), "plan": L("Track", "Weg")][u.kind] ?? ""
        return kind + " · " + unitShape(u)
    }
    func unitShape(_ u: PathUnit) -> String {
        let both = L("both traditions", "beide Traditionen")
        if u.kind == "lesson" { return both }
        if u.kind == "module" { return L("one side, in depth", "eine Seite, vertieft") }
        return ["providence": both, "death": both, "stoics": L("Stoic", "stoisch"), "christian": L("Christian", "christlich"),
                "reborn": L("Christian", "christlich"), "atheist": L("Christian, under objection", "christlich, unter Einwand"),
                "religions": L("Christian and other faiths", "christlich und andere Religionen")][u.ref] ?? both
    }
    public func unitForLesson(_ id: String) -> PathUnit? { corpus.allUnits.first { $0.kind == "lesson" && $0.ref == id } }

    // MARK: the daily lesson

    public func lessonOfDay() -> String {
        for u in corpus.allUnits where u.kind == "lesson" && corpus.lessons[u.ref] != nil && !unitDone(u) { return u.ref }
        let ids = corpus.lessonIDs
        guard !ids.isEmpty else { return "control" }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let c = Calendar.current.dateComponents([.year, .month, .day], from: now())
        let utc = cal.date(from: c) ?? now()
        let seed = Int((utc.timeIntervalSince1970 * 1000 / Self.day).rounded(.down))
        return ids[seed % ids.count]
    }

    /// Today's lesson record, created on first touch.
    public var lesson: JSONValue {
        get {
            let k = todayKey
            if doc["lessons"][k].isNull { return freshLesson(lessonOfDay()) }
            return doc["lessons"][k]
        }
        set { doc["lessons"][todayKey] = newValue; save() }
    }
    func freshLesson(_ id: String, opened: Bool = false) -> JSONValue {
        ["id": .string(id), "step": 0, "checks": [:], "saved": [], "said": "", "done": false, "cv": 2, "opened": .bool(opened)]
    }
    /// Starts (or restarts) today's lesson on a given topic, as the Path does.
    public func openLesson(_ id: String) { doc["lessons"][todayKey] = freshLesson(id, opened: true); save() }
    public func updateLesson(_ f: (inout JSONValue) -> Void) { var l = lesson; f(&l); lesson = l }

    public func lessonCorrect(_ l: JSONValue) -> Int {
        guard let les = corpus.lessons[l["id"].string] else { return 0 }
        return les.check.enumerated().filter { l["checks"][String($0.offset)].intValue == $0.element.a }.count
    }

    /// Moves the lesson on one step, raising mastery exactly where the web does.
    public func lessonAdvance() {
        updateLesson { st in
            let id = st["id"].string
            st["step"] = .number(st["step"].double + 1)
            let step = st["step"].int
            if step == 1 { doc["seen"][id] = .number(nowMs) }
            if step == 5 {
                let right = lessonCorrect(st)
                st["rightCount"] = .number(Double(right))
                if right >= 3 { raiseMastery(id, to: 1) }
            }
            if step >= 6 {
                st["step"] = 6
                if !st["done"].truthy {
                    st["done"] = true
                    if st["said"].string.trimmingCharacters(in: .whitespacesAndNewlines).count > 30 {
                        noteEvidence(id, "spoke"); raiseMastery(id, to: 2)
                    }
                }
            }
        }
    }
    public func lessonFinish() {
        updateLesson { st in
            st["opened"] = false; st["done"] = true
            let id = st["id"].string
            if st["said"].string.trimmingCharacters(in: .whitespacesAndNewlines).count > 30 { noteEvidence(id, "spoke"); raiseMastery(id, to: 2) }
            else if st["rightCount"].int >= 2 { raiseMastery(id, to: 1) }
        }
    }

    // MARK: plans

    public func planState(_ id: String) -> JSONValue {
        let s = doc["plans"][id]
        return s.isNull ? ["day": 0, "step": 0, "doneDays": 0, "runs": 0, "completed": false, "started": nil] : s
    }
    public func setPlanState(_ id: String, _ f: (inout JSONValue) -> Void) {
        var s = planState(id); f(&s); doc["plans"][id] = s; save()
    }
    public func planWork(_ planId: String, day: Int, step: Int) -> JSONValue { doc["planWork"][planId]["\(day):\(step)"] }
    public func setPlanWork(_ planId: String, day: Int, step: Int, _ f: (inout JSONValue) -> Void) {
        var w = planWork(planId, day: day, step: step)
        if w.isNull { w = [:] }
        f(&w)
        doc["planWork"][planId]["\(day):\(step)"] = w
        save()
    }
    public func planRecord(_ planId: String) -> (spoken: Int, skipped: Int, total: Int) {
        guard let pl = corpus.plan(planId) else { return (0, 0, 0) }
        var spoken = 0, skipped = 0, total = 0
        for (di, d) in pl.days.enumerated() {
            for (si, st) in d.steps.enumerated() where st.t == "speak" {
                total += 1
                let r = planWork(planId, day: di, step: si)
                if r["text"].string.trimmingCharacters(in: .whitespacesAndNewlines).count >= 15 { spoken += 1 }
                else if r["skipped"].truthy { skipped += 1 }
            }
        }
        return (spoken, skipped, total)
    }
    /// Records a finished plan day and the evidence it carries.
    public func completePlanDay(_ planId: String, day: Int) -> Bool {
        guard let pl = corpus.plan(planId) else { return false }
        var finishedTrack = false
        setPlanState(planId) { st in
            if day >= st["doneDays"].int { st["doneDays"] = .number(Double(day + 1)) }
            if st["doneDays"].int >= pl.days.count && !st["completed"].truthy {
                st["completed"] = true; st["runs"] = .number(st["runs"].double + 1); finishedTrack = true
            }
        }
        for x in pl.days[day].steps { if let l = x.lesson { raiseMastery(l, to: 1) } }
        return finishedTrack
    }

    public func markModuleDone(_ id: String) { doc["modulesDone"][id] = true; save() }

    // MARK: voices & craft

    public func work(_ bucket: String, _ id: String) -> JSONValue { doc[bucket][id] }
    public func setWork(_ bucket: String, _ id: String, _ f: (inout JSONValue) -> Void) {
        var w = doc[bucket][id]
        if w.isNull { w = [:] }
        f(&w)
        doc[bucket][id] = w
        save()
    }
    public func markSeen(_ bucket: String, _ id: String) {
        if !doc[bucket][id]["seen"].truthy { setWork(bucket, id) { $0["seen"] = .number(nowMs) } }
    }

    /// One voice or figure per day, unseen first, alternating kinds.
    public func leafOfDay() -> (kind: String, id: String)? {
        let vs = corpus.voices.map { ("voice", $0.id) }, fs = corpus.figures.map { ("figure", $0.id) }
        var pool: [(String, String)] = []
        for i in 0..<max(vs.count, fs.count) {
            if i < vs.count { pool.append(vs[i]) }
            if i < fs.count { pool.append(fs[i]) }
        }
        guard !pool.isEmpty else { return nil }
        let key = todayKey
        let leaf = doc["leaf"]
        if leaf["day"].string == key, !leaf["id"].string.isEmpty { return (leaf["kind"].string, leaf["id"].string) }
        func seen(_ x: (String, String)) -> Bool { doc[x.0 == "voice" ? "voiceWork" : "craftWork"][x.1]["seen"].truthy }
        let unseen = pool.filter { !seen($0) }
        let src = unseen.isEmpty ? pool : unseen
        let lastIdx = leaf.isNull ? -1 : (pool.firstIndex { $0.0 == leaf["kind"].string && $0.1 == leaf["id"].string } ?? -1)
        var chosen: (String, String)? = nil
        for k in 1...pool.count {
            let c = pool[((lastIdx + k) % pool.count + pool.count) % pool.count]
            if src.contains(where: { $0 == c }) { chosen = c; break }
        }
        let pickIt = chosen ?? src[Int(TextTools.hash(key) % UInt32(src.count))]
        doc["leaf"] = ["day": .string(key), "kind": .string(pickIt.0), "id": .string(pickIt.1)]
        save()
        return pickIt
    }

    /// The last coached answer not yet re-attempted, for "where you left off".
    public func lastCoached() -> (title: String, text: String, fix: String, ts: Double, target: Target)? {
        var items: [(String, String, String, Double, Target)] = []
        let fixOf: (String) -> String = { TextTools.coachParse($0)?["FIX"] ?? "" }
        for (pid, recs) in doc["planWork"].object {
            guard let pl = corpus.plan(pid) else { continue }
            for (k, r) in recs.object where !r["coach"].string.isEmpty && r["coachTs"].doubleValue != nil {
                let d = Int(k.split(separator: ":").first ?? "0") ?? 0
                items.append((pick(pl.title) + " · " + L("Day", "Tag") + " \(d + 1)", r["text"].string, fixOf(r["coach"].string), r["coachTs"].double, .planDay(pid, d)))
            }
        }
        for (id, r) in doc["voiceWork"].object where !r["coach"].string.isEmpty {
            if let v = corpus.voice(id) { items.append((v.name, r["text"].string, fixOf(r["coach"].string), r["coachTs"].double, .voice(id))) }
        }
        for (id, r) in doc["craftWork"].object where !r["coach"].string.isEmpty {
            if let f = corpus.figure(id) { items.append((L("Craft", "Handwerk") + " · " + pick(f.n), r["text"].string, fixOf(r["coach"].string), r["coachTs"].double, .figure(id))) }
        }
        guard let it = items.max(by: { $0.3 < $1.3 }), !it.2.isEmpty, nowMs - it.3 <= 21 * Self.day else { return nil }
        return (it.0, it.1, it.2, it.3, it.4)
    }

    public enum Target: Hashable { case planDay(String, Int), voice(String), figure(String) }

    // MARK: captures (commonplace book)

    public var captures: [JSONValue] { doc["captures"].array }
    public func saveCapture(id: String?, kind: String, title: String, body: String, concept: String?, tags: [String]) {
        var arr = doc["captures"].array
        if let id, let i = arr.firstIndex(where: { $0["id"].string == id }) {
            var c = arr[i]
            c["kind"] = .string(kind); c["title"] = .string(title); c["body"] = .string(body)
            c["concept"] = concept.map(JSONValue.string) ?? nil; c["tags"] = .array(tags.map(JSONValue.string))
            c["edited"] = true; c["example"] = false
            arr[i] = c
        } else {
            arr.insert(["id": .string(TextTools.uid(now: now())), "kind": .string(kind), "title": .string(title), "body": .string(body),
                        "concept": concept.map(JSONValue.string) ?? nil, "lang": .string(lang.rawValue),
                        "tags": .array(tags.map(JSONValue.string)), "ts": .number(nowMs)], at: 0)
        }
        doc["captures"] = .array(arr)
        save()
    }
    public func deleteCapture(_ id: String) {
        doc["captures"] = .array(doc["captures"].array.filter { $0["id"].string != id }); save()
    }

    // MARK: reflections

    public func reflection(for key: String? = nil) -> JSONValue {
        let k = key ?? todayKey
        return doc["reflections"].array.first { $0["date"].string == k }
            ?? ["id": .string(TextTools.uid(now: now())), "date": .string(k), "ts": .number(nowMs), "morning": "",
                "evening": .array(Array(repeating: "", count: 7))]
    }
    public func setReflection(_ f: (inout JSONValue) -> Void) {
        var r = reflection()
        f(&r)
        var arr = doc["reflections"].array
        if let i = arr.firstIndex(where: { $0["date"].string == r["date"].string }) { arr[i] = r } else { arr.insert(r, at: 0) }
        doc["reflections"] = .array(arr)
        save()
    }

    // MARK: rhetoric sessions

    public func logRhetoric(promptId: String, answer: String, secs: Int, lang lg: String, concept: String?, difficulty: String) {
        var arr = doc["sessions"].array
        arr.insert(["id": .string(TextTools.uid(now: now())), "type": "rhetoric", "prompt": .string(promptId),
                    "answer": .string(answer), "secs": .number(Double(secs)), "lang": .string(lg),
                    "concept": concept.map(JSONValue.string) ?? nil, "ts": .number(nowMs)], at: 0)
        doc["sessions"] = .array(arr)
        if answer.trimmingCharacters(in: .whitespacesAndNewlines).count > 30 {
            noteEvidence(concept, (difficulty == "hard" || difficulty == "expert") ? "hard" : "spoke", lang: Lang(rawValue: lg))
        }
        save()
    }

    public var lastConcept: String {
        get { doc["lastConcept"].stringValue ?? "control" }
        set { doc["lastConcept"] = .string(newValue); save() }
    }

    // MARK: sync metadata

    public var modified: Double { doc["modified"].double }
}
