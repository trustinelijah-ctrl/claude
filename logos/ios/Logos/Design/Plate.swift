import SwiftUI

/// One of the corpus's engraving plates, drawn as vectors in bronze.
struct Plate: View {
    @Environment(AppStore.self) private var store
    let id: String?
    var height: CGFloat = 120
    @State private var drawn: CGFloat = 0

    var body: some View {
        let svg = store.corpus.plates[id ?? ""] ?? store.corpus.plates["virtue"] ?? ""
        let shapes = PlateGeometry.parse(svg)
        Canvas { ctx, size in
            let s = min(size.width / PlateGeometry.viewBox.w, size.height / PlateGeometry.viewBox.h)
            let dx = (size.width - PlateGeometry.viewBox.w * s) / 2, dy = (size.height - PlateGeometry.viewBox.h * s) / 2
            for sh in shapes {
                var p = Path()
                func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: dx + x * s, y: dy + y * s) }
                for op in sh.ops {
                    switch op {
                    case let .move(x, y): p.move(to: pt(x, y))
                    case let .line(x, y): p.addLine(to: pt(x, y))
                    case let .curve(a, b, c, d, e, f): p.addCurve(to: pt(e, f), control1: pt(a, b), control2: pt(c, d))
                    case .close: p.closeSubpath()
                    }
                }
                let color = Color.bronze.opacity(sh.opacity)
                if sh.filled { ctx.fill(p, with: .color(color)) }
                else {
                    ctx.stroke(p.trimmedPath(from: 0, to: drawn), with: .color(color),
                               style: StrokeStyle(lineWidth: 1.25 * s, lineCap: .round, lineJoin: .round,
                                                  dash: sh.dash.map { CGFloat($0) * s }))
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .onAppear {
            if UIAccessibility.isReduceMotionEnabled { drawn = 1 }
            else { withAnimation(.easeInOut(duration: 1.4)) { drawn = 1 } }
        }
    }
}

/// The vellum ground with the web's faint, fixed paper grain.
struct Paper: View {
    var body: some View {
        Color.vellum
            .overlay {
                Canvas { ctx, size in
                    var rng = SplitMix(seed: 0x10605)
                    let n = Int(size.width * size.height / 90)
                    for _ in 0..<n {
                        let x = Double(rng.next() % 10_000) / 10_000 * size.width
                        let y = Double(rng.next() % 10_000) / 10_000 * size.height
                        let a = Double(rng.next() % 100) / 100
                        ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(Color.ink.opacity(0.035 * a)))
                    }
                }
                .drawingGroup()
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
    }
}

struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
