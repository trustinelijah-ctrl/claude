import Foundation
import SwiftData

/// Local history + cache. A product is stored once and re-scans bump the counter,
/// so a repeat scan never needs the network.
@Model
final class ScanRecord {
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String?
    var imageURLString: String?
    var score: Int
    var productData: Data
    var verdictData: Data?
    var verdictRubricVersion: Int
    var firstScannedAt: Date
    var lastScannedAt: Date
    var scanCount: Int
    var isFavorite: Bool

    init(product: Product, score: Int) {
        barcode = product.barcode
        name = product.name
        brand = product.displayBrand
        imageURLString = product.imageURL?.absoluteString
        self.score = score
        productData = (try? JSONEncoder().encode(product)) ?? Data()
        verdictData = nil
        verdictRubricVersion = 0
        firstScannedAt = .now
        lastScannedAt = .now
        scanCount = 1
        isFavorite = false
    }

    var tier: ScoreTier { ScoreTier(score: score) }
    var imageURL: URL? { imageURLString.flatMap(URL.init(string:)) }

    var product: Product? { try? JSONDecoder().decode(Product.self, from: productData) }

    var cachedVerdict: Verdict? {
        guard verdictRubricVersion == Verdict.rubricVersion, let verdictData else { return nil }
        return try? JSONDecoder().decode(Verdict.self, from: verdictData)
    }

    func update(product: Product, score: Int) {
        name = product.name
        brand = product.displayBrand
        imageURLString = product.imageURL?.absoluteString
        self.score = score
        productData = (try? JSONEncoder().encode(product)) ?? productData
    }

    func store(verdict: Verdict) {
        verdictData = try? JSONEncoder().encode(verdict)
        verdictRubricVersion = Verdict.rubricVersion
    }
}
