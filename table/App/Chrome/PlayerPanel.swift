import SwiftUI
import ChessCore

/// One player's end of the board: their name engraved in gold, a felt-lined tray where the
/// pieces they take come to stand, and two brass pins for controls. Laid out for the player
/// at the bottom; the top player's zone is the same view turned with its whole layer.
struct PlayerZone: View {
    let color: PieceColor
    let session: GameSession
    let settings: SettingsStore
    let layout: TableLayout
    let openSettings: () -> Void

    private var theme: BoardTheme { settings.theme }
    private var isComputer: Bool { settings.computerColor == color }
    private var isTurn: Bool { !session.isOver && session.sideToMove == color }
    private var name: String { isComputer ? "TABLE" : (color == .white ? "White" : "Black") }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            tray
            switch layout.arrangement {
            case .ends: ends
            case .sides: sides
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("panel-\(color.rawValue)")
    }

    // MARK: Arrangements

    /// Portrait: name on the left, tray in the middle, pins on the right.
    private var ends: some View {
        let z = layout.zone
        return ZStack(alignment: .topLeading) {
            identity
                .frame(width: max(0, layout.tray.minX - z.minX - 12), alignment: .leading)
                .position(x: z.minX + (layout.tray.minX - z.minX - 12) / 2, y: z.midY)
            if !isComputer {
                pins
                    .position(x: layout.tray.maxX + (z.maxX - layout.tray.maxX) / 2, y: z.midY)
            } else {
                thinking
                    .position(x: layout.tray.maxX + (z.maxX - layout.tray.maxX) / 2, y: z.midY)
            }
            leadLabel
                .position(x: layout.tray.maxX - 22, y: layout.tray.minY - 10)
        }
    }

    /// Landscape: tray at the top of the column, then name and pins beneath.
    private var sides: some View {
        let z = layout.zone
        return VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            identity
            if isComputer { thinking } else { pins }
        }
        .frame(width: z.width, height: max(0, z.maxY - layout.tray.maxY - 12), alignment: .bottomLeading)
        .position(x: z.midX, y: layout.tray.maxY + 12 + (z.maxY - layout.tray.maxY - 12) / 2)
    }

    // MARK: Parts

    /// A recess in the board, lined with felt, edged with a fine gilt line.
    private var tray: some View {
        let r = layout.tray
        let corner = min(r.height, r.width) * 0.22
        return RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(theme.isDark ? Color.black.opacity(0.32) : Color(hex: 0x3A3024, opacity: 0.10))
            .overlay(
                // inner shadow: the upper lip casts into the recess
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(LinearGradient(colors: [.black.opacity(theme.isDark ? 0.6 : 0.25), .clear],
                                           startPoint: .top, endPoint: .center), lineWidth: 6)
                    .blur(radius: 3)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(theme.inlay.opacity(0.42), lineWidth: 0.75)
            )
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
            .accessibilityHidden(true)
    }

    private var identity: some View {
        let large = !layout.compact
        return VStack(alignment: .leading, spacing: large ? 1 : -1) {
            Text(name)
                .font(Typeface.display(large ? 32 : 24))
                .tracking(isComputer ? 5 : 0.5)
                .foregroundStyle(engraved)
                .shadow(color: .black.opacity(theme.isDark ? 0.6 : 0.15), radius: 0, y: 1)
            Text(status)
                .font(Typeface.italic(large ? 19 : 16))
                .foregroundStyle(statusColor)
                .contentTransition(.opacity)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .animation(.easeInOut(duration: 0.3), value: status)
        .animation(.easeInOut(duration: 0.3), value: isTurn)
        .accessibilityElement(children: .combine)
    }

    /// Gold leaf in a light-catching gradient, as if pressed into the surface.
    private var engraved: LinearGradient {
        let lit = isTurn || session.isOver
        return LinearGradient(colors: [Color(hex: 0xF1DCA6).opacity(lit ? 1 : 0.55),
                                       theme.accent.opacity(lit ? 1 : 0.5),
                                       Color(hex: 0x9C7A3E).opacity(lit ? 1 : 0.5)],
                              startPoint: .top, endPoint: .bottom)
    }

    private var status: String {
        if let r = session.result {
            switch r {
            case .checkmate(let w): return w == color ? "Wins by checkmate" : "Checkmated"
            case .resignation(let w): return w == color ? "Wins" : "Resigned"
            case .draw: return "Draw"
            }
        }
        if isComputer {
            return isTurn ? "Thinking" : settings.botLevel.title
        }
        if isTurn { return session.checkedKing != nil ? "In check" : "Your move" }
        return "Waiting"
    }

    private var statusColor: Color {
        if session.result?.winner == color { return theme.accent }
        if isTurn && session.checkedKing != nil { return theme.check }
        return isTurn ? theme.ink.opacity(0.85) : theme.inkSecondary
    }

    /// While the computer chooses, three small dots breathe in turn.
    private var thinking: some View {
        HStack(spacing: 7) {
            if session.isThinking {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 6, height: 6)
                        .phaseAnimator([0.25, 1.0]) { dot, phase in
                            dot.opacity(phase)
                        } animation: { _ in .easeInOut(duration: 0.45).delay(Double(i) * 0.15) }
                }
                .transition(.opacity)
            }
        }
        .frame(width: 60, height: 44)
        .animation(.easeInOut(duration: 0.25), value: session.isThinking)
    }

    @ViewBuilder
    private var leadLabel: some View {
        let lead = session.materialLead(for: color)
        if lead > 0 {
            Text("+\(lead)")
                .font(Typeface.display(17, bold: true))
                .monospacedDigit()
                .foregroundStyle(theme.accent.opacity(0.85))
        }
    }

    private var pins: some View {
        HStack(spacing: 14) {
            if session.canClaimDraw && isTurn {
                Button {
                    session.feedback.ui()
                    session.claimDraw()
                } label: {
                    Text("Claim draw")
                        .font(Typeface.italic(18))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .overlay(Capsule().strokeBorder(theme.inlay.opacity(0.5), lineWidth: 0.75))
                }
                .buttonStyle(PressScaleStyle())
            }
            BrassPin(symbol: "arrow.uturn.backward", label: "Undo", enabled: session.canUndo) {
                session.feedback.ui()
                session.undo()
            }
            BrassPin(symbol: "ellipsis", label: "Settings", enabled: true) {
                session.feedback.ui()
                openSettings()
            }
        }
    }
}

/// A control set into the board like a small polished brass stud.
struct BrassPin: View {
    let symbol: String
    let label: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xF7E8C0), Color(hex: 0xD4AF66), Color(hex: 0x8A672E)],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 26))
                Circle()
                    .strokeBorder(LinearGradient(colors: [Color(hex: 0xFFF3D0).opacity(0.9), Color(hex: 0x5E4419)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x3D2B10).opacity(0.85))
                    .shadow(color: Color(hex: 0xFFF1C8).opacity(0.6), radius: 0, y: 0.75)
            }
            .frame(width: 38, height: 38)
            .shadow(color: .black.opacity(0.45), radius: 2.5, y: 1.5)
            .saturation(enabled ? 1 : 0.2)
            .opacity(enabled ? 1 : 0.5)
            .frame(width: 46, height: 46)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
