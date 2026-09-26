import SwiftUI
import Observation

enum Tab: String, CaseIterable, Hashable { case today, path, review, practice, library }

enum Route: Hashable {
    case lesson
    case pickLesson
    case plan(String)
    case planDay(String, Int)
    case module(String)
    case memorySession
    case memorise(String)
    case concept(String)
    case scripture(String)
    case source(String)
    case argument(String)
    case voices
    case voice(String)
    case craft
    case figure(String)
    case rhetoric
    case reflect
    case speechBank
    case capture(String?)
    case settings
    case sync
}

@Observable
final class Router {
    var tab: Tab = .today
    var paths: [Tab: NavigationPath] = Dictionary(uniqueKeysWithValues: Tab.allCases.map { ($0, NavigationPath()) })

    func push(_ r: Route, on t: Tab? = nil) {
        let target = t ?? tab
        if target != tab { tab = target }
        paths[target, default: NavigationPath()].append(r)
    }
    func popToRoot(_ t: Tab? = nil) { paths[t ?? tab] = NavigationPath() }
    func pop(_ t: Tab? = nil) { let k = t ?? tab; if !(paths[k]?.isEmpty ?? true) { paths[k]?.removeLast() } }

    func binding(_ t: Tab) -> Binding<NavigationPath> {
        Binding(get: { self.paths[t] ?? NavigationPath() }, set: { self.paths[t] = $0 })
    }

    /// logos://voice/augustine, logos://review, logos://lesson … (widgets, notifications, links from the web).
    func open(_ url: URL) {
        guard url.scheme == "logos" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host {
        case "review": popToRoot(.review); tab = .review; push(.memorySession, on: .review)
        case "lesson": popToRoot(.today); tab = .today; push(.lesson, on: .today)
        case "path": tab = .path
        case "voice": if let id = parts.first { push(.voice(id), on: .practice) } else { push(.voices, on: .practice) }
        case "figure": if let id = parts.first { push(.figure(id), on: .practice) }
        case "concept": if let id = parts.first { push(.concept(id), on: .library) }
        case "sync": push(.sync, on: .practice)
        default: tab = .today
        }
    }
}

extension View {
    func logosDestinations() -> some View {
        navigationDestination(for: Route.self) { r in
            switch r {
            case .lesson: LessonFlowView()
            case .pickLesson: PickLessonView()
            case .plan(let id): PlanView(planId: id)
            case .planDay(let id, let d): PlanDayView(planId: id, day: d)
            case .module(let id): ModuleView(moduleId: id)
            case .memorySession: MemorySessionView()
            case .memorise(let id): MemoriseView(itemId: id)
            case .concept(let id): ConceptView(conceptId: id)
            case .scripture(let k): ScriptureView(key: k)
            case .source(let id): SourceView(sourceId: id)
            case .argument(let id): ArgumentView(argumentId: id)
            case .voices: VoicesView()
            case .voice(let id): VoiceView(voiceId: id)
            case .craft: CraftView()
            case .figure(let id): FigureView(figureId: id)
            case .rhetoric: RhetoricView()
            case .reflect: ReflectView()
            case .speechBank: SpeechBankView()
            case .capture(let id): CaptureEditor(captureId: id)
            case .settings: SettingsView()
            case .sync: SyncView()
            }
        }
    }
}
