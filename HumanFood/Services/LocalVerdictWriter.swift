import Foundation

/// Writes a verdict without any network, from the score factors alone.
/// Used offline, when no backend is configured, or if the AI is unavailable.
enum LocalVerdictWriter {
    static func write(product: Product, score: ScoreResult) -> Verdict {
        let tier = score.tier
        let headline: String = switch tier {
        case .excellent: "A genuinely whole choice"
        case .good: "A solid everyday pick"
        case .fair: "Fine now and then"
        case .limit: "Best as an occasional food"
        case .rarely: "Worth swapping when you can"
        }

        let processing = score.factors.first { $0.group == .processing }
        let topConcern = score.considerations.first { $0.group != .processing }
        let topPositive = score.positives.first { $0.group != .processing && $0.impact > 0 }

        var sentences: [String] = []
        if let processing {
            let t = processing.title.lowercased()
            sentences.append(processing.id == "nova" && t == "culinary ingredient"
                             ? "In our view this is a culinary ingredient, best used in modest amounts."
                             : "In our view this is \(article(t)) \(t) food.")
        }
        if let topConcern {
            sentences.append("Biggest drawback: \(lowerFirst(topConcern.title)).")
        }
        if let topPositive {
            sentences.append("On the plus side: \(lowerFirst(topPositive.title)).")
        }
        if score.confidence == .low {
            sentences.append("Nutrition and ingredient data are limited, so treat this rating as a rough guide.")
        }

        return Verdict(
            headline: headline,
            summary: sentences.joined(separator: " "),
            highlights: score.positives.prefix(3).map { $0.title },
            considerations: score.considerations.prefix(3).map { $0.title },
            alternatives: tier == .excellent ? [] : ideas(for: product),
            tip: tip(for: product, score: score),
            origin: .local
        )
    }

    private static func article(_ word: String) -> String {
        guard let first = word.first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    private static func lowerFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.lowercased() + s.dropFirst()
    }

    private static func tip(for product: Product, score: ScoreResult) -> String {
        if score.factors.contains(where: { $0.id == "sugar" && $0.impact < 0 }) {
            return "Pair sweet foods with fibre, like fruit or nuts, and keep portions small."
        }
        if score.factors.contains(where: { $0.id == "salt" && $0.impact < 0 }) {
            return "Balance salty foods with potassium-rich vegetables, beans and fruit."
        }
        if score.factors.contains(where: { $0.group == .animal && $0.impact < 0 }) {
            return "Try making beans, lentils or tofu the centre of the plate a few times a week."
        }
        if score.tier == .excellent {
            return "Foods like this are the backbone of a long, healthy diet. Enjoy."
        }
        return "Shorter ingredient lists with names you recognise are usually the better pick."
    }

    /// Generic, brand-free swaps by category.
    static func ideas(for product: Product) -> [AlternativeIdea] {
        let rules: [(match: [String], ideas: [AlternativeIdea])] = [
            (["energy-drink"], [.init(title: "Green tea or matcha", reason: "Gentle caffeine with no added sugar."),
                                .init(title: "Cold brew coffee, unsweetened", reason: "A lift without sweeteners or colours.")]),
            (["soda", "soft-drink", "carbonated-drink", "colas"], [
                .init(title: "Sparkling water with citrus", reason: "All the fizz, none of the sugar or sweeteners."),
                .init(title: "Unsweetened iced tea", reason: "Refreshing, with naturally occurring polyphenols.")]),
            (["fruit-juice", "juices", "nectars"], [
                .init(title: "Whole fruit", reason: "Keeps the fibre that slows sugar absorption."),
                .init(title: "Water infused with fruit", reason: "Flavour without the concentrated sugar.")]),
            (["breakfast-cereal", "cereals"], [
                .init(title: "Rolled oats with berries", reason: "A whole grain with fibre and no added sugar."),
                .init(title: "Unsweetened muesli", reason: "Whole grains, nuts and seeds in their whole form.")]),
            (["crisps", "chips", "salty-snack", "appetizers"], [
                .init(title: "Air-popped popcorn", reason: "A whole grain snack you can season lightly."),
                .init(title: "Roasted chickpeas", reason: "Crunchy, with plant protein and fibre.")]),
            (["chocolate", "candies", "confectioner", "sweets", "bonbons"], [
                .init(title: "Dates with nut butter", reason: "Sweetness that comes with fibre and minerals."),
                .init(title: "Dark chocolate, 85% or more", reason: "Much less sugar; a small square goes far.")]),
            (["biscuits", "cookies", "cakes", "pastries", "snacks-sweet"], [
                .init(title: "Fresh fruit and a handful of nuts", reason: "Whole-food sweetness with healthy fats."),
                .init(title: "Oat and banana bakes", reason: "Whole grains sweetened by fruit.")]),
            (["ice-cream", "frozen-dessert"], [
                .init(title: "Frozen banana \"nice cream\"", reason: "One ingredient, naturally creamy."),
                .init(title: "Frozen berries", reason: "Cold, sweet and full of fibre.")]),
            (["processed-meat", "sausage", "ham", "bacon", "salami", "deli"], [
                .init(title: "Marinated tofu or tempeh", reason: "Savoury protein without curing salts."),
                .init(title: "Bean or lentil spread", reason: "Satisfying on bread, with fibre.")]),
            (["meats", "beef", "pork", "poultr", "chicken"], [
                .init(title: "Lentils or black beans", reason: "Protein that comes with fibre and no cholesterol."),
                .init(title: "Tempeh", reason: "A fermented whole-soy protein.")]),
            (["fish", "seafood"], [
                .init(title: "Ground flax or walnuts", reason: "Plant sources of omega-3 ALA."),
                .init(title: "Chickpea \"tuna\" salad", reason: "A plant-based take on a classic.")]),
            (["cheese"], [
                .init(title: "Hummus", reason: "Creamy, savoury and made from legumes."),
                .init(title: "Cashew-based spread", reason: "Rich texture from whole nuts.")]),
            (["yogurt", "yoghurt"], [
                .init(title: "Unsweetened soy yogurt with berries", reason: "Plant protein without added sugar.")]),
            (["milks", "dairies", "dairy"], [
                .init(title: "Unsweetened soy milk", reason: "Comparable protein, plant-based and fortified.")]),
            (["spread", "hazelnut"], [
                .init(title: "Nut butter, no added sugar", reason: "Just nuts — nothing else needed.")]),
            (["breads", "bread"], [
                .init(title: "100% whole-grain bread", reason: "Keeps the bran and germ with their fibre.")]),
            (["pasta", "noodles"], [
                .init(title: "Whole-wheat or lentil pasta", reason: "More fibre and protein per plate.")]),
            (["sauce", "dressing", "condiment"], [
                .init(title: "Homemade tomato sauce", reason: "Tomatoes, garlic and herbs — no added sugar."),
                .init(title: "Lemon and tahini dressing", reason: "Whole-food fats and bright flavour.")]),
            (["pizza", "meals", "ready", "frozen-foods"], [
                .init(title: "Grain bowl with beans and vegetables", reason: "Quick to assemble from whole foods."),
                .init(title: "Lentil soup", reason: "Batch-cooks well and freezes perfectly.")]),
        ]
        for rule in rules where product.hasCategory(matching: rule.match) {
            return rule.ideas
        }
        return [
            .init(title: "A version with fewer ingredients", reason: "Shorter, recognisable lists tend to mean less processing."),
            .init(title: "Whole fruit, vegetables, legumes or grains", reason: "The foundation of every long-lived diet."),
        ]
    }
}
