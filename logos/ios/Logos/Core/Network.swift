import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// The Netlify deployment both apps talk to. Changing it in Settings points
/// the phone at a different deploy (a preview, a fork) without a rebuild.
public enum Endpoint {
    public static let defaultBase = URL(string: "https://logosschool.netlify.app")!
    public static var base: URL {
        get { UserDefaults.standard.string(forKey: "logos.base").flatMap(URL.init(string:)) ?? defaultBase }
        set { UserDefaults.standard.set(newValue.absoluteString, forKey: "logos.base") }
    }
}

// MARK: - the reviewer

/// Prompts are the web app's PROMPTS, word for word, so the coach behaves the
/// same on both surfaces.
public enum CoachTask {
    case coach(question: String, hint: String, model: String, answer: String)
    case explain(topic: String, tradition: String, summary: String, points: [String])
    case recite(text: String, reference: String, said: String)

    public var prompt: String {
        switch self {
        case let .coach(question, hint, model, answer):
            return "You are a demanding but warm rhetoric coach. A learner answered a speaking exercise out loud and wrote down roughly what they said.\n\n" +
                "Exercise: " + question + "\n" +
                (hint.isEmpty ? "" : "What a good answer needs: " + hint + "\n") +
                (model.isEmpty ? "" : "One strong answer, for reference only (it is ONE way, not the answer): " + model + "\n") +
                "\nTheir answer:\n\"" + answer + "\"\n\n" +
                "Reply in exactly these four labelled lines and nothing else:\n" +
                "STRENGTH: the single best thing in their answer, quoting a few of their own words.\n" +
                "FIX: the one change that would most improve it next time — structure, a missing concession, a vague claim, an overclaim, or a missed opportunity. Be concrete.\n" +
                "REWRITE: take their weakest sentence and rewrite it so it lands, keeping their meaning and their position. Put only the rewritten sentence here, in quotation marks.\n" +
                "DEVICE: one rhetorical move that would have helped (for example antithesis, a tricolon, a concrete example, restating the objection more strongly, naming what the view costs) and show it in one short line using their material.\n\n" +
                "Rules. Do not praise a quotation, verse or citation unless you are confident its wording and attribution are correct; if one looks wrong or unverifiable, say so under FIX. " +
                "If their position differs from the reference answer but is a defensible reading, do not call it wrong — judge how well they argued it. " +
                "Judge only the words; you cannot hear pace, pauses or tone, so do not comment on them. No flattery, no preamble, under 130 words in total."
        case let .explain(topic, tradition, summary, points):
            return "A learner is studying \"" + topic + "\" and has just read the " + tradition + " teaching.\n" +
                "Summary: " + summary + "\n" +
                "Points: " + points.joined(separator: " | ") + "\n\n" +
                "Give one short clarification that adds something the lesson did not already say — " +
                "an example, a common misunderstanding, or where this shows up in ordinary life. " +
                "Stay strictly inside the " + tradition + " tradition; do not mention the other one."
        case let .recite(text, reference, said):
            return "The learner is memorising this passage:\n\"" + text + "\" (" + reference + ")\n\n" +
                "From memory they said:\n\"" + said + "\"\n\n" +
                "Judge it by MEANING, not exact wording — a correct paraphrase passes. " +
                "Say in one line whether they have it, then name anything missing in substance " +
                "(not synonyms, not word order). If a dropped clause changes the sense, quote just that clause. " +
                "Two or three sentences total."
        }
    }
}

public enum CoachError: Error, Equatable {
    case absent, timeout, network, rate, malformed, server

    public func reason(_ lang: Lang) -> String {
        let de = lang == .de
        switch self {
        case .timeout: return de ? "Die Rückmeldung hat zu lange gebraucht. Deine Antwort ist unverändert — versuch es noch einmal oder mach weiter." : "The reviewer took too long. Your answer is untouched — try again or carry on."
        case .network: return de ? "Keine Verbindung zur Rückmeldung. Deine Antwort ist unverändert." : "No connection to the reviewer. Your answer is untouched."
        case .rate: return de ? "Gerade zu viele Anfragen. Versuch es gleich noch einmal." : "Too many requests just now. Try again shortly."
        case .malformed: return de ? "Die Rückmeldung war unlesbar. Es wurde nichts verändert." : "The reviewer sent something unreadable. Nothing has been changed."
        case .server: return de ? "Die Rückmeldung hat ein Problem. Deine Antwort ist unverändert." : "The reviewer is having trouble. Your answer is untouched."
        case .absent: return de ? "Keine Rückmeldung verbunden. Alles hier funktioniert auch ohne." : "No reviewer is connected. Everything here still works without one."
        }
    }
}

public struct CoachClient {
    public var base: URL
    public var session: URLSession
    public init(base: URL = Endpoint.base, session: URLSession = .shared) { self.base = base; self.session = session }

