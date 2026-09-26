import Foundation

/// Produces the written verdict for a product.
///
/// Order of preference:
/// 1. Human Food backend — returns the shared cached verdict, or generates it
///    once with Gemini and stores it so no other user ever pays for it again.
/// 2. DEBUG only: direct Gemini call with a developer key (no shared cache).
/// 3. Local writer — deterministic prose built from the score factors. Always works offline.
struct VerdictService: Sendable {
    let config: AppConfig

    func verdict(for product: Product, score: ScoreResult) async -> Verdict {
        let locale = Locale.current.identifier
        if let backend = BackendClient(config: config) {
            if let v = try? await backend.verdict(product: product, score: score, locale: locale) {
                return v.sanitized(brand: product.brand)
            }
        }
        #if DEBUG
        if let key = config.geminiDevKey {
            let gemini = GeminiClient(apiKey: key, model: config.geminiModel)
            if let v = try? await gemini.verdict(product: product, score: score, locale: locale) {
                return v.sanitized(brand: product.brand)
            }
        }
        #endif
        return LocalVerdictWriter.write(product: product, score: score).sanitized(brand: product.brand)
    }

    /// Reads packaging photos into a product (for items missing from every database).
    func readLabel(images: [Data], barcode: String?) async throws -> Product {
        if let backend = BackendClient(config: config) {
            return try await backend.readLabel(images: images, barcode: barcode)
        }
        #if DEBUG
        if let key = config.geminiDevKey {
            return try await GeminiClient(apiKey: key, model: config.geminiModel)
                .readLabel(images: images, barcode: barcode)
        }
        #endif
        throw ServiceError.aiUnavailable
    }

    func communityProduct(barcode: String) async -> Product? {
        guard let backend = BackendClient(config: config) else { return nil }
        return try? await backend.product(barcode: barcode)
    }
}

enum ServiceError: LocalizedError {
    case aiUnavailable
    case badResponse
    case limitReached

    var errorDescription: String? {
        switch self {
        case .aiUnavailable: "Label reading needs the Human Food service. Add your backend in Config/Secrets.xcconfig."
        case .badResponse: "We couldn't read that. Try again with the label flat and well lit."
        case .limitReached: "We're a little busy right now. Please try again later."
        }
    }
}

// MARK: - Backend

/// Talks to the Supabase Edge Function in backend/supabase/functions/human-food.
struct BackendClient: Sendable {
    let base: URL
    let anonKey: String?

    init?(config: AppConfig) {
        guard let url = config.backendBaseURL else { return nil }
        base = url
        anonKey = config.backendAnonKey
    }

    private struct VerdictEnvelope: Decodable {
        struct Body: Decodable {
            var headline: String
            var summary: String
            var highlights: [String]
            var considerations: [String]
            var alternatives: [AlternativeIdea]
            var tip: String?
        }
        var verdict: Body
        var cached: Bool?
    }

    private struct ProductEnvelope: Decodable { var product: Product }

    func verdict(product: Product, score: ScoreResult, locale: String) async throws -> Verdict {
        let body: [String: Any] = [
            "barcode": product.barcode,
            "locale": locale,
            "rubricVersion": Verdict.rubricVersion,
            "score": [
                "value": score.score,
                "tier": score.tier.title,
                "factors": score.factors.map { ["title": $0.title, "detail": $0.detail, "impact": $0.impact] },
            ] as [String: Any],
        ]
        let data = try await send(path: "verdict", body: body, timeout: 30)
        let env = try JSONDecoder().decode(VerdictEnvelope.self, from: data)
        let v = env.verdict
        return Verdict(headline: v.headline, summary: v.summary, highlights: v.highlights,
                       considerations: v.considerations, alternatives: v.alternatives, tip: v.tip, origin: .ai)
    }

    func readLabel(images: [Data], barcode: String?) async throws -> Product {
        var body: [String: Any] = ["images": images.map { $0.base64EncodedString() }]
        if let barcode { body["barcode"] = barcode }
        let data = try await send(path: "label", body: body, timeout: 60)
        return try JSONDecoder().decode(ProductEnvelope.self, from: data).product
    }

    func product(barcode: String) async throws -> Product {
        var components = URLComponents(url: base.appendingPathComponent("product"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "barcode", value: barcode)]
        var request = URLRequest(url: components.url!, timeoutInterval: 10)
        authorize(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError.badResponse }
        return try JSONDecoder().decode(ProductEnvelope.self, from: data).product
    }

    private func send(path: String, body: [String: Any], timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: base.appendingPathComponent(path), timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return data
        case 429: throw ServiceError.limitReached
        default: throw ServiceError.badResponse
        }
    }

    private func authorize(_ request: inout URLRequest) {
        guard let anonKey else { return }
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
    }
}

// MARK: - Direct Gemini (DEBUG only)

#if DEBUG
struct GeminiClient: Sendable {
    let apiKey: String
    let model: String

    func verdict(product: Product, score: ScoreResult, locale: String) async throws -> Verdict {
        let parts: [[String: Any]] = [["text": AIPrompts.verdictInput(product: product, score: score)]]
        let data = try await generate(system: AIPrompts.verdictSystem(locale: locale), parts: parts,
                                      schema: AIPrompts.verdictSchema)
        struct Body: Decodable {
            var headline: String
            var summary: String
            var highlights: [String]
            var considerations: [String]
            var alternatives: [AlternativeIdea]
            var tip: String?
        }
        let b = try JSONDecoder().decode(Body.self, from: data)
        return Verdict(headline: b.headline, summary: b.summary, highlights: b.highlights,
                       considerations: b.considerations, alternatives: b.alternatives, tip: b.tip, origin: .ai)
    }

    func readLabel(images: [Data], barcode: String?) async throws -> Product {
        var parts: [[String: Any]] = images.map {
            ["inline_data": ["mime_type": "image/jpeg", "data": $0.base64EncodedString()]]
        }
        parts.append(["text": "Transcribe this product's packaging."])
        let data = try await generate(system: AIPrompts.labelSystem, parts: parts, schema: AIPrompts.labelSchema)
        struct Label: Decodable {
            var name: String
            var brand: String?
            var quantity: String?
            var ingredientsText: String?
            var ingredients: [String]
            var nutrients: Nutrients
            var novaGroup: Int?
            var additives: [String]
            var categories: [String]
            var allergens: [String]
            var isBeverage: Bool
        }
        let l = try JSONDecoder().decode(Label.self, from: data)
        return Product(barcode: barcode ?? "label-\(UUID().uuidString.prefix(8))", name: l.name, brand: l.brand,
                       imageURL: nil, quantity: l.quantity, ingredientsText: l.ingredientsText,
                       ingredients: l.ingredients.map { $0.lowercased() }, nutrients: l.nutrients,
                       novaGroup: l.novaGroup, additives: l.additives, categories: l.categories,
                       allergens: l.allergens, labels: [], fruitsVegNutsPercent: nil,
                       isBeverage: l.isBeverage, source: .community)
    }

    private func generate(system: String, parts: [[String: Any]], schema: [String: Any]) async throws -> Data {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": 0.4,
            ] as [String: Any],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let textParts = content["parts"] as? [[String: Any]],
              let text = textParts.compactMap({ $0["text"] as? String }).first,
              let out = text.data(using: .utf8) else {
            throw ServiceError.badResponse
        }
        return out
    }
}
#endif
