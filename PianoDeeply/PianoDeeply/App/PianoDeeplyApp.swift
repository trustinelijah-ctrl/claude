import SwiftUI
import SwiftData

@main
struct PianoDeeplyApp: App {
    @State private var app = AppState()
    @State private var recorder = AudioRecorder()
    @State private var player = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(recorder)
                .environment(player)
                .tint(Palette.forest)
        }
        .modelContainer(for: AppSchema.models)
    }
}
