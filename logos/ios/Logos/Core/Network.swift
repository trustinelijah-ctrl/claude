import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// The Netlify deployment both apps talk to.
public enum Endpoint {
    public static let base = URL(string: "https://logosschool.netlify.app")!
}

// MARK: - the reviewer

/// One reviewer request. The prompt templates live in the `ai` function, so
/// the app sends only which exercise this is and the learner's words.
public enum CoachTask {
    case coach(question: String, hint: String, model: String, answer: String)
    case craft(figure: String, def: String, flat: String, answer: String)
    case explain(topic: String, tradition: String, summary: String, points: [String])
    case recite(text: String, reference: String, said: String)

    public var body: [String: Any] {
        switch self {
        case let .coach(question, hint, model, answer):
            return ["task": "coach", "input": ["question": question, "hint": hint, "model": model, "answer": answer]]
        case let .craft(figure, def, flat, answer):
            return ["task": "craft", "input": ["figure": figure, "def": def, "flat": flat, "answer": answer]]
        case let .explain(topic, tradition, summary, points):
            return ["task": "explain", "input": ["topic": topic, "tradition": tradition, "summary": summary, "points": points]]
        case let .recite(text, reference, said):
            return ["task": "recite", "input": ["text": text, "reference": reference, "said": said]]
        }
    }
}

public enum CoachError: Error, Equatable {
    case absent, timeout, network, rate, malformed, server

    public func reason(_ lang: Lang) -> String {
        let de = lang == .de
        switch self {
        case .timeout: return de ? "Die Rückmeldung hat zu lange gebraucht. Deine Antwort ist unverändert. Versuch es noch einmal oder mach weiter." : "The reviewer took too long. Your answer is untouched. Try again or carry on."
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
        var body = task.body
        body["lang"] = exerciseLang.rawValue
        var req = URLRequest(url: base.appendingPathComponent(".netlify/functions/ai"))
        req.httpMethod = "POST"
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
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

/// Fetches /corpus.json from the deploy, so a content edit deployed to
/// Netlify reaches installed phones on their next launch.
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

/// Encrypted sync through the deploy's /api/sync function. The browser
/// implements the same scheme with WebCrypto (web/sync.js).
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
    public var id: String { Self.hex("logos-sync-id:" + normalized) }
    /// Sent with every request so the server can tell the code's holder from someone who only knows the id.
    public var auth: String { Self.hex("logos-sync-auth:" + normalized) }
    static func hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    var key: SymmetricKey { SymmetricKey(data: Data(SHA256.hash(data: Data(("logos-sync-key:" + normalized).utf8)))) }

    /// base64(nonce(12) || ciphertext || tag(16)), readable by WebCrypto AES-GCM.
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
        req.setValue(code.auth, forHTTPHeaderField: "X-Sync-Auth")
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
        req.setValue(code.auth, forHTTPHeaderField: "X-Sync-Auth")
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
