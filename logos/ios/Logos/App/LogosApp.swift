import SwiftUI

@main
struct LogosApp: App {
    @State private var store: AppStore
    @State private var router = Router()
    @Environment(\.scenePhase) private var phase

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LOGOS", isDirectory: true)
        let updater = CorpusUpdater(cacheURL: support.appendingPathComponent("corpus.json"))
        // Newest content first: a corpus fetched from the deploy, else the one in the app bundle.
        let corpus = updater.cached() ?? Self.bundledCorpus()
        _store = State(initialValue: AppStore(corpus: corpus, fileURL: support.appendingPathComponent("logos.json")))
        Appearance.apply()
    }

    static func bundledCorpus() -> Corpus {
        guard let url = Bundle.main.url(forResource: "corpus", withExtension: "json"),
              let data = try? Data(contentsOf: url), let c = try? Corpus(data: data) else { return Corpus() }
        return c
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .preferredColorScheme(.light)
                .tint(.ink)
                .task {
                    // `-route lesson` opens a screen directly (used by CI screenshots).
                    let args = ProcessInfo.processInfo.arguments
                    if let i = args.firstIndex(of: "-route"), i + 1 < args.count, let u = URL(string: "logos://" + args[i + 1]) {
                        router.open(u)
                    }
                    await refreshCorpus()
                }
                .onOpenURL { router.open($0) }
        }
        .onChange(of: phase) { _, p in
            if p != .active { store.writeNow() }
            if p == .active { Task { await refreshCorpus() } }
        }
    }

    /// Picks up content deployed to Netlify since this build shipped.
    func refreshCorpus() async {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LOGOS", isDirectory: true)
        let updater = CorpusUpdater(cacheURL: support.appendingPathComponent("corpus.json"))
        if let newer = await updater.fetchNewer(than: store.corpus.version) {
            await MainActor.run { store.corpus = newer }
        }
    }
}

enum Appearance {
    static func apply() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = .vellum
        nav.shadowColor = .rule
        let serif = UIFont(name: "IowanOldStyle-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        nav.titleTextAttributes = [.font: serif, .foregroundColor: UIColor.ink]
        nav.largeTitleTextAttributes = [.font: UIFont(name: "IowanOldStyle-Bold", size: 32) ?? .boldSystemFont(ofSize: 32), .foregroundColor: UIColor.ink]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = .ink

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = .vellum
        tab.shadowColor = .rule
        let item = UITabBarItemAppearance()
        let label = UIFont.systemFont(ofSize: 10, weight: .semibold)
        item.normal.titleTextAttributes = [.font: label, .foregroundColor: UIColor.ink4, .kern: 1.4]
        item.selected.titleTextAttributes = [.font: label, .foregroundColor: UIColor.ink, .kern: 1.4]
        item.normal.badgeBackgroundColor = UIColor(red: 0x6E / 255, green: 0x22 / 255, blue: 0x33 / 255, alpha: 1)
        item.normal.iconColor = .ink4
        item.selected.iconColor = .ink
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
