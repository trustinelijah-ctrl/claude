import Foundation

/// A small, curated reference of common additives.
///
/// Wording rules: describe what regulators or research bodies have *said*
/// (a verifiable fact) instead of asserting harm. Never say "toxic",
/// "dangerous" or "causes". Tiers are Human Food's own opinion.
struct AdditiveInfo: Sendable {
    enum Tier: Int, Sendable, Comparable {
        case none = 0, low, moderate, elevated, high

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

        var penalty: Int {
            switch self {
            case .none: 0
            case .low: 1
            case .moderate: 4
            case .elevated: 8
            case .high: 15
            }
        }

        var label: String {
            switch self {
            case .none: "No concerns noted"
            case .low: "Low concern"
            case .moderate: "Some questions raised"
            case .elevated: "Worth limiting"
            case .high: "Best avoided when possible"
            }
        }
    }

    let code: String
    let name: String
    let tier: Tier
    let note: String
}

enum AdditiveCatalog {
    static func info(for code: String) -> AdditiveInfo {
        let key = normalise(code)
        if let exact = table[key] { return exact }
        // "e160ai" → fall back to the numeric family "e160" when listed.
        let family = String(key.prefix { $0 == "e" || $0.isNumber })
        if let parent = table[family] { return parent }
        return AdditiveInfo(code: key.uppercased(), name: key.uppercased(), tier: .low,
                            note: "Not yet in our reference list.")
    }

    /// Turns "en:e150d" / "E150d" / "e 150 d" into "e150d".
    static func normalise(_ raw: String) -> String {
        var s = raw.lowercased()
        if let colon = s.firstIndex(of: ":") { s = String(s[s.index(after: colon)...]) }
        return s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
    }

