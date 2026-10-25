import SwiftUI

/// Shown the moment 64 Pro is bought or restored: a gold seal, what is now unlocked, and
/// when a free week ends, so nobody wonders whether the purchase went through.
struct ProWelcome: View {
    let welcome: ProStore.Welcome
    let feedback: FeedbackCoordinator
    let close: () -> Void

    @State private var sealIn = false
    @State private var shine = false
    @State private var shown = 0

    private var features: [ProCard.Feature] { ProCard.features }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Color(hex: 0x140B06).opacity(0.62))
                .ignoresSafeArea()
            GoldDust()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            ViewThatFits(in: .vertical) {
                card
                ScrollView(.vertical, showsIndicators: false) { card.padding(.vertical, 24) }
            }
            .padding(24)
        }
        .environment(\.colorScheme, .dark)
        .onAppear(perform: play)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro-welcome")
    }

    private var card: some View {
        VStack(spacing: 22) {
            seal
            VStack(spacing: 8) {
                Text(welcome == .restored ? "64 Pro is back" : "Welcome to 64 Pro")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Brand.cream)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Brand.cream.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Brand.gold)
                            .scaleEffect(i < shown ? 1 : 0.4)
                        Text(f.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Brand.cream)
                        Spacer(minLength: 0)
                    }
                    .opacity(i < shown ? 1 : 0)
                    .offset(x: i < shown ? 0 : -8)
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Brand.gold.opacity(0.25), lineWidth: 0.75))
            VStack(spacing: 10) {
                Button {
                    feedback.ui()
                    close()
                } label: {
                    Text("Start playing")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Brand.brown)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(GoldCapsule())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("pro-welcome-done")
                Text("Manage or cancel anytime in Settings ▸ your name ▸ Subscriptions.")
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.cream.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: 440)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2A1810), Color(hex: 0x1A0F09)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.5), radius: 40, y: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color(hex: 0xF3DFA8), Brand.gold.opacity(0.5), Color(hex: 0x8A672E)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }

    /// The 64 mark struck in gold, with a gleam passing over it.
    private var seal: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFBEFC8), Color(hex: 0xD9B465), Color(hex: 0x8C6A2F)],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: 70))
            Circle()
                .strokeBorder(LinearGradient(colors: [Color(hex: 0xFFF6DA), Color(hex: 0x6E5121)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 2)
                .padding(5)
            Image("Logo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(Brand.brown)
                .padding(26)
            LinearGradient(colors: [.clear, .white.opacity(0.65), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40)
                .rotationEffect(.degrees(20))
                .offset(x: shine ? 90 : -90)
                .blendMode(.plusLighter)
                .mask(Circle())
        }
        .frame(width: 112, height: 112)
        .clipShape(Circle())
        .shadow(color: Brand.gold.opacity(0.45), radius: 24)
        .scaleEffect(sealIn ? 1 : 0.5)
        .opacity(sealIn ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var subtitle: String {
        switch welcome {
        case .subscribed(let trialEnds?):
            let day = trialEnds.formatted(date: .long, time: .omitted)
            return "Your free week has started. Nothing is charged before \(day), and you can cancel before then."
        case .subscribed(nil):
            return "Thank you for supporting 64. Everything is unlocked."
        case .restored:
            return "Your subscription was found. Everything is unlocked again."
        }
    }

    /// The seal lands with a knock and a bell; then each unlocked feature ticks into place.
    private func play() {
        feedback.audio.play(.checkmate, gain: 0.55)
        feedback.haptics.checkmate(after: 0.05)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { sealIn = true }
        withAnimation(.easeInOut(duration: 1.1).delay(0.45)) { shine = true }
        for i in 0..<features.count {
            let delay = 0.6 + Double(i) * 0.14
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { shown = i + 1 }
                feedback.audio.play(.placeLight, gain: 0.35)
                feedback.haptics.place(after: 0, weight: 0.35)
            }
        }
    }
}
