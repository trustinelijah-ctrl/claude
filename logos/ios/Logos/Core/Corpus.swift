import Foundation

public enum Lang: String, Codable, CaseIterable, Identifiable {
    case en, de
    public var id: String { rawValue }
    public var other: Lang { self == .en ? .de : .en }
    public var locale: Locale { Locale(identifier: self == .en ? "en-US" : "de-DE") }
}

/// A bilingual string. The corpus writes these as {en, de}; a few older
/// entries use a bare string or an [en, de] pair, and all three decode.
public struct LS: Codable, Hashable {
    public var en: String
    public var de: String
    public init(_ en: String, _ de: String) { self.en = en; self.de = de }

    public init(from decoder: Decoder) throws {
        if let c = try? decoder.container(keyedBy: K.self) {
            en = (try? c.decodeIfPresent(String.self, forKey: .en)) ?? ""
            de = (try? c.decodeIfPresent(String.self, forKey: .de)) ?? ""
            return
        }
        let s = try decoder.singleValueContainer()
        if let str = try? s.decode(String.self) { en = str; de = str; return }
        let pair = try s.decode([String].self)
        en = pair.first ?? ""; de = pair.count > 1 ? pair[1] : en
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(en, forKey: .en); try c.encode(de, forKey: .de)
    }
    enum K: String, CodingKey { case en, de }

    public func callAsFunction(_ lang: Lang) -> String {
        let v = lang == .de ? de : en
        return v.isEmpty ? (lang == .de ? en : de) : v
    }
    public var isEmpty: Bool { en.isEmpty && de.isEmpty }
}

public struct Scripture: Codable, Hashable {
    public var ref: String
    public var refDe: String?
    public var book: String?
    public var en: String
    public var de: String
    public var pen: String?
    public var pde: String?
    public var ctx: LS?
}

public struct Passage: Codable, Hashable {
    public var ref: String?
    public var work: String?
    public var author: String
    public var en: String
    public var de: String
    public var gist: String?
    public var tr: String?
    public var cite: String?
}

public struct Concept: Codable, Hashable, Identifiable {
    public struct Speak: Codable, Hashable { public var s30: LS?; public var m2: LS?; public var m5: LS? }
    public var id: String
    public var t: LS
    public var gloss: String?
    public var overview: LS?
    public var christian: LS?
    public var stoic: LS?
    public var agree: LS?
    public var tension: LS?
    public var scripture: [String]?
    public var sources: [String]?
    public var position: LS?
    public var objections: [LS]?
    public var responses: [LS]?
    public var lines: [LS]?
    public var application: LS?
    public var speak: Speak?
    public var related: [String]?
}

/// A recall card. Seeded cards come from the corpus; cards the learner saves
/// live in the document's `extra` array in exactly this shape.
public struct MemoryItem: Codable, Hashable, Identifiable {
    public var id: String
    public var mode: String
    public var concept: String?
    public var ref: String?
    public var q: LS
    public var a: LS
    public var src: String?
    public var qk: String?
    public var own: Bool?
}

public struct RhetoricPrompt: Codable, Hashable, Identifiable {
    public var id: String
    public var concept: String
    public var lang: String
    public var format: String
    public var difficulty: String
    public var who: String
    public var secs: Int
    public var q: String
    public var structure: String
    public var sources: [String]
    public var better: String
}

public struct FollowUp: Codable, Hashable { public var q: LS; public var hint: LS }

public struct SpeechLine: Codable, Hashable, Identifiable {
    public var id: String; public var cat: String; public var en: String; public var de: String
}

public struct Source: Codable, Hashable, Identifiable {
    public var id: String
    public var cat: String
    public var title: String
    public var author: String
    public var edition: String?
    public var progress: Double?
    public var note: LS?
}

public struct CaptureSeed: Codable, Hashable, Identifiable {
    public var id: String; public var kind: String; public var title: String; public var body: String
    public var concept: String?; public var lang: String?; public var tags: [String]?
}

