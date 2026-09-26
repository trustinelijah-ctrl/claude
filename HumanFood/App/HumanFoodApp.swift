import SwiftData
import SwiftUI

@main
struct HumanFoodApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .tint(HF.Palette.ink)
        }
        .modelContainer(for: ScanRecord.self)
    }
}

struct RootView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        ZStack {
            if services.preferences.hasOnboarded {
                ScannerScreen()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        services.preferences.hasOnboarded = true
                    }
                }
                .transition(.opacity)
            }
        }
    }
}
