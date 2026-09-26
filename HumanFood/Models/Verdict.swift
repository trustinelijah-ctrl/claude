import Foundation

struct AlternativeIdea: Codable, Hashable, Sendable, Identifiable {
    var title: String
    var reason: String
    var id: String { title }
}

/// The written "verdict" for a product. Generated once by AI (then cached
/// server-side for every user) or written locally from the score factors.
struct Verdict: Codable, Hashable, Sendable {
    enum Origin: String, Codable, Sendable { case ai, local }

    var headline: String
    var summary: String
    var highlights: [String]
    var considerations: [String]
    var alternatives: [AlternativeIdea]
    var tip: String?
    var origin: Origin

    /// Bump when the scoring rubric or prompt changes so stale verdicts refresh.
    static let rubricVersion = 1

    /// Runs every string through the safe-language filter.
    func sanitized(brand: String?) -> Verdict {
        var copy = self
        let clean = { (s: String) in SafeLanguage.clean(s, brand: brand) }
        copy.headline = clean(headline)
        copy.summary = clean(summary)
        copy.highlights = highlights.map(clean)
        copy.considerations = considerations.map(clean)
        copy.alternatives = alternatives.map { AlternativeIdea(title: clean($0.title), reason: clean($0.reason)) }
        copy.tip = tip.map(clean)
        return copy
    }
}