public struct Argument: Codable, Hashable, Identifiable {
    public var id: String
    public var concept: String?
    public var question: LS
    public var thesis: LS
    public var why: LS?
    public var scripture: [String]
    public var sources: [String]
    public var objection: LS?
    public var steelman: LS?
    public var response: LS?
    public var counter: LS?
    public var limits: LS?
    public var s30: LS?
    public var line: LS?
}

public struct CheckQuestion: Codable, Hashable {
    public var q: LS
    public var opts: [LS]
    public var a: Int
    public var why: LS
}

public struct SayTask: Codable, Hashable {
    public var q: LS
    public var hint: LS
    public var model: LS
    public var secs: Int?
}

public struct Lesson: Codable, Hashable {
    public struct Side: Codable, Hashable {
        public var summary: LS
        public var points: [LS]
        public var quotes: [String]
    }
    public var plate: String?
    public var intro: LS
    public var christian: Side
    public var stoic: Side
    public var check: [CheckQuestion]
    public var say: SayTask?
    public var tension: LS?
}

public struct PlanStep: Codable, Hashable {
    public var t: String
    public var title: LS?
    public var body: LS?
    public var lesson: String?
    public var side: String?
    public var keys: [String]?
    public var concept: String?
    public var key: String?
    public var q: LS?
    public var hint: LS?
    public var model: LS?
    public var secs: Int?
    public var i: Int?
}

public struct PlanDay: Codable, Hashable {
    public var title: LS
    public var aim: LS?
    public var steps: [PlanStep]
}

public struct Plan: Codable, Hashable, Identifiable {
    public var id: String
    public var plate: String?
    public var title: LS
    public var blurb: LS?
    public var days: [PlanDay]
}

public struct PathUnit: Codable, Hashable, Identifiable {
    public var id: String
    public var kind: String
    public var ref: String
    public var assumes: [String]
    public var can: LS
}

public struct PathStage: Codable, Hashable, Identifiable {
    public var stage: Int
    public var name: LS
    public var aim: LS
    public var units: [PathUnit]
    public var id: Int { stage }
}

public struct Voice: Codable, Hashable, Identifiable {
    public struct Quote: Codable, Hashable {
        public struct Also: Codable, Hashable { public var en: String?; public var orig: String?; public var src: String? }
        public var en: String?
        public var orig: String?
        public var origLang: String?
        public var src: String?
        public var de: String?
        public var deKind: String?
        public var kind: String?
        public var para: LS?
        public var also: Also?
    }
    public var id: String
    public var name: String
    public var years: String
    public var trad: String
    public var place: LS
    public var status: String?
    public var concepts: [String]?
    public var hook: LS
    public var scene: LS
    public var quote: Quote
    public var use: LS
    public var limit: LS
    public var drill: SayTask
    public var check: String?
}

public struct Figure: Codable, Hashable, Identifiable {
    public struct Specimen: Codable, Hashable { public var k: String?; public var voice: String?; public var note: LS? }
    public var id: String
    public var term: String
    public var n: LS
    public var def: LS
    public var why: LS
    public var specimens: [Specimen]
    public var german: LS?
    public var flat: LS
    public var model: LS
}

public struct Depth: Codable, Hashable {
    public struct Part: Codable, Hashable { public var story: LS?; public var life: LS? }
    public var c: Part?
    public var s: Part?
}

public struct Deepen: Codable, Hashable {
    public var f: LS?; public var dist: LS?; public var c: LS?; public var s: LS?; public var obj: LS?; public var rep: LS?
}

public struct Think: Codable, Hashable { public var t: LS; public var a: LS; public var b: LS; public var q: LS }
public struct Builds: Codable, Hashable { public var from: LS?; public var t: LS?; public var body: LS? }
public struct HeadedBlock: Codable, Hashable { public var h: LS; public var b: LS }
public struct SaidWell: Codable, Hashable { public var bad: LS; public var well: LS; public var note: LS? }
public struct Card: Codable, Hashable { public var claim: LS?; public var moves: [LS]?; public var lines: [LS]?; public var cost: LS? }
public struct Translation: Codable, Hashable { public var en: String; public var de: String; public var note: LS? }

