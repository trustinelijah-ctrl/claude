import Foundation
import Observation
import SwiftData

/// State for one product's result screen.
@Observable
@MainActor
final class AnalysisModel: Identifiable {
    let id = UUID()
    let product: Product
    let score: ScoreResult
    /// True when this product was already in the user's history (no celebration toast).
    let isRevisit: Bool
    var verdict: Verdict?
    var alternatives: [ScoredProduct] = []
    var alternativesLoaded = false

    init(product: Product, score: ScoreResult, verdict: Verdict? = nil, isRevisit: Bool = false) {
        self.product = product
        self.score = score
        self.verdict = verdict
        self.isRevisit = isRevisit
    }

    func load(services: AppServices, context: ModelContext) async {
        let product = product
        let score = score
        let verdictService = services.verdicts
        let altService = services.alternatives
        let profile = services.preferences.profile
        let needsVerdict = verdict == nil

        let verdictTask: Task<Verdict?, Never> = Task {
            guard needsVerdict else { return nil }
            return await verdictService.verdict(for: product, score: score)
        }
        let altTask = Task {
            await altService.alternatives(for: product, currentScore: score.score, profile: profile)
        }

        if let v = await verdictTask.value {
            verdict = v
            // Only AI verdicts are cached; local ones are regenerated for free.
            if v.origin == .ai, let record = AppServices.record(for: product.barcode, in: context) {
                record.store(verdict: v)
                try? context.save()
            }
        }
        alternatives = await altTask.value
        alternativesLoaded = true
    }

    static func from(record: ScanRecord, services: AppServices) -> AnalysisModel? {
        guard let product = record.product else { return nil }
        return AnalysisModel(product: product, score: services.score(product),
                             verdict: record.cachedVerdict, isRevisit: true)
    }
}
