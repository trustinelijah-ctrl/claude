import Foundation
import Observation
import SwiftData

/// Items collected in Grocery mode, looked up in parallel as they're scanned.
@Observable
@MainActor
final class GroceryBasket {
    enum State: Equatable {
        case loading
        case ready(ScoredProduct)
        case missing
    }

    struct Item: Identifiable, Equatable {
        let barcode: String
        var state: State
        var id: String { barcode }

        var scored: ScoredProduct? {
            if case .ready(let s) = state { return s }
            return nil
        }
    }

    static let capacity = 12

    private(set) var items: [Item] = []

    var isFull: Bool { items.count >= Self.capacity }
    var ready: [ScoredProduct] { items.compactMap(\.scored) }
    var ranked: [ScoredProduct] { ready.sorted { $0.score.score > $1.score.score } }
    var isLoading: Bool { items.contains { $0.state == .loading } }

    /// Returns true if the barcode was new and added.
    @discardableResult
    func add(_ barcode: String, services: AppServices, context: ModelContext) -> Bool {
        guard !isFull, !items.contains(where: { $0.barcode == barcode }) else { return false }
        items.append(Item(barcode: barcode, state: .loading))
        Task { await resolve(barcode, services: services, context: context) }
        return true
    }

    func remove(_ barcode: String) {
        items.removeAll { $0.barcode == barcode }
    }

    func clear() {
        items.removeAll()
    }

    private func resolve(_ barcode: String, services: AppServices, context: ModelContext) async {
        let result = await services.lookup(barcode: barcode, context: context)
        guard let index = items.firstIndex(where: { $0.barcode == barcode }) else { return }
        switch result {
        case .found(let product, _):
            let score = services.score(product)
            services.remember(product, score: score, context: context)
            items[index].state = .ready(ScoredProduct(product: product, score: score))
        case .notFound, .failed:
            items[index].state = .missing
        }
    }
}