public struct Module: Codable, Hashable {
    public struct Claim: Codable, Hashable { public var label: String?; public var text: LS; public var cite: String?; public var url: String? }
    public struct WorkedStep: Codable, Hashable { public var principle: LS; public var text: LS; public var options: [LS]; public var a: Int }
    public struct Worked: Codable, Hashable { public var question: LS; public var steps: [WorkedStep] }
    public struct Faded: Codable, Hashable { public var removed: Int; public var question: LS; public var prompt: LS? }
    public struct Independent: Codable, Hashable { public var q: LS; public var hint: LS }
    public struct Transfer: Codable, Hashable { public var kind: String; public var q: LS; public var hint: LS; public var model: LS }
    public struct Teaching: Codable, Hashable {
        public struct Body: Codable, Hashable { public var h: LS; public var p: LS }
        public var hook: LS; public var body: [Body]
    }
    public var pack: String?
    public var title: LS
    public var sub: LS?
    public var claims: [Claim]
    public var worked: Worked
    public var faded: [Faded]
    public var independent: Independent
    public var transfer: [Transfer]
    public var teaching: Teaching
}

/// Everything LOGOS teaches. Generated from the web app by
/// scripts/extract-corpus.mjs, bundled with the app, and refreshed from
/// https://<site>/corpus.json when a newer version is deployed.
public struct Corpus {
    public var version: String = "empty"
    public var scripture: [String: Scripture] = [:]
    public var passages: [String: Passage] = [:]
    public var mastery: [LS] = []
    public var concepts: [Concept] = []
    public var memorySeed: [MemoryItem] = []
    public var rhetoric: [RhetoricPrompt] = []
    public var followUps: [String: FollowUp] = [:]
    public var speech: [SpeechLine] = []
    public var speechCats: [String: LS] = [:]
    public var sources: [Source] = []
    public var sourceCats: [String: LS] = [:]
    public var captureSeed: [CaptureSeed] = []
    public var kinds: [String: LS] = [:]
    public var arguments: [Argument] = []
    public var formats: [String: LS] = [:]
    public var who: [String: LS] = [:]
    public var diff: [String: LS] = [:]
    public var eveningQ: [LS] = []
    public var lessons: [String: Lesson] = [:]
    public var plain: [String: [String]] = [:]
    public var translations: [String: Translation] = [:]
    public var plans: [Plan] = []
    public var path: [PathStage] = []
    public var cards: [String: Card] = [:]
    public var voices: [Voice] = []
    public var voiceKind: [String: LS] = [:]
    public var figures: [Figure] = []
    public var modes: [String: LS] = [:]
    public var modeTier: [String: Int] = [:]
    public var depth: [String: Depth] = [:]
    public var deepen: [String: Deepen] = [:]
    public var think: [String: Think] = [:]
    public var qwhy: [String: LS] = [:]
    public var modules: [String: Module] = [:]
    public var builds: [String: Builds] = [:]
    public var planQ: [String: CheckQuestion] = [:]
    public var planDepth: [String: [HeadedBlock]] = [:]
    public var planThink: [String: Think] = [:]
    public var saidWell: [String: SaidWell] = [:]
    public var pqwhy: [String: LS] = [:]
    public var plates: [String: String] = [:]
    public var lessonIDs: [String] = []
    /// Datasets that failed to decode. Empty in a healthy build; the tests assert it.
    public var failures: [String] = []

    public init() {}

