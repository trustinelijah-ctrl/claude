import Foundation
import Observation
import SwiftData

/// Dependency container injected into the environment.
@Observable
@MainActor
final class AppServices {
    let config: AppConfig
    let off: OpenFoodFactsClient
    let verdicts: VerdictService
    let alternatives: AlternativesService
    let preferences: Preferences
    let streak: StreakStore

    init(config: AppConfig = .current) {
        self.config = config
        off = OpenFoodFactsClient()
        verdicts = VerdictService(config: config)
        alternatives = AlternativesService(off: off)
        preferences = Preferences()
        streak = StreakStore()
    }

    enum LookupResult {
        case found(Product, fromCache: Bool)
        case notFound
        case failed(Error)
    }

    /// Local cache → Open Food Facts → Human Food community database.
    func lookup(barcode: String, context: ModelContext) async -> LookupResult {
        if let record = Self.record(for: barcode, in: context), let product = record.product {
            return .found(product, fromCache: true)
        }
        do {
            let product = try await off.product(barcode: barcode)
            return .found(product, fromCache: false)
        } catch OpenFoodFactsClient.LookupError.notFound {
            if let community = await verdicts.communityProduct(barcode: barcode) {
                return .found(community, fromCache: false)
            }
            return .notFound
        } catch {
            if let community = await verdicts.communityProduct(barcode: barcode) {
                return .found(community, fromCache: false)
            }
            return .failed(error)
        }
    }

    func score(_ product: Product) -> ScoreResult {
        ScoringEngine.score(product, profile: preferences.profile)
    }

    /// Saves or refreshes the history entry for a scanned product.
    @discardableResult
    func remember(_ product: Product, score: ScoreResult, context: ModelContext) -> ScanRecord {
        let record: ScanRecord
        if let existing = Self.record(for: product.barcode, in: context) {
            existing.update(product: product, score: score.score)
            existing.lastScannedAt = .now
            existing.scanCount += 1
            record = existing
        } else {
            record = ScanRecord(product: product, score: score.score)
            context.insert(record)
        }
        try? context.save()
        return record
    }

    static func record(for barcode: String, in context: ModelContext) -> ScanRecord? {
        var descriptor = FetchDescriptor<ScanRecord>(predicate: #Predicate { $0.barcode == barcode })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func normalise(barcode raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard (6...14).contains(digits.count) else { return nil }
        return digits
    }
}
