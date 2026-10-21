import SwiftUI
import ChessCore

/// Everything one player has taken, laid out on a frosted card over a blurred table:
/// opened by touching their tray, closed by touching anywhere.
struct CapturesPanel: View {
    let owner: PieceColor
    let session: GameSession
    let settings: SettingsStore
    let close: () -> Void

    @State private var shown = false

    private var theme: BoardTheme { settings.theme }
    private static let order: [PieceKind] = [.queen, .rook, .bishop, .knight, .pawn]

    private var groups: [(kind: PieceKind, count: Int)] {
        let kinds = session.tokens.filter { $0.isCaptured && $0.capturedBy == owner }.map(\.piece.kind)
        return Self.order.compactMap { k in
            let n = kinds.filter { $0 == k }.count
            return n > 0 ? (k, n) : nil
        }
    }

    private var title: String {
        if settings.computerColor == owner { return "Taken by 64" }
        return settings.isAgainstComputer ? "Your captures" : "Taken by \(ResultText.name(owner))"
    }

    var body: some View {
        let total = groups.reduce(0) { $0 + $1.count }
        let points = groups.reduce(0) { $0 + $1.kind.value * $1.count }
        let lead = session.materialLead(for: owner)
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(title)
                    .font(Typeface.display(28))
                    .foregroundStyle(theme.ink)
                Text("\(total) \(total == 1 ? "piece" : "pieces") · \(points) \(points == 1 ? "point" : "points")")
                    .font(Typeface.text(15))
                    .foregroundStyle(theme.inkSecondary)
            }
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(groups.enumerated()), id: \.offset) { i, g in
                    VStack(spacing: 2) {
                        ZStack {
                            // Several of a kind stand in a little row, one behind the other.
                            ForEach(0..<min(g.count, 4), id: \.self) { j in
                                StandingPiece(piece: Piece(owner.opposite, g.kind), size: 100, shadow: 0.35)
                                    .offset(x: CGFloat(j) * 15 - CGFloat(min(g.count, 4) - 1) * 7.5, y: CGFloat(-j) * 2)
                                    .zIndex(Double(-j))
                            }
                        }
                        .frame(width: 100 + CGFloat(min(g.count, 4) - 1) * 15, height: 100)
                        Text("×\(g.count)")
                            .font(Typeface.display(18, bold: true))
                            .monospacedDigit()
                            .foregroundStyle(theme.accent)
                    }
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 16)
                    .animation(.spring(response: 0.42, dampingFraction: 0.78).delay(0.05 + Double(i) * 0.06), value: shown)
                }
            }
            if lead != 0 {
                Text(lead > 0 ? "Ahead by \(lead) on the board" : "Behind by \(-lead) on the board")
                    .font(Typeface.text(14))
                    .foregroundStyle(lead > 0 ? theme.accent : theme.inkSecondary)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill((theme.isDark ? Color.black : Color.white).opacity(0.18)))
                .shadow(color: .black.opacity(0.35), radius: 30, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(theme.inlay.opacity(0.45), lineWidth: 0.75)
        )
        .scaleEffect(shown ? 1 : 0.94)
        .onAppear { shown = true }
        .onTapGesture(perform: close)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("captures")
        .accessibilityAddTraits(.isModal)
    }
}