    /// Decodes each dataset on its own, so one malformed section costs that
    /// section rather than the whole app.
    public init(data: Data) throws {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard root["app"] as? String == "logos" else { throw CorpusError.notLogos }
        version = root["version"] as? String ?? "unknown"
        var failed: [String] = []
        func get<T: Decodable>(_ key: String, _ type: T.Type) -> T? {
            guard let raw = root[key], !(raw is NSNull) else { failed.append(key); return nil }
            do {
                let d = try JSONSerialization.data(withJSONObject: raw)
                return try JSONDecoder().decode(T.self, from: d)
            } catch {
                failed.append("\(key): \(error)")
                return nil
            }
        }
        scripture = get("SCRIPTURE", [String: Scripture].self) ?? [:]
        passages = get("PASSAGES", [String: Passage].self) ?? [:]
        mastery = get("MASTERY", [LS].self) ?? []
        concepts = get("CONCEPTS", [Concept].self) ?? []
        memorySeed = get("MEMORY_SEED", [MemoryItem].self) ?? []
        rhetoric = get("RHETORIC", [RhetoricPrompt].self) ?? []
        followUps = get("RH_FOLLOW", [String: FollowUp].self) ?? [:]
        speech = get("SPEECH", [SpeechLine].self) ?? []
        speechCats = get("SPEECH_CATS", [String: LS].self) ?? [:]
        sources = get("SOURCES", [Source].self) ?? []
        sourceCats = get("SOURCE_CATS", [String: LS].self) ?? [:]
        captureSeed = get("CAPTURE_SEED", [CaptureSeed].self) ?? []
        kinds = get("KINDS", [String: LS].self) ?? [:]
        arguments = get("ARGUMENTS", [Argument].self) ?? []
        formats = get("FORMATS", [String: LS].self) ?? [:]
        who = get("WHO", [String: LS].self) ?? [:]
        diff = get("DIFF", [String: LS].self) ?? [:]
        eveningQ = get("EVENING_Q", [LS].self) ?? []
        lessons = get("LESSONS", [String: Lesson].self) ?? [:]
        plain = get("PLAIN", [String: [String]].self) ?? [:]
        translations = get("TRANSLATIONS", [String: Translation].self) ?? [:]
        plans = get("PLANS", [Plan].self) ?? []
        path = get("PATH", [PathStage].self) ?? []
        cards = get("CARDS", [String: Card].self) ?? [:]
        voices = get("VOICES", [Voice].self) ?? []
        voiceKind = get("VOICE_KIND", [String: LS].self) ?? [:]
        figures = get("FIGURES", [Figure].self) ?? []
        modes = get("MODES", [String: LS].self) ?? [:]
        modeTier = get("MODE_TIER", [String: Int].self) ?? [:]
        depth = get("DEPTH", [String: Depth].self) ?? [:]
        deepen = get("DEEPEN", [String: Deepen].self) ?? [:]
        think = get("THINK", [String: Think].self) ?? [:]
        qwhy = get("QWHY", [String: LS].self) ?? [:]
        modules = get("MODULES", [String: Module].self) ?? [:]
        builds = get("BUILDS", [String: Builds].self) ?? [:]
        planQ = get("PLAN_Q", [String: CheckQuestion].self) ?? [:]
        planDepth = get("PLAN_DEPTH", [String: [HeadedBlock]].self) ?? [:]
        planThink = get("PLAN_THINK", [String: Think].self) ?? [:]
        saidWell = get("SAIDW", [String: SaidWell].self) ?? [:]
        pqwhy = get("PQWHY", [String: LS].self) ?? [:]
        plates = get("PLATES", [String: String].self) ?? [:]
        lessonIDs = get("LESSON_IDS", [String].self) ?? lessons.keys.sorted()
        failures = failed
    }

    public enum CorpusError: Error { case notLogos }

    // MARK: lookups

    public func concept(_ id: String?) -> Concept? { guard let id else { return nil }; return concepts.first { $0.id == id } }
    public func plan(_ id: String) -> Plan? { plans.first { $0.id == id } }
    public func voice(_ id: String) -> Voice? { voices.first { $0.id == id } }
    public func figure(_ id: String) -> Figure? { figures.first { $0.id == id } }
    public func source(_ id: String) -> Source? { sources.first { $0.id == id } }
    public func argument(_ id: String) -> Argument? { arguments.first { $0.id == id } }
    public func unit(_ id: String) -> PathUnit? {
        for s in path { if let u = s.units.first(where: { $0.id == id }) { return u } }
        return nil
    }
    public func stage(of unit: PathUnit) -> PathStage? { path.first { $0.units.contains(unit) } }
    public var allUnits: [PathUnit] { path.flatMap(\.units) }
}
