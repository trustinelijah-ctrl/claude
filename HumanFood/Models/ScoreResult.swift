import SwiftUI

enum ScoreTier: String, Codable, CaseIterable, Sendable {
    case excellent, good, fair, limit, rarely

    init(score: Int) {
        switch score {
        case 85...: self = .excellent
        case 70..<85: self = .good
        case 50..<70: self = .fair
        case 30..<50: self = .limit
        default: self = .rarely
        }
    }

    var title: String {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .fair: "Fair"
        case .limit: "Limit"
        case .rarely: "Rarely"
        }
    }

    /// Deliberately gentle, opinion-framed guidance.
    var phrase: String {
        switch self {
        case .excellent: "Enjoy freely"
        case .good: "A solid everyday pick"
        case .fair: "Fine now and then"
        case .limit: "Best kept occasional"
        case .rarely: "Worth swapping when you can"
        }
    }

    var color: Color {
        switch self {
        case .excellent: HF.Palette.excellent
        case .good: HF.Palette.good
        case .fair: HF.Palette.fair
        case .limit: HF.Palette.limit
        case .rarely: HF.Palette.rarely
        }
    }

    var celebrates: Bool { self == .excellent || self == .good }
}

struct ScoreFactor: Identifiable, Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable { case positive, consideration, info }
    enum Group: String, Codable, Sendable, CaseIterable {
        case processing, nutrients, ingredients, additives, animal
        var title: String {
            switch self {
            case .processing: "Processing"
            case .nutrients: "Nutrients"
            case .ingredients: "Ingredients"
            case .additives: "Additives"
            case .animal: "Animal foods"
            }
        }
    }

    var id: String
    var title: String
    var detail: String
    /// Points added (+) or removed (−) from the score.
    var impact: Int
    var kind: Kind
    var group: Group
    var symbol: String
}

struct ScoreResult: Hashable, Codable, Sendable {
    enum Confidence: String, Codable, Sendable { case high, medium, low }

    var score: Int
    var factors: [ScoreFactor]
    var confidence: Confidence
    /// Present when a rule capped the score (e.g. ultra-processed ceiling).
    var capNote: String?

    var tier: ScoreTier { ScoreTier(score: score) }
    var positives: [ScoreFactor] { factors.filter { $0.kind == .positive } }
    var considerations: [ScoreFactor] {
        factors.filter { $0.kind == .consideration }.sorted { $0.impact < $1.impact }
    }
}
