import Foundation

/// How strongly animal foods are weighted. "Plant-forward" follows the
/// whole-food, plant-based literature (Campbell, Esselstyn, Greger); "Flexible"
/// halves those adjustments for people who want a gentler lens.
struct ScoringProfile: Sendable, Hashable {
    var animalWeight: Double

    static let plantForward = ScoringProfile(animalWeight: 1.0)
    static let flexible = ScoringProfile(animalWeight: 0.5)
}

/// Deterministic, explainable 0–100 score. Computed on-device so it is instant,
/// free, consistent for every user and fully auditable. AI only writes the prose.
///
/// Pillars (see docs/SCORING.md):
/// 1. Processing (NOVA) sets the baseline — whole foods start high.
/// 2. Nutrients: sugar, salt, saturated & trans fat, energy density, fibre.
/// 3. Ingredients: whole plants first, refined sugar/flour/oil, flavourings.
/// 4. Animal foods: processed & red meat, other meat/fish, dairy, eggs.
/// 5. Additives: tiered reference list, with a ceiling for the highest tier.
enum ScoringEngine {
    static let neutralBase = 70

    static func score(_ product: Product, profile: ScoringProfile = .plantForward) -> ScoreResult {
        var builder = Builder()
        let unit = product.isBeverage ? "100 ml" : "100 g"
        let text = IngredientText(product.ingredients, raw: product.ingredientsText)
        let animal = AnimalSignals(product: product, text: text)

        // 1 · Processing ------------------------------------------------------
        let estimatedNova = product.novaGroup == nil
        let nova = product.novaGroup ?? estimateNova(product, text: text)
        let estNote = estimatedNova ? " Estimated from the ingredient list." : ""
        switch nova {
        case 1:
            builder.add("nova", "Whole or minimally processed",
                        "Close to how it's found in nature." + estNote, +20, .processing, "leaf")
        case 2:
            builder.add("nova", "Culinary ingredient",
                        "A kitchen staple extracted from whole foods, like oil, flour or sugar." + estNote,
                        +2, .processing, "drop")
        case 3:
            builder.add("nova", "Processed",
                        "Whole foods changed with salt, sugar, oil or fermentation." + estNote,
                        -6, .processing, "flask")
        default:
            builder.add("nova", "Ultra-processed",
                        "An industrial formulation with ingredients you wouldn't usually find in a home kitchen." + estNote,
                        -15, .processing, "gearshape.2")
        }

        // 2 · Nutrients ---------------------------------------------------------
        var nutrientPenalty = 0
        let n = product.nutrients

        let hasSugarIngredient = text.items.contains { IngredientText.matches($0, sugarWords) }
        let sugarValue: Double? = {
            // OFF's added-sugar field is often a hand-entered 0; trust it only if the list agrees.
            if let added = n.addedSugars, added > 0 || !hasSugarIngredient { return added }
            if !hasSugarIngredient && (nova == 1 || product.hasCategory(matching: naturalSugarCategories)) { return nil }
            return n.sugars
        }()
        if let sugar = sugarValue {
            let p: Int
            if product.isBeverage {
                p = sugar > 10 ? 22 : sugar > 6 ? 15 : sugar > 2.5 ? 8 : 0
            } else {
                p = sugar > 22.5 ? 20 : sugar > 15 ? 14 : sugar > 10 ? 9 : sugar > 5 ? 4 : 0
            }
            if p > 0 {
                nutrientPenalty += p
                builder.add("sugar", "High in sugar",
                            "\(fmt(sugar)) g per \(unit). The WHO suggests keeping free sugars under 10% of daily energy.",
                            -p, .nutrients, "cube")
                if sugar > 50 {
                    nutrientPenalty += 15
                    builder.add("mostlysugar", "Mostly sugar", "More than half of it is sugar, even if the sugar is natural.",
                                -15, .nutrients, "cube.fill")
                }
            } else if sugar <= 2.5 {
                builder.add("sugar", "Low in sugar", "\(fmt(sugar)) g per \(unit).", 0, .nutrients, "cube", kind: .positive)
            }
        }

        if let salt = n.salt {
            let p = salt > 2.0 ? 15 : salt > 1.5 ? 11 : salt > 1.0 ? 7 : salt > 0.6 ? 3 : 0
            if p > 0 {
                nutrientPenalty += p
                builder.add("salt", "Salty", "\(fmt(salt)) g salt per \(unit). Most adults are advised to stay under 5 g a day.",
                            -p, .nutrients, "circle.grid.cross")
            } else if salt <= 0.3 {
                builder.add("salt", "Low in salt", "\(fmt(salt)) g per \(unit).", 0, .nutrients, "circle.grid.cross", kind: .positive)
            }
        }

        if let sat = n.saturatedFat {
            var p = sat > 10 ? 12 : sat > 5 ? 8 : sat > 3 ? 4 : 0
            if nova == 1 && !animal.isAnimalFood { p /= 2 } // nuts, seeds, avocado
            if p > 0 {
                nutrientPenalty += p
                builder.add("satfat", "Saturated fat", "\(fmt(sat)) g per \(unit).", -p, .nutrients, "drop.triangle")
            }
        }

        if (n.transFat ?? 0) > 0.1 || text.contains(["partially hydrogenated"]) {
            nutrientPenalty += 20
            builder.add("trans", "Industrial trans fat",
                        "Partially hydrogenated oils were phased out in many countries for heart-health reasons.",
                        -20, .nutrients, "exclamationmark.triangle")
        }

        if let fat = n.fat, fat > 17.5, nova >= 3, !product.isBeverage {
            nutrientPenalty += 4
            builder.add("fat", "High in fat", "\(ScoringEngine.fmt(fat)) g per \(unit).", -4, .nutrients, "drop")
        }

        if let kcal = n.energyKcal, kcal > 450, nova >= 3, !product.isBeverage {
            let p = kcal > 500 ? 8 : 5
            nutrientPenalty += p
            builder.add("energy", "Very energy-dense", "\(Int(kcal)) kcal per \(unit), which makes it easy to overeat.",
                        -p, .nutrients, "flame")
        }

        if let fiber = n.fiber {
            if fiber >= 6 {
                builder.add("fiber", "High in fibre", "\(fmt(fiber)) g per \(unit). Fibre is found only in plants.", +8, .nutrients, "leaf.arrow.triangle.circlepath")
            } else if fiber >= 3 {
                builder.add("fiber", "Source of fibre", "\(fmt(fiber)) g per \(unit).", +4, .nutrients, "leaf.arrow.triangle.circlepath")
            }
        }
        builder.cap(group: .nutrients, negativeFloor: -35, alreadyApplied: nutrientPenalty)

        // 3 · Ingredients ---------------------------------------------------------
        if let fvn = product.fruitsVegNutsPercent {
            if fvn >= 80 {
                builder.add("plants", "Mostly whole plants", "About \(Int(fvn))% fruit, vegetables, legumes or nuts.", +8, .ingredients, "carrot")
            } else if fvn >= 40 {
                builder.add("plants", "Rich in plants", "About \(Int(fvn))% fruit, vegetables, legumes or nuts.", +4, .ingredients, "carrot")
            }
        }
        if let first = text.items.first {
            if IngredientText.matches(first, wholeGrainWords) {
                builder.add("wholegrain", "Whole grain first", "The main ingredient is a whole grain.", +4, .ingredients, "laurel.leading")
            } else if IngredientText.matches(first, legumeWords) {
                builder.add("legume", "Legumes lead", "Beans, lentils and peas are staples of long-lived populations.", +4, .ingredients, "circle.hexagongrid")
            }
        }
        if nova >= 2, text.items.prefix(3).contains(where: { IngredientText.matches($0, sugarWords) }) {
            builder.add("sugarfirst", "Sugar is a main ingredient", "Sugar appears in the first three ingredients.", -5, .ingredients, "cube.fill")
        }
        if text.contains(syrupWords) {
            builder.add("syrup", "Refined syrups", "Contains glucose, fructose or corn syrups.", -4, .ingredients, "drop.fill")
        }
        if text.items.prefix(3).contains(where: { $0.contains("flour") && !IngredientText.matches($0, ["whole", "wholemeal", "wholegrain"]) }) {
            builder.add("flour", "Refined flour", "White flour has most of the grain's fibre removed.", -3, .ingredients, "circle.dotted")
        }
        if text.contains(["palm oil", "palm fat", "palm kernel"]) {
            builder.add("palm", "Palm oil", "A refined fat high in saturated fat.", -3, .ingredients, "drop.halffull")
        } else if text.contains(refinedOilWords) {
            builder.add("oil", "Added refined oil", "Whole-food authors favour getting fats from whole nuts, seeds and avocado.", -2, .ingredients, "drop.halffull")
        }
        if text.contains(["flavouring", "flavoring", "flavour", "flavor", "aroma"]) && nova >= 3 {
            builder.add("flavour", "Added flavourings", "Flavourings are a hallmark of ultra-processed formulations.", -2, .ingredients, "wand.and.stars")
        }
        if text.items.count > 15 {
            builder.add("long", "Long ingredient list", "\(text.items.count) ingredients.", -3, .ingredients, "list.bullet")
        } else if !text.items.isEmpty && text.items.count <= 3 && nova <= 3 {
            builder.add("short", "Short, simple list", "Just \(text.items.count) ingredient\(text.items.count == 1 ? "" : "s").", +2, .ingredients, "checklist")
        }
        if product.labels.contains(where: { $0.contains("organic") || $0.contains("bio") }) {
            builder.add("organic", "Organic", "Grown without most synthetic pesticides.", +2, .ingredients, "sun.max")
        }
        builder.clamp(group: .ingredients, floor: -14)

        // 4 · Animal foods ------------------------------------------------------
        let w = profile.animalWeight
        func weighted(_ v: Int) -> Int { Int((Double(v) * w).rounded()) }
        if animal.processedMeat {
            builder.add("processedmeat", "Processed meat",
                        "The WHO's cancer research agency (IARC) classifies processed meat in Group 1. Plant-forward research suggests keeping it rare.",
                        -weighted(25), .animal, "fork.knife")
        } else if animal.redMeat {
            builder.add("redmeat", "Red meat",
                        "IARC classifies red meat in Group 2A. Beans, lentils and tofu offer protein with fibre instead.",
                        -weighted(18), .animal, "fork.knife")
        } else if animal.meatOrFish {
            builder.add("meat", "Animal protein",
                        "Whole-food, plant-based research (e.g. The China Study) favours getting protein mostly from plants.",
                        -weighted(12), .animal, "fish")
        }
        if animal.dairy {
            builder.add("dairy", "Dairy",
                        "Plant-forward authors such as T. Colin Campbell recommend limiting dairy protein and fat.",
                        -weighted(12), .animal, "cup.and.saucer")
        }
        if animal.eggs {
            builder.add("eggs", "Eggs", "Rich in dietary cholesterol; plant-forward eating keeps eggs occasional.",
                        -weighted(10), .animal, "oval.portrait")
        }
        if !animal.isAnimalFood && animal.minorAnimalIngredient {
            builder.add("animalbits", "Animal-derived ingredients", "Contains ingredients such as milk, egg, whey or gelatine.",
                        -weighted(3), .animal, "pawprint")
        }
        if !animal.isAnimalFood && !animal.minorAnimalIngredient && !text.items.isEmpty && nova <= 3 {
            builder.add("plantbased", "Plant-based", "No animal-derived ingredients listed.", +2, .animal, "leaf.circle")
        }

        // 5 · Additives ---------------------------------------------------------
        var additivePenalty = 0
        var highest = AdditiveInfo.Tier.none
        var lowCount = 0
        for code in Set(product.additives.map(AdditiveCatalog.normalise)).sorted() {
            let info = AdditiveCatalog.info(for: code)
            highest = max(highest, info.tier)
            if info.tier >= .moderate {
                additivePenalty += info.tier.penalty
                builder.add("add-\(code)", "\(info.name) (\(info.code.uppercased()))", info.note,
                            -info.tier.penalty, .additives, "atom")
            } else if info.tier == .low {
                lowCount += 1
                additivePenalty += 1
            }
        }
        if lowCount > 0 {
            builder.add("add-low", "\(lowCount) low-concern additive\(lowCount == 1 ? "" : "s")",
                        "Generally well studied, but a sign of processing.", -lowCount, .additives, "atom")
        }
        builder.cap(group: .additives, negativeFloor: -30, alreadyApplied: additivePenalty)

        // Total & ceilings -------------------------------------------------------
        var total = neutralBase + builder.total
        var capNote: String?
        if highest == .high, total > 49 {
            total = 49
            capNote = "Contains an additive we rate \"best avoided\", so the score is capped at 49."
        }
        if animal.processedMeat, total > 35 {
            total = 35
            capNote = "Processed meats are capped at 35."
        }
        if nova == 4, total > 69 {
            total = 69
            capNote = "Ultra-processed foods are capped at 69."
        }
        total = min(100, max(0, total))

        let coreNutrients = n.sugars != nil && n.salt != nil && n.saturatedFat != nil
        let confidence: ScoreResult.Confidence =
            n.isEmpty && text.items.isEmpty ? .low :
            (coreNutrients && !text.items.isEmpty) ? .high : .medium

        return ScoreResult(score: total, factors: builder.factors, confidence: confidence, capNote: capNote)
    }

