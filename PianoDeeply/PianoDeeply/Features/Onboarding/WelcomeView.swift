import SwiftUI
import PianoCore

/// First launch. Explains the six-sample inventory and lets you skip it.
struct WelcomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                KeyboardMotif()
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Piano, Deeply")
                        .font(.display)
                    Text("Decide what to play, work on one thing properly, and keep a record that shows it getting easier.")
                        .font(.title3)
                        .foregroundStyle(Palette.inkSoft)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Start with a six-sample inventory")
                        .font(.displayHeadline)
                    Text("Play six short things cold, about fifteen minutes in all. Nothing is scored. Four weeks later you play the same six again and listen to the difference.")
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(InventorySample.allCases) { sample in
                            Label(sample.title, systemImage: sample.branch.symbol)
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    .padding(.top, 4)
                }

                VStack(spacing: 8) {
                    Button("Start the inventory") {
                        hasSeenWelcome = true
                        app.pendingSheet = .inventory
                        dismiss()
                    }
                    .buttonStyle(.primary)

                    Button("I'll do this later") {
                        hasSeenWelcome = true
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.canvas.ignoresSafeArea())
    }
}

#if DEBUG
#Preview("Fresh install") {
    WelcomeView()
        .previewEnvironment(.fresh)
}
#endif