    /// Never throws past the caller's text: every failure is a CoachError the UI explains.
    public func run(_ task: CoachTask, exerciseLang: Lang) async -> Result<String, CoachError> {
        var prompt = task.prompt
        prompt += exerciseLang == .de ? "\n\nAntworte auf Deutsch." : "\n\nAnswer in English."
        var req = URLRequest(url: base.appendingPathComponent(".netlify/functions/ai"))
        req.httpMethod = "POST"
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["prompt": prompt])
        do {
            let (data, resp) = try await session.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else {
                if code == 404 || code == 503 { return .failure(.absent) }
                if code == 429 { return .failure(.rate) }
                return .failure(.server)
            }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = (obj["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
            else { return .failure(.malformed) }
            return .success(text)
        } catch let e as URLError where e.code == .timedOut {
            return .failure(.timeout)
        } catch {
            return .failure(.network)
        }
    }
}

// MARK: - content updates

/// Fetches /corpus.json from the deploy. A content edit to the web app that is
/// deployed to Netlify reaches installed phones on their next launch.
public struct CorpusUpdater {
    public var base: URL
    public var cacheURL: URL
    public var session: URLSession
    public init(base: URL = Endpoint.base, cacheURL: URL, session: URLSession = .shared) {
        self.base = base; self.cacheURL = cacheURL; self.session = session
    }

    public func cached() -> Corpus? {
        guard let d = try? Data(contentsOf: cacheURL), let c = try? Corpus(data: d), c.failures.isEmpty else { return nil }
        return c
    }

    /// Returns a newer corpus if the deploy has one that decodes cleanly.
    public func fetchNewer(than version: String) async -> Corpus? {
        var req = URLRequest(url: base.appendingPathComponent("corpus.json"))
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 20
        guard let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let c = try? Corpus(data: data), c.failures.isEmpty, c.version != version,
              !c.path.isEmpty, !c.lessons.isEmpty
        else { return nil }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
        return c
    }
}

// MARK: - sync

/// End-to-end-encrypted sync through the deploy's /api/sync function. The
/// browser implements the same scheme with WebCrypto; see web/sync.js.
public struct SyncCode: Equatable {
    public static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    public let normalized: String

    public init?(_ raw: String) {
        let n = raw.uppercased().filter { Self.alphabet.contains($0) }
        guard n.count == 20 else { return nil }
        normalized = String(n)
    }
    public static func generate() -> SyncCode {
        var g = SystemRandomNumberGenerator()
        return SyncCode(String((0..<20).map { _ in alphabet[Int(g.next() % 32)] }))!
    }
    /// ABCD-EFGH-JKLM-NPQR-STUV
    public var display: String {
        stride(from: 0, to: 20, by: 4).map { i in
            let a = normalized.index(normalized.startIndex, offsetBy: i)
            return String(normalized[a..<normalized.index(a, offsetBy: 4)])
        }.joined(separator: "-")
    }
    public var id: String {
        SHA256.hash(data: Data(("logos-sync-id:" + normalized).utf8)).map { String(format: "%02x", $0) }.joined()
    }
    var key: SymmetricKey { SymmetricKey(data: Data(SHA256.hash(data: Data(("logos-sync-key:" + normalized).utf8)))) }

    /// base64(nonce(12) || ciphertext || tag(16)) — WebCrypto AES-GCM compatible.
    public func seal(_ plaintext: Data) throws -> String {
        try AES.GCM.seal(plaintext, using: key).combined!.base64EncodedString()
    }
    public func open(_ b64: String) throws -> Data {
        guard let d = Data(base64Encoded: b64) else { throw SyncError.corrupt }
        return try AES.GCM.open(try AES.GCM.SealedBox(combined: d), using: key)
    }
}

public enum SyncError: Error, Equatable { case corrupt, network, server(Int), wrongCode }

public struct SyncRemote: Equatable { public var updated: Double; public var doc: JSONValue }

public struct SyncClient {
    public var code: SyncCode
    public var base: URL
    public var session: URLSession
    public init(code: SyncCode, base: URL = Endpoint.base, session: URLSession = .shared) {
        self.code = code; self.base = base; self.session = session
    }
    var url: URL { base.appendingPathComponent("api/sync/" + code.id) }

    public func pull() async throws -> SyncRemote? {
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await session.data(for: req) } catch { throw SyncError.network }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }
        guard status == 200, let obj = try? JSONDecoder().decode(JSONValue.self, from: data),
              let blob = obj["blob"].stringValue else { throw SyncError.server(status) }
        let plain: Data
        do { plain = try code.open(blob) } catch { throw SyncError.wrongCode }
        guard let payload = try? JSONDecoder().decode(JSONValue.self, from: plain), payload["app"].string == "logos",
              payload["data"].objectValue != nil else { throw SyncError.corrupt }
        return SyncRemote(updated: obj["updated"].double, doc: payload["data"])
    }

    public func push(doc: JSONValue, updated: Double) async throws {
        let payload: JSONValue = ["app": "logos", "version": 2, "data": doc]
        let blob = try code.seal(try JSONEncoder().encode(payload))
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["updated": updated, "blob": blob])
        let resp: URLResponse
        do { (_, resp) = try await session.data(for: req) } catch { throw SyncError.network }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw SyncError.server(status) }
    }
}

/// What a sync should do, given when each side last changed.
public enum SyncPlan: Equatable {
    case push, pull, upToDate, conflict

    /// - local: this device's document `modified`
    /// - remote: the stored copy's `updated`, nil if nothing is stored yet
    /// - lastSync: the `updated` value this device last pushed or pulled
    public static func decide(local: Double, remote: Double?, lastSync: Double) -> SyncPlan {
        guard let remote else { return .push }
        let localChanged = local > lastSync
        let remoteChanged = remote > lastSync
        switch (localChanged, remoteChanged) {
        case (false, false): return .upToDate
        case (true, false): return .push
        case (false, true): return .pull
        case (true, true): return .conflict
        }
    }
}