    // MARK: - NOVA estimate

    static func estimateNova(_ product: Product, text: IngredientText) -> Int {
        if text.items.count <= 1 && product.additives.isEmpty { return text.items.isEmpty ? 3 : 1 }
        if text.contains(ultraProcessedMarkers) { return 4 }
        if product.additives.contains(where: { AdditiveCatalog.info(for: $0).tier >= .moderate }) { return 4 }
        return 3
    }

    // MARK: - Vocabulary

    static let naturalSugarCategories = ["en:fruits", "en:fresh-fruits", "en:dried-fruits", "en:plain-yogurts",
                                         "en:milks", "en:unsweetened", "en:vegetables", "en:fruit-juices"]
    static let wholeGrainWords = ["whole grain", "wholegrain", "whole wheat", "wholemeal", "whole-grain", "rolled oat",
                                  "oat", "brown rice", "quinoa", "buckwheat", "barley", "millet", "spelt", "rye", "teff", "amaranth"]
    static let legumeWords = ["lentil", "chickpea", "bean", "pea", "soy", "tofu", "tempeh", "edamame", "hummus"]
    static let sugarWords = ["sugar", "sucrose", "glucose", "fructose", "dextrose", "syrup", "cane", "caramel", "honey", "maltose"]
    static let syrupWords = ["glucose syrup", "glucose-fructose", "fructose syrup", "corn syrup", "high fructose",
                             "high-fructose", "invert sugar", "maltodextrin"]
    static let refinedOilWords = ["sunflower oil", "rapeseed oil", "canola oil", "soybean oil", "soya oil", "vegetable oil",
                                  "corn oil", "cottonseed oil", "vegetable fat"]
    static let ultraProcessedMarkers = ["flavouring", "flavoring", "glucose syrup", "maltodextrin", "hydrogenated",
                                        "isolate", "modified starch", "emulsifier", "dextrose", "invert sugar",
                                        "fructose syrup", "corn syrup", "colour", "color", "sweetener", "hydrolysed",
                                        "hydrolyzed", "mechanically separated"]

