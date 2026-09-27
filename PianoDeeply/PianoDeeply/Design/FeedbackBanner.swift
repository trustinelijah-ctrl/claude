import SwiftUI
import PianoCore

/// The response after logging an experiment. A finished experiment that
/// worked gets a brass glow and one light haptic; anything else gets the same
/// words without the fanfare. Nothing here reacts to taps alone.
struct FeedbackBanner: View {
    let feedback: ExperimentFeedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                if feedback.celebrate {
                    Circle()
                        .fill(Palette.brass.opacity(0.35))
                        .frame(width: 34, height: 34)
                        .scaleEffect(glow ? 1.9 : 1)
                        .opacity(glow ? 0 : 1)
                }
                Image(systemName: feedback.celebrate ? "checkmark" : "scope")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(feedback.celebrate ? Palette.onForest : Palette.forest)
                    .frame(width: 34, height: 34)
                    .background(feedback.celebrate ? Palette.forest : Palette.forestWash, in: Circle())
            }

            Text(feedback.message)
                .font(.body.weight(.medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
        .onAppear {
            guard feedback.celebrate, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.4)) { glow = true }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FeedbackPresenter: ViewModifier {
    @Binding var feedback: ExperimentFeedback?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hapticTrigger = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let feedback {
                    FeedbackBanner(feedback: feedback)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .onTapGesture { self.feedback = nil }
                        .accessibilityAction(named: "Dismiss") { self.feedback = nil }
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86), value: feedback)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: hapticTrigger)
            .onChange(of: feedback) { _, new in
                guard let new else { return }
                if new.celebrate { hapticTrigger += 1 }
                AccessibilityNotification.Announcement(new.message).post()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(5))
                    if feedback == new { feedback = nil }
                }
            }
    }
}

extension View {
    func feedbackBanner(_ feedback: Binding<ExperimentFeedback?>) -> some View {
        modifier(FeedbackPresenter(feedback: feedback))
    }
}

#Preview("Worked") {
    FeedbackBanner(feedback: .after(outcome: .worked, tempo: 72, phase: .afterPractice)).padding()
}

#Preview("Not yet") {
    FeedbackBanner(feedback: .after(outcome: .notYet, tempo: nil, phase: .afterPractice)).padding()
}
