import Foundation
import Observation

/// User settings persisted in UserDefaults.
@Observable
@MainActor
final class Preferences {
    enum Lens: String, CaseIterable, Identifiable {
        case plantForward, flexible
        var id: String { rawValue }
        var title: String { self == .plantForward ? "Plant-forward" : "Flexible" }
        var detail: String {
            self == .plantForward
                ? "Follows whole-food, plant-based research. Meat, dairy and eggs lower the score."
                : "Halves the adjustment for animal foods. Processing, sugar and additives count the same."
        }
        var profile: ScoringProfile { self == .plantForward ? .plantForward : .flexible }
    }

    struct Allergen: Identifiable, Hashable {
        let tag: String
        let name: String
        var id: String { tag }
    }

    static let allergenOptions: [Allergen] = [
        .init(tag: "en:gluten", name: "Gluten"),
        .init(tag: "en:milk", name: "Milk"),
        .init(tag: "en:eggs", name: "Eggs"),
        .init(tag: "en:peanuts", name: "Peanuts"),
        .init(tag: "en:nuts", name: "Tree nuts"),
        .init(tag: "en:soybeans", name: "Soy"),
        .init(tag: "en:sesame-seeds", name: "Sesame"),
        .init(tag: "en:fish", name: "Fish"),
        .init(tag: "en:crustaceans", name: "Shellfish"),
        .init(tag: "en:mustard", name: "Mustard"),
        .init(tag: "en:celery", name: "Celery"),
        .init(tag: "en:sulphur-dioxide-and-sulphites", name: "Sulphites"),
    ]

    private let defaults = UserDefaults.standard

    var lens: Lens {
        didSet { defaults.set(lens.rawValue, forKey: PreferenceKeys.lens) }
    }
    var allergens: Set<String> {
        didSet { defaults.set(Array(allergens), forKey: PreferenceKeys.allergens) }
    }
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: PreferenceKeys.haptics) }
    }
    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: PreferenceKeys.onboarded) }
    }

    init() {
        lens = Lens(rawValue: defaults.string(forKey: PreferenceKeys.lens) ?? "") ?? .plantForward
        allergens = Set(defaults.stringArray(forKey: PreferenceKeys.allergens) ?? [])
        hapticsEnabled = defaults.object(forKey: PreferenceKeys.haptics) as? Bool ?? true
        hasOnboarded = defaults.bool(forKey: PreferenceKeys.onboarded)
    }

    var profile: ScoringProfile { lens.profile }

    func allergenMatches(for product: Product) -> [Allergen] {
        Self.allergenOptions.filter { allergens.contains($0.tag) && product.allergens.contains($0.tag) }
    }
}

/// Daily streak — the small, sticky reward loop.
@Observable
@MainActor
final class StreakStore {
    private let defaults = UserDefaults.standard
    private(set) var days: Int
    private(set) var best: Int

    init() {
        days = defaults.integer(forKey: PreferenceKeys.streakDays)
        best = defaults.integer(forKey: PreferenceKeys.bestStreak)
        // A missed day resets the visible streak.
        if let last = defaults.object(forKey: PreferenceKeys.streakLastDay) as? Date,
           let gap = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last),
                                                     to: Calendar.current.startOfDay(for: .now)).day,
           gap > 1 {
            days = 0
        }
    }

    /// Records activity today. Returns true when the streak grew.
    @discardableResult
    func recordScan(now: Date = .now) -> Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let last = (defaults.object(forKey: PreferenceKeys.streakLastDay) as? Date).map(cal.startOfDay(for:))
        if last == today { return false }
        if let last, cal.dateComponents([.day], from: last, to: today).day == 1 {
            days += 1
        } else {
            days = 1
        }
        best = max(best, days)
        defaults.set(days, forKey: PreferenceKeys.streakDays)
        defaults.set(best, forKey: PreferenceKeys.bestStreak)
        defaults.set(today, forKey: PreferenceKeys.streakLastDay)
        return true
    }
}