    static func fmt(_ v: Double) -> String {
        v < 10 ? String(format: "%.1f", v) : String(Int(v.rounded()))
    }
}

// MARK: - Builder

private struct Builder {
    var factors: [ScoreFactor] = []
    private var adjustments: [ScoreFactor.Group: Int] = [:]

    var total: Int { adjustments.values.reduce(0, +) }

    mutating func add(_ id: String, _ title: String, _ detail: String, _ impact: Int,
                      _ group: ScoreFactor.Group, _ symbol: String, kind: ScoreFactor.Kind? = nil) {
        let k = kind ?? (impact > 0 ? .positive : impact < 0 ? .consideration : .info)
        factors.append(ScoreFactor(id: id, title: title, detail: detail, impact: impact, kind: k, group: group, symbol: symbol))
        adjustments[group, default: 0] += impact
    }

    /// Limits how much a group's negatives can pull the score down.
    mutating func cap(group: ScoreFactor.Group, negativeFloor: Int, alreadyApplied penalty: Int) {
        guard penalty > -negativeFloor else { return }
        adjustments[group, default: 0] += penalty + negativeFloor
    }

    mutating func clamp(group: ScoreFactor.Group, floor: Int) {
        if let v = adjustments[group], v < floor { adjustments[group] = floor }
    }
}

