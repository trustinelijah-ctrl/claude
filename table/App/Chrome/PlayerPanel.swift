import SwiftUI
import ChessCore

/// One player's side of the table: their name, whose move it is, the pieces they have
/// taken standing beside the board, and two quiet controls.
struct PlayerPanel: View {
    let color: PieceColor
    let session: GameSession
    let theme: BoardTheme
    let layout: TableLayout
    let openSettings: () -> Void

    private var isTurn: Bool { !session.isOver && session.sideToMove == color }
    private var name: String { color == .white ? "White" : "Black" }

    var body: some View {
        Group {
            switch layout.arrangement {
            case .strips: strip
            case .columns: column
            }
        }
        .frame(width: layout.panel.width, height: layout.panel.height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("panel-\(color.rawValue)")
    }

    /// Captured pieces are drawn at a size that suits the room the panel has.
    private var trophySize: CGFloat {
        switch layout.arrangement {
        case .strips: return min(64, max(30, layout.panel.height * 0.42))
        case .columns: return min(52, max(28, layout.panel.width * 0.2))
        }
    }

    // MARK: Arrangements

    private var strip: some View {
        HStack(alignment: .center, spacing: 18) {
            identity(large: !layout.compact)
            trophies(size: trophySize, rows: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if session.canClaimDraw && isTurn { claimDraw }
            controls
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 0)
            trophies(size: trophySize, rows: 2)
            identity(large: !layout.compact)
            if session.canClaimDraw && isTurn { claimDraw }
            controls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Pieces of the panel

    private func identity(large: Bool) -> some View {
        VStack(alignment: .leading, spacing: large ? 0 : -2) {
            Text(name)
                .font(Typeface.display(large ? 34 : 26))
                .foregroundStyle(theme.ink.opacity(isTurn || session.isOver ? 1 : 0.62))
            Text(status)
                .font(Typeface.italic(large ? 20 : 17))
                .foregroundStyle(statusColor)
                .contentTransition(.opacity)
                .lineLimit(1)
        }
        .fixedSize()
        .animation(.easeInOut(duration: 0.3), value: status)
        .animation(.easeInOut(duration: 0.3), value: isTurn)
        .accessibilityElement(children: .combine)
    }

    private var status: String {
        if let r = session.result {
            switch r {
            case .checkmate(let w): return w == color ? "Wins by checkmate" : "Checkmated"
            case .resignation(let w): return w == color ? "Wins" : "Resigned"
            case .draw: return "Draw"
            }
        }
        if isTurn { return session.checkedKing != nil ? "In check" : "Your move" }
        return "Waiting"
    }

    private var statusColor: Color {
        if session.result?.winner == color { return theme.accent }
        if isTurn && session.checkedKing != nil { return theme.check }
        return isTurn ? theme.accent : theme.inkSecondary
    }

    private var captures: [Piece] { session.captures(by: color) }
    private var lead: Int { session.materialLead(for: color) }

    /// Taken pieces stand on the table beside the board, the way they do in a real game.
    @ViewBuilder
    private func trophies(size: CGFloat, rows: Int) -> some View {
        let pieces = captures.filter { $0.kind != .pawn }
        let pawns = captures.filter { $0.kind == .pawn }
        if rows == 1 {
            HStack(alignment: .bottom, spacing: 6) {
                standing(pieces + pawns, size: size)
                if lead > 0 { leadLabel }
            }
        } else {
            VStack(alignment: .leading, spacing: -size * 0.28) {
                standing(pieces, size: size)
                HStack(alignment: .bottom, spacing: 6) {
                    standing(pawns, size: size * 0.92)
                    if lead > 0 { leadLabel }
                }
            }
        }
    }

    private func standing(_ pieces: [Piece], size: CGFloat) -> some View {
        HStack(spacing: -size * 0.5) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { item in
                StandingPiece(piece: item.element, size: size, shadow: theme.pieceShadow * 0.9)
                    .transition(.scale(scale: 0.7, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pieces.count)
    }

    private var leadLabel: some View {
        Text("+\(lead)")
            .font(Typeface.display(18, bold: true))
            .monospacedDigit()
            .foregroundStyle(theme.inkSecondary)
            .padding(.bottom, 4)
    }

    private var claimDraw: some View {
        Button {
            session.feedback.ui()
            session.claimDraw()
        } label: {
            Text("Claim draw")
                .font(Typeface.italic(19))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .overlay(Capsule().strokeBorder(theme.panelStroke, lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityHint(session.game.canClaimThreefold ? "Threefold repetition" : "Fifty-move rule")
    }

    private var controls: some View {
        HStack(spacing: 12) {
            IconButton(symbol: "arrow.uturn.backward", label: "Undo", theme: theme, enabled: session.canUndo) {
                session.feedback.ui()
                session.undo()
            }
            IconButton(symbol: "ellipsis", label: "Settings", theme: theme, enabled: true) {
                session.feedback.ui()
                openSettings()
            }
        }
    }
}

/// A small round control ringed in a fine gilt line: 44 pt to the finger, 40 pt to the eye.
struct IconButton: View {
    let symbol: String
    let label: String
    let theme: BoardTheme
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(theme.ink.opacity(enabled ? 0.82 : 0.28))
                .frame(width: 40, height: 40)
                .background(Circle().fill(theme.panel.opacity(0.6)))
                .overlay(Circle().strokeBorder(theme.panelStroke.opacity(enabled ? 1 : 0.4), lineWidth: 0.75))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
