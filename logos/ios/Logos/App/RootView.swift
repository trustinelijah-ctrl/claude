import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            stack(.today) { TodayView() }
                .tabItem { Label(store.L("TODAY", "HEUTE"), systemImage: "clock") }.tag(Tab.today)
            stack(.path) { PathView() }
                .tabItem { Label(store.L("PATH", "WEG"), systemImage: "building.columns") }.tag(Tab.path)
            stack(.review) { ReviewView() }
                .tabItem { Label(store.L("REVIEW", "ABRUF"), systemImage: "arrow.counterclockwise") }.tag(Tab.review)
                .badge(store.dueItems.count)
            stack(.practice) { PracticeView() }
                .tabItem { Label(store.L("PRACTICE", "ÜBEN"), systemImage: "waveform") }.tag(Tab.practice)
            stack(.library) { LibraryView() }
                .tabItem { Label(store.L("LIBRARY", "BIBLIOTHEK"), systemImage: "books.vertical") }.tag(Tab.library)
        }
        .environment(\.symbolVariants, .none)
        .transaction { if reduceMotion { $0.animation = nil } }
        .sensoryFeedback(.selection, trigger: router.tab)
    }

    func stack<V: View>(_ t: Tab, @ViewBuilder _ root: () -> V) -> some View {
        NavigationStack(path: router.binding(t)) {
            root().logosDestinations().toolbar(.hidden, for: .navigationBar)
        }
    }
}