// MARK: - Ingredient helpers

struct IngredientText: Sendable {
    let items: [String]
    let joined: String

    init(_ items: [String], raw: String?) {
        let cleaned = items.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if cleaned.isEmpty, let raw, !raw.isEmpty {
            self.items = IngredientText.split(raw)
        } else {
            self.items = cleaned
        }
        self.joined = (raw?.lowercased() ?? "") + " " + self.items.joined(separator: " ")
    }

    func contains(_ words: [String]) -> Bool { words.contains { joined.contains($0) } }

    static func matches(_ item: String, _ words: [String]) -> Bool { words.contains { item.contains($0) } }

    /// Splits a raw ingredient label on top-level commas (ignoring those in brackets).
    static func split(_ raw: String) -> [String] {
        var parts: [String] = []
        var depth = 0
        var current = ""
        for ch in raw.lowercased() {
            switch ch {
            case "(", "[": depth += 1; current.append(ch)
            case ")", "]": depth = max(0, depth - 1); current.append(ch)
            case "," where depth == 0, ";" where depth == 0:
                parts.append(current)
                current = ""
            default: current.append(ch)
            }
        }
        parts.append(current)
        return parts
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "."))) }
            .filter { !$0.isEmpty }
    }
}

struct AnimalSignals: Sendable {
    var processedMeat = false
    var redMeat = false
    var meatOrFish = false
    var dairy = false
    var eggs = false
    var minorAnimalIngredient = false

