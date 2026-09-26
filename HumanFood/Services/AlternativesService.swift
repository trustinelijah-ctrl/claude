import Foundation

/// Finds real products in the same category that score meaningfully higher.
/// Uses the same local scoring engine, so comparisons are like-for-like.
struct AlternativesService: Sendable {
    let off: OpenFoodFactsClient

    func alternatives(for product: Product, currentScore: Int, profile: ScoringProfile) async -> [ScoredProduct] {
        guard currentScore < 85 else { return [] }
        // Only canonical taxonomy tags — OFF data sometimes contains free-text entries.
        let tags = product.categories.filter { $0.range(of: #"^en:[a-z0-9-]+$"#, options: .regularExpression) != nil }
        guard !tags.isEmpty else { return [] }

        // Most specific category first, then its parent.
        let categoryTags = Array(tags.suffix(2).reversed())
        let countries: [String?] = OpenFoodFactsClient.countryTag.map { [$0, nil] } ?? [nil]
        var best: [ScoredProduct] = []

        for tag in categoryTags {
            for country in countries {
                if Task.isCancelled { return best }
                guard let found = try? await off.products(inCategory: tag, country: country) else { continue }
                var seenNames = Set<String>()
                let ranked = found
                    .filter { $0.barcode != product.barcode }
                    .map { ScoredProduct(product: $0, score: ScoringEngine.score($0, profile: profile)) }
                    // Only compare against products with full data, so missing fields never look "healthier".
                    .filter { $0.score.score >= max(currentScore + 8, 40) && $0.score.confidence == .high }
                    .sorted { $0.score.score > $1.score.score }
                    .filter { seenNames.insert($0.product.name.lowercased()).inserted }
                if ranked.count > best.count { best = Array(ranked.prefix(6)) }
                if best.count >= 3 { return best }
            }
        }
        return best
    }
}