    private static let entries: [AdditiveInfo] = [
        // Colours
        .init(code: "e102", name: "Tartrazine", tier: .elevated,
              note: "One of the \"Southampton colours\"; EU products using it must carry an attention/activity warning for children."),
        .init(code: "e104", name: "Quinoline yellow", tier: .elevated,
              note: "A Southampton colour that requires a warning label in the EU."),
        .init(code: "e110", name: "Sunset yellow", tier: .elevated,
              note: "A Southampton colour that requires a warning label in the EU."),
        .init(code: "e122", name: "Carmoisine", tier: .elevated,
              note: "A Southampton colour that requires a warning label in the EU."),
        .init(code: "e124", name: "Ponceau 4R", tier: .elevated,
              note: "A Southampton colour that requires a warning label in the EU."),
        .init(code: "e129", name: "Allura red", tier: .elevated,
              note: "A Southampton colour that requires a warning label in the EU."),
        .init(code: "e127", name: "Erythrosine", tier: .elevated,
              note: "Its use in food was revoked by the US FDA in 2025."),
        .init(code: "e133", name: "Brilliant blue", tier: .moderate,
              note: "A synthetic colour with no nutritional role."),
        .init(code: "e150a", name: "Plain caramel", tier: .low, note: "A simple colouring."),
        .init(code: "e150c", name: "Ammonia caramel", tier: .moderate,
              note: "Can contain 4-MEI, a by-product that has been reviewed by several agencies."),
        .init(code: "e150d", name: "Sulphite ammonia caramel", tier: .moderate,
              note: "Can contain 4-MEI, a by-product that has been reviewed by several agencies."),
        .init(code: "e171", name: "Titanium dioxide", tier: .high,
              note: "No longer authorised as a food additive in the EU since 2022."),
        .init(code: "e173", name: "Aluminium", tier: .elevated,
              note: "A colouring whose use is tightly restricted in the EU."),
        .init(code: "e160a", name: "Carotenes", tier: .none, note: "Plant-derived pigments."),
        .init(code: "e162", name: "Beetroot red", tier: .none, note: "Colour from beetroot."),
        // Preservatives
        .init(code: "e200", name: "Sorbic acid", tier: .low, note: "A widely used preservative."),
        .init(code: "e202", name: "Potassium sorbate", tier: .low, note: "A widely used preservative."),
        .init(code: "e211", name: "Sodium benzoate", tier: .moderate,
              note: "Can form small amounts of benzene when combined with vitamin C in drinks."),
        .init(code: "e220", name: "Sulphur dioxide", tier: .moderate,
              note: "Sulphites can trigger reactions in sensitive people."),
        .init(code: "e223", name: "Sodium metabisulphite", tier: .moderate,
              note: "Sulphites can trigger reactions in sensitive people."),
        .init(code: "e224", name: "Potassium metabisulphite", tier: .moderate,
              note: "Sulphites can trigger reactions in sensitive people."),
        .init(code: "e249", name: "Potassium nitrite", tier: .high,
              note: "Nitrites in cured meat are part of why IARC classifies processed meat in Group 1."),
        .init(code: "e250", name: "Sodium nitrite", tier: .high,
              note: "Nitrites in cured meat are part of why IARC classifies processed meat in Group 1."),
        .init(code: "e251", name: "Sodium nitrate", tier: .high,
              note: "Converted to nitrite in cured products; EFSA recommends limiting intake."),
        .init(code: "e252", name: "Potassium nitrate", tier: .high,
              note: "Converted to nitrite in cured products; EFSA recommends limiting intake."),
        .init(code: "e282", name: "Calcium propionate", tier: .moderate,
              note: "A preservative that some early research has looked at for metabolic effects."),
        .init(code: "e319", name: "TBHQ", tier: .elevated,
              note: "A synthetic antioxidant with a low acceptable daily intake."),
        .init(code: "e320", name: "BHA", tier: .high,
              note: "Classified by IARC as possibly carcinogenic to humans (Group 2B)."),
        .init(code: "e321", name: "BHT", tier: .elevated,
              note: "A synthetic antioxidant that remains under regulatory review."),
        .init(code: "e385", name: "Calcium disodium EDTA", tier: .moderate,
              note: "A synthetic preservative with no nutritional role."),
        // Acids, antioxidants (mostly benign)
        .init(code: "e270", name: "Lactic acid", tier: .none, note: "Naturally present in fermented foods."),
        .init(code: "e296", name: "Malic acid", tier: .none, note: "Found naturally in fruit."),
        .init(code: "e300", name: "Ascorbic acid", tier: .none, note: "Vitamin C."),
        .init(code: "e306", name: "Tocopherols", tier: .none, note: "Vitamin E."),
        .init(code: "e322", name: "Lecithins", tier: .none, note: "Usually from soy or sunflower."),
        .init(code: "e330", name: "Citric acid", tier: .none, note: "Found naturally in citrus fruit."),
        .init(code: "e338", name: "Phosphoric acid", tier: .moderate,
              note: "High phosphate intake from additives has been studied in relation to bone and kidney health."),
        .init(code: "e339", name: "Sodium phosphates", tier: .moderate,
              note: "Added phosphates are absorbed more readily than those naturally in food."),
        .init(code: "e340", name: "Potassium phosphates", tier: .moderate,
              note: "Added phosphates are absorbed more readily than those naturally in food."),
        .init(code: "e341", name: "Calcium phosphates", tier: .low, note: "A mineral salt."),
        .init(code: "e450", name: "Diphosphates", tier: .moderate,
              note: "Added phosphates are absorbed more readily than those naturally in food."),
        .init(code: "e451", name: "Triphosphates", tier: .moderate,
              note: "Added phosphates are absorbed more readily than those naturally in food."),
        .init(code: "e452", name: "Polyphosphates", tier: .moderate,
              note: "Added phosphates are absorbed more readily than those naturally in food."),
        // Thickeners, emulsifiers
        .init(code: "e407", name: "Carrageenan", tier: .moderate,
              note: "Some studies have looked at its effect on gut inflammation."),
        .init(code: "e410", name: "Locust bean gum", tier: .none, note: "A plant fibre."),
        .init(code: "e412", name: "Guar gum", tier: .none, note: "A plant fibre."),
        .init(code: "e415", name: "Xanthan gum", tier: .low, note: "A fermentation-derived thickener."),
        .init(code: "e425", name: "Konjac", tier: .low, note: "A plant fibre."),
        .init(code: "e433", name: "Polysorbate 80", tier: .moderate,
              note: "Emulsifiers like this one are being studied for effects on the gut microbiome."),
        .init(code: "e440", name: "Pectin", tier: .none, note: "A fruit fibre."),
        .init(code: "e466", name: "Carboxymethyl cellulose", tier: .moderate,
              note: "Emulsifiers like this one are being studied for effects on the gut microbiome."),
        .init(code: "e471", name: "Mono- and diglycerides", tier: .moderate,
              note: "A common emulsifier in ultra-processed foods; recent cohort studies are examining it."),
        .init(code: "e472e", name: "DATEM", tier: .low, note: "A dough conditioner."),
        .init(code: "e476", name: "PGPR", tier: .moderate, note: "An emulsifier used to reduce cocoa butter."),
        .init(code: "e481", name: "Sodium stearoyl lactylate", tier: .low, note: "A dough conditioner."),
        .init(code: "e1422", name: "Modified starch", tier: .low, note: "A processed starch."),
        .init(code: "e1442", name: "Modified starch", tier: .low, note: "A processed starch."),
        // Raising agents, minerals, anti-caking
        .init(code: "e170", name: "Calcium carbonate", tier: .none, note: "A mineral."),
        .init(code: "e500", name: "Sodium carbonates", tier: .none, note: "Baking soda."),
        .init(code: "e503", name: "Ammonium carbonates", tier: .none, note: "A raising agent."),
        .init(code: "e551", name: "Silicon dioxide", tier: .low, note: "An anti-caking agent."),
        // Flavour enhancers
        .init(code: "e621", name: "Monosodium glutamate", tier: .low,
              note: "Generally regarded as safe; mainly a marker of savoury processed food."),
        .init(code: "e627", name: "Disodium guanylate", tier: .low, note: "A flavour enhancer."),
        .init(code: "e631", name: "Disodium inosinate", tier: .low, note: "A flavour enhancer."),
        .init(code: "e635", name: "Disodium ribonucleotides", tier: .low, note: "A flavour enhancer."),
        // Sweeteners
        .init(code: "e950", name: "Acesulfame K", tier: .moderate,
              note: "An artificial sweetener; the WHO advises against relying on sweeteners for weight control."),
        .init(code: "e951", name: "Aspartame", tier: .elevated,
              note: "Classified by IARC as possibly carcinogenic to humans (Group 2B) in 2023."),
        .init(code: "e952", name: "Cyclamate", tier: .elevated,
              note: "Not permitted in foods in the United States."),
        .init(code: "e954", name: "Saccharin", tier: .moderate, note: "An artificial sweetener."),
        .init(code: "e955", name: "Sucralose", tier: .moderate,
              note: "An artificial sweetener; recent lab studies have examined its breakdown products."),
        .init(code: "e960", name: "Steviol glycosides", tier: .low, note: "A plant-derived sweetener."),
        .init(code: "e967", name: "Xylitol", tier: .low, note: "A sugar alcohol."),
        .init(code: "e968", name: "Erythritol", tier: .moderate,
              note: "A 2023 study linked higher blood levels to cardiovascular events; research is ongoing."),
        .init(code: "e901", name: "Beeswax", tier: .none, note: "A glazing agent."),
    ]

    private static let table: [String: AdditiveInfo] =
        Dictionary(entries.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
}
