import Foundation

/// Ports of the web app's small text algorithms. They must match the
/// JavaScript bit for bit — same shuffles, same gaps, same scores — so a
/// learner moving between the web and the phone sees the same exercise.
public enum TextTools {

    // JS: seed = (seed * 31 + charCodeAt(i)) >>> 0, over UTF-16 code units.
    static func hash(_ s: String, seed start: UInt32 = 0) -> UInt32 {
        var seed = start
        for u in s.utf16 { seed = seed &* 31 &+ UInt32(u) }
        return seed
    }

    static func lcg(_ seed: UInt32) -> UInt32 { seed &* 1664525 &+ 1013904223 }

    /// The fixed display order of a question's options.
    public static func optionOrder(question: LS, count n: Int) -> [Int] {
        var idx = Array(0..<n)
        let key = !question.en.isEmpty ? question.en : question.de
        var seed = hash(key)
        var i = n - 1
        while i > 0 {
            seed = lcg(seed)
            let j = Int(seed % UInt32(i + 1))
            idx.swapAt(i, j)
            i -= 1
        }
        return idx
    }

    // [A-Za-zÀ-ÿ]
    static func isLetter(_ u: Unicode.Scalar) -> Bool {
        let v = u.value
        return (v >= 65 && v <= 90) || (v >= 97 && v <= 122) || (v >= 0xC0 && v <= 0xFF)
    }

    /// String(text).split(/(\s+)/) keeping the whitespace runs as tokens.
    public static func tokenise(_ text: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var curIsSpace: Bool? = nil
        for ch in text {
            let sp = ch.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
            if curIsSpace == nil || curIsSpace == sp { cur.append(ch) }
            else { out.append(cur); cur = String(ch) }
            curIsSpace = sp
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    public static func isWord(_ t: String) -> Bool { t.unicodeScalars.contains(where: isLetter) }

    /// t.replace(/[^A-Za-zÀ-ÿ']/g, "")
    public static func core(_ t: String) -> String {
        String(String.UnicodeScalarView(t.unicodeScalars.filter { isLetter($0) || $0 == "'" }))
    }

    /// Which token indices are blanked at a memorise stage (0…4).
    public static func gaps(for text: String, stage: Int, seed seedStr: String) -> [Int] {
        let toks = tokenise(text)
        var wordIdx: [Int] = []
        for (i, t) in toks.enumerated() where isWord(t) && core(t).utf16.count > 1 { wordIdx.append(i) }
        if stage <= 0 { return [] }
        let frac = [0, 0.25, 0.5, 0.78, 1][min(stage, 4)]
        let want = max(1, Int((Double(wordIdx.count) * frac).rounded(.toNearestOrAwayFromZero)))
        var seed = hash(seedStr)
        seed = seed &+ UInt32(stage * 7919)
        var scored: [(i: Int, s: Int, order: Int)] = []
        for (n, i) in wordIdx.enumerated() {
            seed = lcg(seed)
            scored.append((i, core(toks[i]).utf16.count * 2 + Int((seed >> 16) % 7), n))
        }
        // Array.prototype.sort is stable; keep ties in their original order.
        scored.sort { $0.s != $1.s ? $0.s > $1.s : $0.order < $1.order }
        return scored.prefix(want).map(\.i).sorted()
    }

    /// Lower-cased runs of [a-zà-ÿ'].
    static func words(_ s: String) -> [String] {
        var out: [String] = []
        var cur = String.UnicodeScalarView()
        for u in s.lowercased().unicodeScalars {
            let v = u.value
            if (v >= 97 && v <= 122) || (v >= 0xE0 && v <= 0xFF) || u == "'" { cur.append(u) }
            else if !cur.isEmpty { out.append(String(cur)); cur = String.UnicodeScalarView() }
        }
        if !cur.isEmpty { out.append(String(cur)) }
        return out
    }

    /// Percentage of the text's words recited in order.
    public static func similarity(said: String, text: String) -> Int {
        let a = words(said), b = words(text)
        if b.isEmpty { return 0 }
        var i = 0, hit = 0
        for w in b {
            if i < a.count, let at = a[i...].firstIndex(of: w) { hit += 1; i = at + 1 }
        }
        return Int((Double(hit) / Double(b.count) * 100).rounded(.toNearestOrAwayFromZero))
    }

    /// Token-by-token hit/miss marks for the recited text.
    public static func diff(said: String, text: String) -> [(token: String, hit: Bool?)] {
        let a = words(said)
        var i = 0
        return tokenise(text).map { t in
            guard isWord(t) else { return (t, nil) }
            let w = core(t).lowercased()
            if i < a.count, let at = a[i...].firstIndex(of: w) { i = at + 1; return (t, true) }
            return (t, false)
        }
    }

    public static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Splits prose written with blank lines between its moves.
    public static func paragraphs(_ s: String) -> [String] {
        s.components(separatedBy: "\n").reduce(into: [[String]]([[]])) { acc, line in
            if line.trimmingCharacters(in: .whitespaces).isEmpty { if !(acc.last?.isEmpty ?? true) { acc.append([]) } }
            else { acc[acc.count - 1].append(line) }
        }
        .filter { !$0.isEmpty }
        .map { $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// "u" + base36(ms) + base36(rand) — the web's id shape.
    public static func uid(now: Date = Date()) -> String {
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        return "u" + String(ms, radix: 36) + String(Int.random(in: 0..<10000), radix: 36)
    }

    /// Parses the coach's four labelled lines (English or German labels).
    public static func coachParse(_ txt: String) -> [String: String]? {
        let map = ["STÄRKE": "STRENGTH", "KORREKTUR": "FIX", "NEUFASSUNG": "REWRITE", "STILMITTEL": "DEVICE"]
        let labels = ["STRENGTH", "FIX", "REWRITE", "DEVICE", "STÄRKE", "KORREKTUR", "NEUFASSUNG", "STILMITTEL"]
        var out: [String: String] = [:]
        var cur: String? = nil
        for raw in txt.components(separatedBy: .newlines) where !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            var line = raw.trimmingCharacters(in: .whitespaces)
            while line.hasPrefix("*") { line.removeFirst(); line = line.trimmingCharacters(in: .whitespaces) }
            var matched: String? = nil
            for l in labels where line.uppercased().hasPrefix(l) {
                var rest = String(line.dropFirst(l.count)).trimmingCharacters(in: .whitespaces)
                while rest.hasPrefix("*") { rest.removeFirst(); rest = rest.trimmingCharacters(in: .whitespaces) }
                if rest.hasPrefix(":") || rest.hasPrefix("：") {
                    matched = map[l] ?? l
                    var value = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
                    while value.hasPrefix("*") { value.removeFirst() }
                    out[matched!] = value.trimmingCharacters(in: .whitespaces)
                }
                break
            }
            if let m = matched { cur = m }
            else if let c = cur { out[c, default: ""] += " " + line }
        }
        return ["STRENGTH", "FIX", "REWRITE", "DEVICE"].allSatisfy({ (out[$0] ?? "").isEmpty }) ? nil : out
    }
}
