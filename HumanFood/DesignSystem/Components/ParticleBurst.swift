import SwiftUI

/// A one-shot burst of confetti "seeds" and leaves rendered with Canvas.
/// Bump `trigger` to fire again.
struct ParticleBurst: View {
    var trigger: Int
    var colors: [Color]
    var count: Int = 46
    var power: Double = 1

    @State private var particles: [Particle] = []
    @State private var start: Date = .distantPast

    private let lifetime: Double = 1.6

    var body: some View {
        TimelineView(.animation(paused: particles.isEmpty)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                guard t < lifetime else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for p in particles {
                    let age = t - p.delay
                    guard age > 0 else { continue }
                    let drag = 1 - exp(-age * 2.4)
                    let reach: Double = p.speed * drag / 2.4 * power
                    let dx: Double = cos(p.angle) * reach
                    let dy: Double = sin(p.angle) * reach + 90 * age * age
                    let x = center.x + CGFloat(dx)
                    let y = center.y + CGFloat(dy)
                    let fade = max(0, 1 - age / (lifetime - p.delay))
                    var ctx = context
                    ctx.opacity = fade
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(p.spin * age + p.angle))
                    let rect = CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.shape == .leaf ? p.size * 1.8 : p.size)
                    switch p.shape {
                    case .dot:
                        ctx.fill(Path(ellipseIn: rect), with: .color(p.color))
                    case .leaf:
                        ctx.fill(Path(roundedRect: rect, cornerRadius: p.size / 2), with: .color(p.color))
                    case .ring:
                        ctx.stroke(Path(ellipseIn: rect), with: .color(p.color), lineWidth: 1.5)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in fire() }
        .task(id: particles.isEmpty) {
            // Release the timeline once the burst has finished.
            guard !particles.isEmpty else { return }
            try? await Task.sleep(for: .seconds(lifetime + 0.1))
            particles = []
        }
    }

    private func fire() {
        start = .now
        particles = (0..<count).map { _ in
            Particle(angle: .random(in: 0..<(2 * .pi)),
                     speed: .random(in: 180...420),
                     size: .random(in: 4...9),
                     spin: .random(in: -8...8),
                     delay: .random(in: 0...0.12),
                     color: colors.randomElement() ?? .white,
                     shape: [.dot, .leaf, .leaf, .ring].randomElement()!)
        }
    }

    private struct Particle {
        enum Shape { case dot, leaf, ring }
        var angle: Double
        var speed: Double
        var size: Double
        var spin: Double
        var delay: Double
        var color: Color
        var shape: Shape
    }
}

/// Expanding ripple rings — the calmer reveal used for lower scores.
struct RippleBurst: View {
    var trigger: Int
    var color: Color

    @State private var phase: CGFloat = 1
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .scaleEffect(phase + CGFloat(i) * 0.12)
                    .opacity(opacity * (1 - Double(i) * 0.3))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            phase = 1
            opacity = 0.6
            withAnimation(.easeOut(duration: 1.1)) {
                phase = 1.45
                opacity = 0
            }
        }
    }
}
