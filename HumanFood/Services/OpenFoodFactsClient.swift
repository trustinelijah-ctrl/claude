import Foundation

/// Open Food Facts: the open, crowd-sourced database of 4M+ products
/// (ODbL licence — attribution shown in Settings).
struct OpenFoodFactsClient: Sendable {
    enum LookupError: Error { case notFound }

    private let session: URLSession
    private static let base = URL(string: "https://world.openfoodfacts.org")!
    private static let fields = [
        "code", "product_name", "product_name_en", "generic_name", "brands", "image_front_url", "image_url",
        "quantity", "ingredients_text", "ingredients_text_en", "ingredients", "nutriments", "nova_group",
        "additives_tags", "categories_tags", "allergens_tags", "labels_tags", "unique_scans_n", "ingredients_tags",
    ].joined(separator: ",")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func product(barcode: String) async throws -> Product {
        var components = URLComponents(url: Self.base.appendingPathComponent("api/v2/product/\(barcode).json"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "fields", value: Self.fields)]
        let json = try await get(components.url!)
        guard (json["status"] as? Int) == 1, let raw = json["product"] as? [String: Any],
              let product = Self.parse(raw, fallbackBarcode: barcode) else {
            throw LookupError.notFound
        }
        return product
    }

    /// Popular products in a category, used to find better-scoring alternatives.
    /// Uses the Elasticsearch-backed search.openfoodfacts.org, falling back to API v2.
    func products(inCategory tag: String, country: String?, limit: Int = 40) async throws -> [Product] {
        var query = "categories_tags:\"\(tag)\""
        if let country { query += " AND countries_tags:\"\(country)\"" }
        var components = URLComponents(string: "https://search.openfoodfacts.org/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: Self.fields),
            URLQueryItem(name: "page_size", value: String(limit)),
            URLQueryItem(name: "sort_by", value: "-unique_scans_n"),
        ]
        if let json = try? await get(components.url!), let hits = json["hits"] as? [[String: Any]] {
            return hits.compactMap { Self.parse($0, fallbackBarcode: nil) }
        }

        var legacy = URLComponents(url: Self.base.appendingPathComponent("api/v2/search"), resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "categories_tags", value: tag),
            URLQueryItem(name: "fields", value: Self.fields),
            URLQueryItem(name: "page_size", value: String(limit)),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
        ]
        if let country { items.append(URLQueryItem(name: "countries_tags", value: country)) }
        legacy.queryItems = items
        let json = try await get(legacy.url!)
        let list = json["products"] as? [[String: Any]] ?? []
        return list.compactMap { Self.parse($0, fallbackBarcode: nil) }
    }

    private func get(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url, timeoutInterval: 12)
        // OFF asks every app to identify itself.
        request.setValue("HumanFood-iOS/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { throw LookupError.notFound }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return object
    }

    // MARK: - Parsing

    static func parse(_ p: [String: Any], fallbackBarcode: String?) -> Product? {
        guard let barcode = (p["code"] as? String) ?? fallbackBarcode else { return nil }
        let name = [p["product_name"], p["product_name_en"], p["generic_name"]]
            .compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let name else { return nil }

        let n = p["nutriments"] as? [String: Any] ?? [:]
        func num(_ key: String) -> Double? {
            switch n[key] {
            case let d as Double: return d
            case let i as Int: return Double(i)
            case let s as String: return Double(s)
            default: return nil
            }
        }
        var salt = num("salt_100g")
        if salt == nil, let sodium = num("sodium_100g") { salt = sodium * 2.5 }
        var kcal = num("energy-kcal_100g")
        if kcal == nil, let kj = num("energy_100g") { kcal = kj / 4.184 }

        let nutrients = Nutrients(
            energyKcal: kcal,
            fat: num("fat_100g"),
            saturatedFat: num("saturated-fat_100g"),
            transFat: num("trans-fat_100g"),
            carbohydrates: num("carbohydrates_100g"),
            sugars: num("sugars_100g"),
            addedSugars: num("added-sugars_100g"),
            fiber: num("fiber_100g"),
            protein: num("proteins_100g"),
            salt: salt
        )

        let ingredientObjects = p["ingredients"] as? [[String: Any]] ?? []
        // Prefer OFF's English taxonomy id ("en:wholemeal-wheat-flour") so keyword rules work for
        // labels in any language; fall back to the printed text.
        var ingredients = ingredientObjects.compactMap { obj -> String? in
            if let id = obj["id"] as? String, id.hasPrefix("en:") {
                return String(id.dropFirst(3)).replacingOccurrences(of: "-", with: " ")
            }
            return (obj["text"] as? String)?.lowercased()
        }
        // The search index only returns flattened `ingredients_tags` (which also list additives).
        let ingredientTags = (p["ingredients_tags"] as? [String] ?? []).filter { $0.hasPrefix("en:") }
        if ingredients.isEmpty {
            ingredients = ingredientTags.map { String($0.dropFirst(3)).replacingOccurrences(of: "-", with: " ") }
        }
        var additives = p["additives_tags"] as? [String] ?? []
        if additives.isEmpty {
            additives = ingredientTags.filter { $0.range(of: #"^en:e\d{3}"#, options: .regularExpression) != nil }
        }

        let categories = p["categories_tags"] as? [String] ?? []
        let isBeverage = categories.contains { $0 == "en:beverages" || $0.hasSuffix("-drinks") || $0 == "en:waters" }
            && !categories.contains { $0.contains("dehydrated") || $0.contains("powder") }

        let nova: Int? = {
            switch p["nova_group"] {
            case let i as Int: return i
            case let d as Double: return Int(d)
            case let s as String: return Int(s)
            default: return nil
            }
        }()

        let image = (p["image_front_url"] as? String) ?? (p["image_url"] as? String)
        let fvn = num("fruits-vegetables-nuts-estimate-from-ingredients_100g")
            ?? num("fruits-vegetables-legumes-estimate-from-ingredients_100g")

        return Product(
            barcode: barcode,
            name: name,
            brand: (p["brands"] as? String) ?? (p["brands"] as? [String])?.joined(separator: ", "),
            imageURL: image.flatMap(URL.init(string:)),
            quantity: p["quantity"] as? String,
            ingredientsText: (p["ingredients_text_en"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? p["ingredients_text"] as? String,
            ingredients: ingredients,
            nutrients: nutrients,
            novaGroup: nova,
            additives: additives,
            categories: categories,
            allergens: p["allergens_tags"] as? [String] ?? [],
            labels: p["labels_tags"] as? [String] ?? [],
            fruitsVegNutsPercent: fvn,
            isBeverage: isBeverage,
            source: .openFoodFacts
        )
    }

    /// Maps the device region to an OFF country tag, e.g. "en:united-states".
    static var countryTag: String? {
        guard let code = Locale.current.region?.identifier,
              let name = Locale(identifier: "en_US").localizedString(forRegionCode: code) else { return nil }
        return "en:" + name.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}
