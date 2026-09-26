import Foundation

/// Nutrient values normalised per 100 g (or per 100 ml for beverages).
struct Nutrients: Codable, Hashable, Sendable {
    var energyKcal: Double?
    var fat: Double?
    var saturatedFat: Double?
    var transFat: Double?
    var carbohydrates: Double?
    var sugars: Double?
    var addedSugars: Double?
    var fiber: Double?
    var protein: Double?
    /// Salt in grams. Derived from sodium (× 2.5) when only sodium is known.
    var salt: Double?

    var isEmpty: Bool {
        [energyKcal, fat, saturatedFat, carbohydrates, sugars, fiber, protein, salt]
            .allSatisfy { $0 == nil }
    }
}

/// A food product, normalised from Open Food Facts or from a label read.
struct Product: Codable, Hashable, Identifiable, Sendable {
    enum Source: String, Codable, Sendable {
        case openFoodFacts
        case community
    }

    var id: String { barcode }

    var barcode: String
    var name: String
    var brand: String?
    var imageURL: URL?
    var quantity: String?
    var ingredientsText: String?
    /// Lower-cased ingredient names, in label order.
    var ingredients: [String]
    var nutrients: Nutrients
    /// NOVA processing group (1 = unprocessed … 4 = ultra-processed).
    var novaGroup: Int?
    /// Additive codes such as "e330".
    var additives: [String]
    /// Category tags such as "en:breakfast-cereals", general → specific.
    var categories: [String]
    /// Allergen tags such as "en:milk".
    var allergens: [String]
    var labels: [String]
    var fruitsVegNutsPercent: Double?
    var isBeverage: Bool
    var source: Source

    var displayBrand: String? {
        guard let brand, !brand.isEmpty else { return nil }
        return brand.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces)
    }

    func hasCategory(matching fragments: [String]) -> Bool {
        categories.contains { tag in fragments.contains { tag.contains($0) } }
    }
}

/// A product together with its locally computed score.
struct ScoredProduct: Identifiable, Hashable, Sendable {
    var product: Product
    var score: ScoreResult
    var id: String { product.barcode }
}
