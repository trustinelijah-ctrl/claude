import Foundation
import Observation
import StoreKit

/// 64 Pro: a subscription, monthly or yearly (the yearly plan starts with a week free), or
/// a one-time Lifetime purchase. In the launch weeks a cheaper Founder lifetime is on sale;
/// once it is taken off sale in App Store Connect the app offers the regular Lifetime.
/// Entitlements are read from StoreKit's verified transactions, so a reinstall or another
/// iPad picks the subscription straight up, and it ends by itself when it lapses.
///
/// In Xcode the scheme points at `SixtyFour.storekit`, so the plans can be tried on the
/// simulator or a development iPad without App Store Connect.
@MainActor
@Observable
final class ProStore {
    enum Plan: String, CaseIterable, Identifiable {
        case yearly = "app.sixtyfour.pro.yearly"
        case monthly = "app.sixtyfour.pro.monthly"
        case lifetime = "app.sixtyfour.pro.lifetime"
        case founder = "app.sixtyfour.pro.founder"
        var id: String { rawValue }
        var fallbackPrice: String {
            switch self {
            case .yearly: return "€19.99"
            case .monthly: return "€3.99"
            case .lifetime: return "€39.99"
            case .founder: return "€24.99"
            }
        }
        var isSubscription: Bool { self == .yearly || self == .monthly }
    }

    /// The one-time option on offer: Founder while it is on sale, Lifetime after.
    var lifetimePlan: Plan { products[.founder] != nil || products.isEmpty ? .founder : .lifetime }

    /// Remembered between launches, so Pro is there at once while the store is checked.
    private(set) var isPro = false {
        didSet { UserDefaults.standard.set(isPro, forKey: "pro.owned") }
    }
    private(set) var products: [Plan: Product] = [:]
    private(set) var isPurchasing = false
    private(set) var isLoading = false
    /// Whether this Apple ID can still start the free week. Unknown (false) until the store answers.
    private(set) var trialAvailable = ProStore.isTestBuild
    /// The plan behind the active entitlement, if any (nil for a test unlock).
    private(set) var activePlan: Plan?

    /// Real prices have arrived from the App Store. A development build without a store
    /// shows the fallback prices so the paywall can still be tried.
    var storeReady: Bool { !products.isEmpty || Self.isTestBuild }
    /// A short, plain message after a purchase or restore that did not go through.
    var message: String?

    /// Set when Pro has just been bought or restored, so the welcome can be shown.
    enum Welcome: Equatable {
        /// Subscribed; `trialEnds` is when the free week ends, if it started one.
        case subscribed(trialEnds: Date?)
        /// Bought once, for good.
        case lifetime
        case restored
    }
    var welcome: Welcome?

    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        // `-pro YES` unlocks for screenshot runs.
        isPro = Self.forcedPro || UserDefaults.standard.bool(forKey: "pro.owned")
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result {
                    await t.finish()
                    await self?.refresh()
                }
            }
        }
        Task { await load() }
    }

    private static var weekFromNow: Date { Date().addingTimeInterval(7 * 24 * 3600) }

    func price(_ plan: Plan) -> String { products[plan]?.displayPrice ?? plan.fallbackPrice }

    /// The yearly price as a monthly figure, for comparison.
    var yearlyPerMonth: String {
        guard let p = products[.yearly] else { return "€1.67" }
        return (p.price / 12).formatted(p.priceFormatStyle)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        if products.isEmpty, let loaded = try? await Product.products(for: Plan.allCases.map(\.rawValue)) {
            for p in loaded {
                if let plan = Plan(rawValue: p.id) { products[plan] = p }
            }
        }
        if let sub = products[.yearly]?.subscription {
            trialAvailable = await sub.isEligibleForIntroOffer && sub.introductoryOffer != nil
        } else if !products.isEmpty {
            trialAvailable = false
        }
        await refresh()
    }

    /// A development build installed without Xcode has no store to talk to; Pro can still be
    /// tried with a test unlock, which never exists in a release build.
    static var isTestBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    /// `-pro YES` unlocks for screenshot runs; development builds only.
    private static var forcedPro: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "pro")
        #else
        return false
        #endif
    }

    var hasTestUnlock: Bool { Self.isTestBuild && UserDefaults.standard.bool(forKey: "pro.test") }

    func endTestUnlock() {
        UserDefaults.standard.set(false, forKey: "pro.test")
        Task { await refresh() }
    }

    func refresh() async {
        if Self.forcedPro || hasTestUnlock { isPro = true; return }
        var active: Plan?
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, let plan = Plan(rawValue: t.productID), t.revocationDate == nil {
                // A one-time purchase wins over a subscription when both exist.
                if active == nil || !plan.isSubscription { active = plan }
            }
        }
        activePlan = active
        isPro = active != nil
    }

    func purchase(_ plan: Plan) async {
        message = nil
        Analytics.signal("purchase.started", ["plan": "\(plan)"])
        if products[plan] == nil { await load() }
        guard let product = products[plan] else {
            if Self.isTestBuild {
                UserDefaults.standard.set(true, forKey: "pro.test")
                isPro = true
                welcome = plan.isSubscription ? .subscribed(trialEnds: plan == .yearly && trialAvailable ? Self.weekFromNow : nil) : .lifetime
                message = "Test purchase: Pro is on in this development build. Nothing was charged."
            } else {
                message = "The App Store isn't reachable right now. Try again in a moment."
            }
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                    isPro = true
                    Analytics.signal("purchase.completed", ["plan": "\(plan)"])
                    if plan.isSubscription {
                        let trial = t.offerType == .introductory
                        welcome = .subscribed(trialEnds: trial ? (t.expirationDate ?? Self.weekFromNow) : nil)
                        trialAvailable = false
                    } else {
                        welcome = .lifetime
                    }
                } else {
                    message = "The purchase couldn't be verified."
                }
            case .pending:
                message = "Waiting for approval. Pro turns on as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn't go through. You haven't been charged."
        }
    }

    func restore() async {
        message = nil
        try? await AppStore.sync()
        let had = isPro
        await refresh()
        if !isPro { message = "No 64 Pro purchase was found for this Apple ID." }
        else if !had {
            welcome = .restored
            Analytics.signal("purchase.restored")
        }
    }
}
