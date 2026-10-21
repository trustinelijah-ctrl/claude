import Foundation
import Observation
import StoreKit

/// TABLE Pro: one purchase that unlocks the extra boards and piece sets, the stronger
/// opponents and the game library. StoreKit 2; entitlements are read from the verified
/// transaction history, so a reinstall or a second iPad picks the purchase straight up.
///
/// In Xcode the scheme points at `Table.storekit`, so the purchase can be tried on the
/// simulator or a development iPad without App Store Connect.
@MainActor
@Observable
final class ProStore {
    static let productID = "app.table.chess.pro"

    /// Remembered between launches, so Pro is there at once while the store is checked.
    private(set) var isPro = false {
        didSet { UserDefaults.standard.set(isPro, forKey: "pro.owned") }
    }
    private(set) var product: Product?
    private(set) var isPurchasing = false
    /// A short, human message after a purchase or restore that did not go through.
    var message: String?

    /// Shown until the product has loaded from the store.
    var displayPrice: String { product?.displayPrice ?? "$4.99" }

    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        // `-pro YES` unlocks for screenshot runs.
        isPro = UserDefaults.standard.bool(forKey: "pro") || UserDefaults.standard.bool(forKey: "pro.owned")
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

    func load() async {
        if product == nil {
            product = try? await Product.products(for: [Self.productID]).first
        }
        await refresh()
    }

    func refresh() async {
        if UserDefaults.standard.bool(forKey: "pro") { isPro = true; return }
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    func purchase() async {
        message = nil
        if product == nil { await load() }
        guard let product else {
            message = "The store isn't reachable right now. Try again in a moment."
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
                } else {
                    message = "The purchase couldn't be verified."
                }
            case .pending:
                message = "Waiting for approval. Pro unlocks as soon as it's approved."
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
        await refresh()
        if !isPro { message = "No earlier purchase of TABLE Pro was found for this Apple ID." }
    }
}
