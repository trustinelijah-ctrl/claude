import SwiftUI

/// Home · Shelf · (Scan) · You
struct MainTabView: View {
    enum Tab: Hashable {
        case home, shelf, you
        var title: String {
            switch self {
            case .home: "Home"
            case .shelf: "Shelf"
            case .you: "You"
            }
        }
    }

    @State private var tab: Tab = .home
    @State private var scanner: ScanMode?

    var body: some View {
        ZStack {
            HF.Palette.canvas.ignoresSafeArea()
            switch tab {
            case .home:
                HomeView(onScan: { scanner = .barcode }, onCompare: { scanner = .grocery }, onSeeAll: { tab = .you })
            case .shelf:
                ShelfView(onCompare: { scanner = .grocery })
            case .you:
                YouView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HFTabBar(selection: $tab) { scanner = .barcode }
        }
        .fullScreenCover(item: $scanner) { mode in
            ScannerScreen(initialMode: mode)
        }
    }
}
