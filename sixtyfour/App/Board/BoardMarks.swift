import SwiftUI
import ChessCore

/// Quiet marks drawn on the squares: last move, selection, legal destinations, drag target, check.
struct BoardMarks: View {
    let theme: BoardTheme
    let geometry: BoardGeometry
    /// The whole table, which this layer covers.
    let size: CGSize
    let lastMove: Move?
    let selection: Square?
    let targets: [Square]
    let occupiedTargets: Set<Square>
    let hover: Square?
    /// The square of a piece being held under a finger: it glows softly from beneath.
    let held: Square?
    let checkedKing: Square?
    let isMate: Bool
    let showHints: Bool
    /// A suggested move, drawn as a gold arrow.
    var hint: Move? = nil

    var body: some View {
        Canvas { ctx, _ in
            let g = geometry
            if let m = lastMove {
                ctx.fill(Path(g.rect(m.from)), with: .color(theme.lastMove))
                ctx.fill(Path(g.rect(m.to)), with: .color(theme.lastMove))
            }
            if let k = checkedKing {
                let c = g.center(k)
                let r = g.square * (isMate ? 0.72 : 0.62)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .radialGradient(Gradient(stops: [
                            .init(color: theme.check.opacity(isMate ? 0.85 : 0.62), location: 0),
                            .init(color: theme.check.opacity(isMate ? 0.38 : 0.22), location: 0.55),
                            .init(color: theme.check.opacity(0), location: 1),
                         ]), center: c, startRadius: 0, endRadius: r))
            }
            if let s = selection {
                ctx.fill(Path(g.rect(s)), with: .color(theme.selection))
            }
            if let h = held {
                let c = g.center(h)
                let r = g.square * 0.62
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .radialGradient(Gradient(colors: [theme.turnGlow.opacity(0.45), theme.turnGlow.opacity(0)]),
                                               center: c, startRadius: 0, endRadius: r))
            }
            if showHints {
                for t in targets {
                    let c = g.center(t)
                    if occupiedTargets.contains(t) {
                        // A fine ring around a piece that can be taken.
                        let r = g.square * 0.455
                        let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                        ctx.stroke(ring, with: .color(theme.hint), lineWidth: max(1.5, g.square * 0.05))
                    } else {
                        let r = g.square * 0.125
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(theme.hint))
                    }
                }
            }
            if let hint {
                Self.arrow(ctx, g: g, move: hint, color: Color(hex: 0xD4AF66))
            }
            if let h = hover, h != selection {
                let inset = max(1, g.square * 0.02)
                let rect = g.rect(h).insetBy(dx: inset, dy: inset)
                ctx.stroke(Path(rect), with: .color(theme.hover), lineWidth: max(1.5, g.square * 0.035))
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A move drawn as an arrow from square to square.
    static func arrow(_ ctx: GraphicsContext, g: BoardGeometry, move: Move, color: Color) {
        let a = g.center(move.from), b = g.center(move.to)
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(1, (dx * dx + dy * dy).squareRoot())
        let ux = dx / len, uy = dy / len
        let head = g.square * 0.34, width = g.square * 0.13
        let tip = CGPoint(x: b.x - ux * g.square * 0.12, y: b.y - uy * g.square * 0.12)
        let base = CGPoint(x: tip.x - ux * head, y: tip.y - uy * head)
        let start = CGPoint(x: a.x + ux * g.square * 0.2, y: a.y + uy * g.square * 0.2)
        var shaft = Path()
        shaft.move(to: start)
        shaft.addLine(to: base)
        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: base.x - uy * head * 0.62, y: base.y + ux * head * 0.62))
        arrow.addLine(to: CGPoint(x: base.x + uy * head * 0.62, y: base.y - ux * head * 0.62))
        arrow.closeSubpath()
        ctx.stroke(shaft, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        ctx.fill(arrow, with: .color(color.opacity(0.85)))
    }
}