    var isAnimalFood: Bool { processedMeat || redMeat || meatOrFish || dairy || eggs }

    init(product: Product, text: IngredientText) {
        let vegan = product.labels.contains { $0.contains("vegan") }
        let tags = product.categories.filter { !$0.contains("plant") && !$0.contains("vegan") && !$0.contains("vegetarian") && !$0.contains("substitute") && !$0.contains("alternative") && !$0.contains("nut-butter") && !$0.contains("peanut") && !$0.contains("coconut") && !$0.contains("cocoa") }
        func has(_ fragments: [String]) -> Bool { tags.contains { t in fragments.contains { t.contains($0) } } }
        guard !vegan else { return }

        let hasNitrite = product.additives.contains { ["e249", "e250", "e251", "e252"].contains(AdditiveCatalog.normalise($0)) }
        processedMeat = has(["processed-meat", "sausage", "hams", "bacon", "salami", "cured-meat", "hot-dog", "charcuterie",
                             "deli-meat", "prepared-meat", "chorizo", "pepperoni", "jerk"])
            || (has(["meats"]) && hasNitrite)
        redMeat = has(["beef", "pork", "lamb", "veal", "red-meat", "mutton", "goat-meat", "game-meat"])
        eggs = product.categories.contains { $0 == "en:eggs" || $0 == "en:chicken-eggs" }
        meatOrFish = !eggs && has(["en:meats", "poultr", "chicken", "turkey", "fishes", "en:fish", "seafood", "tuna", "salmon",
                                   "sardine", "mackerel", "shrimp", "prawn"])
        dairy = has(["dairies", "dairy", "cheese", "en:milks", "yogurt", "yoghurt", "butter", "cream", "kefir"])

        // Strip plant-based phrases before looking for small animal ingredients.
        var j = text.joined
        for phrase in ["coconut milk", "almond milk", "oat milk", "soy milk", "soya milk", "rice milk", "peanut butter",
                       "cocoa butter", "nut butter", "shea butter", "butternut", "eggplant", "cream of tartar",
                       "milk thistle", "coconut cream", "butter bean", "shea", "milk-free", "dairy-free", "egg-free"] {
            j = j.replacingOccurrences(of: phrase, with: "")
        }
        minorAnimalIngredient = ["milk", "whey", "casein", "cream", "butter", "egg", "gelatin", "gelatine", "lard",
                                 "beef", "pork", "chicken", "anchov", "fish", "cheese", "lactose", "tallow"]
            .contains { j.contains($0) }
    }
}
