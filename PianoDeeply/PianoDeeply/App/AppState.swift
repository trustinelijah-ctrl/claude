import SwiftUI
import Observation

enum AppTab: Hashable {
    case today, practice, map, journal
}

/// Full-screen, immersive surfaces. Carrying the session object keeps the
/// summary on screen after the session ends and drops out of "active" queries.
enum AppCover: Identifiable {
    case session(PracticeSession)
    case justPlay(PracticeSession)
    case welcome

    var id: String {
        switch self {
        case .session(let s): "session-\(s.id)"
        case .justPlay(let s): "justplay-\(s.id)"
        case .welcome: "welcome"
        }
    }
}

enum AppSheet: Identifiable {
    case setup(focusTaskID: UUID?)
    case inventory
    case settings

    var id: String {
        switch self {
        case .setup(let id): "setup-\(id?.uuidString ?? "none")"
        case .inventory: "inventory"
        case .settings: "settings"
        }
    }
}

/// App-wide navigation. One cover and one sheet at a time; anything that has
/// to open after another dismisses goes in `pendingCover` / `pendingSheet`.
@Observable
final class AppState {
    var tab: AppTab = .today
    var cover: AppCover?
    var sheet: AppSheet?
    var pendingCover: AppCover?
    var pendingSheet: AppSheet?

    func planSession(focus task: PracticeTask? = nil) {
        sheet = .setup(focusTaskID: task?.id)
    }

    func open(_ session: PracticeSession) {
        cover = session.kind == .justPlay ? .justPlay(session) : .session(session)
    }

    /// Called from the sheet's and cover's onDismiss.
    func presentPending() {
        if let next = pendingCover {
            pendingCover = nil
            cover = next
        } else if let next = pendingSheet {
            pendingSheet = nil
            sheet = next
        }
    }
}
