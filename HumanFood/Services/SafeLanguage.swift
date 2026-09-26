import Foundation

/// Keeps every sentence the app shows factual, opinion-framed and brand-neutral.
///
/// Why: product-disparagement and trade-libel claims hinge on false statements
/// of fact about a specific company's product. We therefore (1) never name a
/// brand in generated prose, (2) avoid absolute harm words, and (3) frame
/// ratings as Human Food's opinion based on public data. See docs/SAFE_LANGUAGE.md.
enum SafeLanguage {
    private static let replacements: [(pattern: String, replacement: String)] = [
        (#"\bnon-toxic\b"#, "gentle"),
        (#"\btoxins?\b"#, "compounds of concern"),
        (#"\btoxic\b"#, "concerning"),
        (#"\bpoisonous\b"#, "concerning"),
        (#"\bpoisons?\b"#, "concerning ingredient"),
        (#"\bdangerous\b"#, "worth limiting"),
        (#"\bharmful\b"#, "less favourable"),
        (#"\bunhealthy\b"#, "less favourable"),
        (#"\bunsafe\b"#, "worth limiting"),
        (#"\bjunk food\b"#, "highly processed food"),
        (#"\bjunk\b"#, "highly processed"),
        (#"\bcauses? cancer\b"#, "has been studied in relation to cancer risk"),
        (#"\bcancer-causing\b"#, "studied in relation to cancer risk"),
        (#"\bcarcinogenic\b"#, "classified by some agencies as a possible risk"),
        (#"\bfake food\b"#, "highly processed food"),
        (#"\bchemicals\b"#, "additives"),
        (#"\bdeadly\b"#, "concerning"),
        (#"\bkills?\b"#, "may affect"),
        (#"\bavoid at all costs\b"#, "best kept rare"),
        (#"\bnever eat\b"#, "consider limiting"),
        (#"\bterrible\b"#, "less favourable"),
        (#"\bdisgusting\b"#, "less appealing"),
        (#"\bgarbage\b"#, "highly processed"),
        // House style: no em/en dashes or exclamation marks in generated prose.
        (#"\s*—\s*|\s+–\s+"#, ", "),  // keeps numeric ranges like "2–3"
        (#"!"#, "."),
    ]

    static func clean(_ text: String, brand: String? = nil) -> String {
        var out = text
        for (pattern, replacement) in replacements {
            out = out.replacingOccurrences(of: pattern, with: replacement,
                                           options: [.regularExpression, .caseInsensitive])
        }
        if let brand {
            for name in brand.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) })
            where name.count >= 3 {
                out = out.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: name),
                                               with: "this product",
                                               options: [.regularExpression, .caseInsensitive])
            }
        }
        return out
    }

    static let disclaimer = """
    Human Food scores are our independent opinion, calculated with a published method from publicly \
    available data (mainly Open Food Facts) and nutrition research. They are general information, not \
    medical or dietary advice, and product data may be incomplete or out of date — always check the \
    label, especially for allergies. No brand or manufacturer is affiliated with or endorses Human Food.
    """
}
