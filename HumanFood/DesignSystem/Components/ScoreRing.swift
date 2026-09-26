import SwiftUI

/// The hero ring. `progress` is 0…1 of the *final* score and is driven
/// externally so the ring, the numeral and the haptics stay in lock-step.
struct ScoreRing: View {
    var value: Double            // currently displayed score, 0…100
    var lineWidth: CGFloat = 14
    var trackOpacity: Double = 0.07

    private var tier: ScoreTier { ScoreTier(score: Int(value.rounded())) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(HF.Palette.ink.opacity(trackOpacity), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.001, value / 100))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [tier.color.opacity(0.55), tier.color]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(0.01, value / 100))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tier.color.opacity(0.35), radius: 10)
                .animation(.easeInOut(duration: 0.25), value: tier)

            // A bright head riding the end of the arc.
            GeometryReader { geo in
                let radius = min(geo.size.width, geo.size.height) / 2
                let angle = Angle.degrees(360 * value / 100 - 90)
                Circle()
                    .fill(.white.opacity(0.95))
                    .frame(width: lineWidth * 0.42, height: lineWidth * 0.42)
                    .position(x: geo.size.width / 2 + radius * cos(angle.radians),
                              y: geo.size.height / 2 + radius * sin(angle.radians))
            }
            .opacity(value > 1 ? 1 : 0)
        }
    }
}

/// Compact ring + number used in lists. Same drawing as the result-header dial.
struct ScoreBadge: View {
    var score: Int
    var size: CGFloat = 44

    var body: some View { ScoreDial(score: score, size: size) }
}

/// Pill with tier colour, e.g. "● Excellent".
struct TierPill: View {
    var tier: ScoreTier

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tier.color).frame(width: 7, height: 7)
            Text(tier.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HF.Palette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tier.color.opacity(0.12), in: Capsule())
    }
}
