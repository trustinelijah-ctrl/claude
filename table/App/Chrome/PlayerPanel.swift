import SwiftUI
import ChessCore

/// Everything one player needs, on their own side of the table: whose move it is,
/// what they have taken, and two quiet controls.
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

    // MARK: Arrangements

    private var strip: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: layout.compact ? 4 : 8) {
                identity
                if !layout.compact || !captures.isEmpty { capturedRow(size: layout.compact ? 20 : 28) }
            }
            Spacer(minLength: 8)
            if session.canClaimDraw && isTurn { claimDraw }
            controls
        }
        .padding(.horizontal, 4)
        .frame(maxHeight: .infinity, alignment: layout.compact ? .center : .top)
        .padding(.top, layout.compact ? 0 : 6)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            capturedRows(size: layout.compact ? 22 : 28)
            identity
            if session.canClaimDraw && isTurn { claimDraw }
            controls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Pieces of the panel

    private var identity: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isTurn ? theme.turnGlow : Color.clear)
                .overlay(Circle().strokeBorder(theme.inkSecondary.opacity(isTurn ? 0 : 0.8), lineWidth: 1))
                .frame(width: 8, height: 8)
                .shadow(color: isTurn ? theme.turnGlow.opacity(0.8) : .clear, radius: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: layout.compact ? 15 : 17, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)
                Text(status)
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(statusColor)
                    .contentTransition(.opacity)
                    .lineLimit(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: status)
        .animation(.easeInOut(duration: 0.25), value: isTurn)
        .accessibilityElement(children: .combine)
    }

    private var status: String {
        if let r = session.result {
            switch r {
            case .checkmate(let w): return w == color ? "Wins" : "Checkmated"
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
        return isTurn ? theme.ink.opacity(0.78) : theme.inkSecondary
    }

    private var captures: [Piece] { session.captures(by: color) }

    private var lead: Int { session.materialLead(for: color) }

    private func capturedRow(size: CGFloat) -> some View {
        HStack(spacing: 6) {
            overlapped(captures, size: size)
            if lead > 0 { leadLabel }
        }
        .frame(height: size * 1.12)
        .animation(.easeOut(duration: 0.2), value: captures.count)
    }

    private func capturedRows(size: CGFloat) -> some View {
        let pieces = captures.filter { $0.kind != .pawn }
        let pawns = captures.filter { $0.kind == .pawn }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                overlapped(pieces, size: size)
                if lead > 0 && pawns.isEmpty { leadLabel }
            }
            .frame(height: size * 1.12)
            if !pawns.isEmpty {
                HStack(spacing: 6) {
                    overlapped(pawns, size: size)
                    if lead > 0 { leadLabel }
                }
                .frame(height: size * 1.12)
            }
        }
        .animation(.easeOut(duration: 0.2), value: captures.count)
    }

    /// Taken pieces stand on a small felt tray, so ebony pieces stay legible on a dark table.
    @ViewBuilder
    private func overlapped(_ pieces: [Piece], size: CGFloat) -> some View {
        if !pieces.isEmpty {
            HStack(spacing: -size * 0.38) {
                ForEach(Array(pieces.enumerated()), id: \.offset) { item in
                    PieceGlyph(piece: item.element)
                        .frame(width: size, height: size)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, size * 0.22)
            .padding(.vertical, size * 0.06)
            .background(Capsule().fill(theme.isDark ? Color(hex: 0x8A7258, opacity: 0.30) : Color(hex: 0x24262A, opacity: 0.06)))
        }
    }

    private var leadLabel: some View {
        Text("+\(lead)")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(theme.inkSecondary)
    }

    private var claimDraw: some View {
        Button {
            session.feedback.ui()
            session.claimDraw()
        } label: {
            Text("Claim draw")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(theme.panel))
                .overlay(Capsule().strokeBorder(theme.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityHint(session.game.canClaimThreefold ? "Threefold repetition" : "Fifty-move rule")
    }

    private var controls: some View {
        HStack(spacing: 10) {
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

/// A small round control: 44 pt to the finger, 38 pt to the eye.
struct IconButton: View {
    let symbol: String
    let label: String
    let theme: BoardTheme
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.ink.opacity(enabled ? 0.85 : 0.3))
                .frame(width: 38, height: 38)
                .background(Circle().fill(theme.panel))
                .overlay(Circle().strokeBorder(theme.panelStroke, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
