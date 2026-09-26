import SwiftUI

/// The reward moment: the ring sweeps, the numeral counts up with rising
/// haptic ticks, colour shifts through the tiers, then it locks with a bloom.
/// Good scores earn a burst of leaves and the "Human Food" seal.
struct ScoreHero: View {
    let score: Int
    var animate: Bool = true
    var size: CGFloat = 228
    /// When set, the ring can fly into the result header's dial (matched geometry).
    var namespace: Namespace.ID? = nil
    var onFinished: () -> Void = {}

    @State private var value: Double = 0
    @State private var burst = 0
    @State private var locked = false
    @State private var showSeal = false

    private var finalTier: ScoreTier { ScoreTier(score: score) }
    private var liveTier: ScoreTier { ScoreTier(score: Int(value.rounded())) }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(liveTier.color.opacity(locked ? 0.28 : 0.10))
                    .frame(width: size * 1.05, height: size * 1.05)
                    .blur(radius: 46)
                    .animation(.easeOut(duration: 0.6), value: locked)

                RippleBurst(trigger: burst, color: finalTier.color)
                    .frame(width: size, height: size)

                ScoreRing(value: value, lineWidth: size * 0.055)
                    .frame(width: size, height: size)

                VStack(spacing: 2) {
                    Text("\(Int(value.rounded()))")
                        .font(HF.Font.numeral(size * 0.36))
                        .tracking(-size * 0.012)
                        .foregroundStyle(liveTier.color)
                        .contentTransition(.numericText(value: value))
                        .animation(.easeInOut(duration: 0.25), value: liveTier)
                    Text("out of 100")
                        .eyebrow()
                }
                .scaleEffect(locked ? 1 : 0.94)

                if finalTier.celebrates {
                    ParticleBurst(trigger: burst,
                                  colors: [finalTier.color, HF.Palette.good, HF.Palette.fair.opacity(0.9), HF.Palette.ink.opacity(0.25)],
                                  count: finalTier == .excellent ? 60 : 34,
                                  power: finalTier == .excellent ? 1.15 : 0.8)
                        .frame(width: size * 2, height: size * 2)
                }

                if showSeal {
                    HumanFoodSeal()
                        .offset(x: size * 0.44, y: -size * 0.42)
                        .transition(.scale(scale: 2.2).combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .modifier(MatchedDial(namespace: namespace))
            .scaleEffect(locked ? 1 : 0.97)

            VStack(spacing: 8) {
                TierPill(tier: liveTier)
                    .animation(HF.Motion.snappy, value: liveTier)
                Text(finalTier.phrase)
                    .hfDisplay(22)
                    .foregroundStyle(HF.Palette.ink)
                    .opacity(locked ? 1 : 0)
                    .offset(y: locked ? 0 : 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100. \(finalTier.title). \(finalTier.phrase).")
        .task { await run() }
    }

    private func run() async {
        guard animate else {
            value = Double(score)
            locked = true
            showSeal = finalTier == .excellent
            return
        }
        Haptics.prepare()
        try? await Task.sleep(for: .milliseconds(280))

        let target = Double(score)
        let duration = 1.0 + target / 100 * 0.8
        let start = Date.now
        var lastStep = -1
        while !Task.isCancelled {
            let t = min(1, Date.now.timeIntervalSince(start) / duration)
            // easeOutQuart — fast start, suspenseful finish.
            let eased = 1 - pow(1 - t, 4)
            value = eased * target
            let step = Int(value) / 3
            if step != lastStep {
                lastStep = step
                Haptics.countTick(progress: value / 100)
            }
            if t >= 1 { break }
            try? await Task.sleep(for: .milliseconds(16))
        }
        guard !Task.isCancelled else { return }

        withAnimation(HF.Motion.bouncy) { locked = true }
        burst += 1
        if finalTier.celebrates { Haptics.success() } else { Haptics.lock() }
        if finalTier == .excellent {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) { showSeal = true }
            Haptics.lock()
        }
        onFinished()
    }
}

struct MatchedDial: ViewModifier {
    var namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: "dial", in: namespace)
        } else {
            content
        }
    }
}

/// The circular "HUMAN FOOD" seal awarded to 85+ scores.
struct HumanFoodSeal: View {
    var body: some View {
        ZStack {
            Circle().fill(HF.Palette.excellent)
            Circle().strokeBorder(.white.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .padding(4)
            VStack(spacing: 1) {
                Image(systemName: "leaf.fill").font(.system(size: 13, weight: .semibold))
                Text("HUMAN\nFOOD")
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-1)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 62, height: 62)
        .rotationEffect(.degrees(-12))
        .shadow(color: HF.Palette.excellent.opacity(0.4), radius: 10, y: 4)
        .accessibilityLabel("Human Food seal")
    }
}

#Preview {
    VStack(spacing: 40) {
        ScoreHero(score: 92)
        ScoreHero(score: 34, size: 140)
    }
    .padding()
    .background(HF.Palette.canvas)
}
