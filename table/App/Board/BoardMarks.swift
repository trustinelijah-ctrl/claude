import SwiftUI
import ChessCore

/// Quiet marks drawn on the squares: last move, selection, legal destinations, drag target, check.
struct BoardMarks: View {
    let theme: BoardTheme
    let geometry: BoardGeometry
    let lastMove: Move?
    let selection: Square?
    let targets: [Square]
    let occupiedTargets: Set<Square>
    let hover: Square?
    let checkedKing: Square?
    let isMate: Bool
    let showHints: Bool

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
            if let h = hover, h != selection {
                let inset = max(1, g.square * 0.02)
                let rect = g.rect(h).insetBy(dx: inset, dy: inset)
                ctx.stroke(Path(rect), with: .color(theme.hover), lineWidth: max(1.5, g.square * 0.035))
            }
        }
        .frame(width: geometry.size, height: geometry.size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
