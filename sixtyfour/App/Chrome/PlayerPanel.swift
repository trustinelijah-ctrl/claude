import SwiftUI
import ChessCore

/// One player's strip at their end of the board: the pieces they have taken, their clock,
/// and small brass pins for undo, a hint and the menu. Laid out for the player at the
/// bottom; the top player's strip is the same view turned with its whole layer.
struct PlayerZone: View {
    let color: PieceColor
    let session: GameSession
    let settings: SettingsStore
    let layout: TableLayout
    /// For the far strip when nobody sits there (against the computer): its words turn to
    /// face the player at the near end.
    var facesNearPlayer = false
    /// Opens the full view of everything this player has taken.
    var showCaptures: () -> Void = {}
    var requestHint: () -> Void = {}
    /// Back to the home screen; the game waits there under Continue.
    var goHome: () -> Void = {}
    let openSettings: () -> Void

    /// Resigning takes two taps: the flag turns into a "Resign" button for a few seconds.
    @State private var resignArmed = false

    private var theme: BoardTheme { settings.theme }
    private var isComputer: Bool { settings.computerColor == color }
    private var isTurn: Bool { !session.isOver && session.sideToMove == color }

    var body: some View {
        let z = layout.zone
        ZStack(alignment: .topLeading) {
            Color.clear
            trayTarget
            trayCounter
            // The strip's own controls, in a container no larger than the strip, so the far
            // player's (rotated) layer never covers this player's pins.
            Group {
                switch layout.arrangement {
                case .ends: ends
                case .sides: sides
                }
            }
            .frame(width: z.width, height: z.height, alignment: .topLeading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("panel-\(color.rawValue)")
            .position(x: z.midX, y: z.midY)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
    }

    // MARK: Arrangements (in zone coordinates)

    /// Portrait: captured pieces on the left; status, clock and pins on the right.
    @ViewBuilder
    private var ends: some View {
        if layout.stacked { stackedEnds } else { wideEnds }
    }

    /// A narrow end: tray, status and clock in a row along the board, the pins beneath.
    private var stackedEnds: some View {
        let z = layout.zone
        let trayRight = layout.tray.maxX - z.minX
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Spacer(minLength: trayRight)
                status
                    .rotationEffect(facesNearPlayer ? .degrees(180) : .zero)
                if session.clock != nil {
                    ClockFace(color: color, session: session, theme: theme, large: false)
                        .rotationEffect(facesNearPlayer ? .degrees(180) : .zero)
                }
            }
            .frame(height: layout.tray.height)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                fittedControls(alignment: .trailing)
            }
        }
        .padding(.trailing, 4)
        .frame(width: z.width, height: z.height)
    }

    private var wideEnds: some View {
        let z = layout.zone
        let trayRight = layout.tray.maxX - z.minX
        return HStack(spacing: 14) {
            Spacer(minLength: trayRight)
            status
                .rotationEffect(facesNearPlayer ? .degrees(180) : .zero)
            if session.clock != nil {
                ClockFace(color: color, session: session, theme: theme, large: !layout.compact)
                    .rotationEffect(facesNearPlayer ? .degrees(180) : .zero)
            }
            fittedControls(alignment: .trailing)
                .rotationEffect(facesNearPlayer ? .degrees(180) : .zero)
        }
        .padding(.trailing, 4)
        .frame(width: z.width, height: z.height)
    }

    /// Landscape: tray at the top of the column, then clock, status and pins beneath.
    private var sides: some View {
        let z = layout.zone
        let top = layout.tray.maxY - z.minY + 10
        return VStack(alignment: .leading, spacing: 12) {
            Spacer(minLength: 0)
            if session.clock != nil {
                ClockFace(color: color, session: session, theme: theme, large: !layout.compact)
                    .rotationEffect(facesNearPlayer ? .degrees(180) : .zero)
            }
            status
                .rotationEffect(facesNearPlayer ? .degrees(180) : .zero)
            fittedControls(alignment: .leading)
        }
        .frame(width: z.width, height: max(0, z.height - top), alignment: .bottomLeading)
        .position(x: z.width / 2, y: top + (z.height - top) / 2)
        .frame(width: z.width, height: z.height, alignment: .topLeading)
    }

    // MARK: Parts

    /// The captured pieces are drawn by the board layer; this is the touch area over them.
    private var trayTarget: some View {
        let r = layout.tray
        return Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(width: r.width, height: r.height)
            .contentShape(Rectangle())
            .onTapGesture {
                guard captured > 0 else { return }
                session.feedback.ui()
                showCaptures()
            }
            .position(x: r.midX, y: r.midY)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Captured pieces")
            .accessibilityValue("\(captured)")
            .accessibilityIdentifier("tray-\(color.rawValue)")
            .accessibilityAction { if captured > 0 { showCaptures() } }
    }

    private var captured: Int { session.trayCount(color) }

    /// When the tray is full, the oldest pieces fold into a small gold counter at its start.
    @ViewBuilder
    private var trayCounter: some View {
        let w = layout.trayWindow(count: captured)
        if w.hidden > 0 {
            let slot = layout.traySlot(0, count: w.slots)
            let d = layout.trayPiece * 0.56
            Text("+\(w.hidden)")
                .font(.system(size: d * 0.42, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color(hex: 0x3D2B10))
                .frame(width: d, height: d)
                .background(
                    Circle().fill(RadialGradient(colors: [Color(hex: 0xF7E8C0), Color(hex: 0xD4AF66), Color(hex: 0x8A672E)],
                                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: d * 0.7))
                )
                .overlay(Circle().strokeBorder(Color(hex: 0xFFF3D0).opacity(0.7), lineWidth: 0.75))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                .rotationEffect(facesNearPlayer ? .degrees(180) : .zero)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: w.hidden)
                .position(x: slot.x, y: slot.y - layout.trayPiece * 0.3)
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// A short line only when there is something to say: whose move, check, or the computer thinking.
    @ViewBuilder
    private var status: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if isComputer {
                HStack(spacing: 6) {
                    if session.isThinking { ThinkingDots(color: theme.accent) }
                    Text("64")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.accent)
                }
                Text(settings.botLevel.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.inkSecondary)
            } else if let line = statusLine {
                Text(line)
                    .font(.system(size: layout.compact ? 14 : 16, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .contentTransition(.opacity)
                if lead > 0 {
                    Text("+\(lead)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(theme.accent.opacity(0.9))
                }
            } else if lead > 0 {
                Text("+\(lead)")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent.opacity(0.9))
            }
        }
        .lineLimit(1)
        .animation(.easeInOut(duration: 0.25), value: statusLine)
        .accessibilityElement(children: .combine)
    }

    private var lead: Int { session.materialLead(for: color) }

    private var statusLine: String? {
        if let r = session.result {
            if r.winner == color { return "Won" }
            if r.winner == nil { return "Draw" }
            return nil
        }
        guard isTurn else { return nil }
        return session.checkedKing != nil ? "Check" : "Your move"
    }

    private var statusColor: Color {
        if session.result?.winner == color { return theme.accent }
        if isTurn && session.checkedKing != nil { return theme.check }
        return theme.ink
    }

    /// The pins in one row, or in two when the space is too narrow for one.
    private func fittedControls(alignment: HorizontalAlignment) -> some View {
        ViewThatFits(in: .horizontal) {
            controls(rows: nil)
            VStack(alignment: alignment, spacing: 0) {
                controls(rows: 0)
                controls(rows: 1)
            }
        }
    }

    /// The player's pins: hint (against the computer), undo, resign, home and the menu.
    /// `rows` picks the first or second half when a narrow column stacks them.
    @ViewBuilder
    private func controls(rows: Int?) -> some View {
        if !isComputer {
            HStack(spacing: layout.stacked ? 4 : 10) {
                if rows != 1 {
                    if session.canClaimDraw && isTurn {
                        Button {
                            session.feedback.ui()
                            session.claimDraw()
                        } label: {
                            Text("Claim draw")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .overlay(Capsule().strokeBorder(theme.accent.opacity(0.5), lineWidth: 0.75))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                    // Hints are for practising against the computer, never in a game between two people.
                    if settings.isAgainstComputer {
                        BrassPin(symbol: "lightbulb", label: "Hint", enabled: isTurn && !session.isHinting) {
                            session.feedback.ui()
                            requestHint()
                        }
                    }
                    BrassPin(symbol: "arrow.uturn.backward", label: "Undo", enabled: session.canUndo) {
                        session.feedback.ui()
                        session.undo()
                    }
                    resign
                }
                if rows != 0 {
                    BrassPin(symbol: "house", label: "Home", enabled: true) {
                        session.feedback.ui()
                        goHome()
                    }
                    .accessibilityIdentifier("pin-home-\(color.rawValue)")
                    BrassPin(symbol: "ellipsis", label: "Settings", enabled: true) {
                        session.feedback.ui()
                        openSettings()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resign: some View {
        if resignArmed && !session.isOver {
            Button {
                session.feedback.ui()
                resignArmed = false
                session.resign(color)
            } label: {
                Text("Resign")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(theme.check))
                    .frame(minHeight: 44)
            }
            .buttonStyle(PressScaleStyle())
            .transition(.scale(scale: 0.8).combined(with: .opacity))
            .accessibilityIdentifier("confirm-resign-\(color.rawValue)")
        } else {
            BrassPin(symbol: "flag", label: "Resign", enabled: !session.isOver) {
                session.feedback.ui()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { resignArmed = true }
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation(.easeOut(duration: 0.2)) { resignArmed = false }
                }
            }
            .accessibilityIdentifier("pin-resign-\(color.rawValue)")
        }
    }
}

/// A player's clock: bright while running, quiet while waiting, red in the last ten seconds.
struct ClockFace: View {
    let color: PieceColor
    let session: GameSession
    let theme: BoardTheme
    var large = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
            let clock = session.clock
            let left = clock?.timeLeft(color, at: timeline.date) ?? 0
            let running = clock?.running == color && clock?.isTicking == true
            let low = left < 10
            Text(Self.format(left))
                .font(Typeface.clock(large ? 34 : 26))
                .foregroundStyle(running ? (low ? .white : Brand.brown) : theme.ink.opacity(left == 0 ? 0.9 : 0.55))
                .padding(.horizontal, large ? 16 : 12)
                .frame(minWidth: large ? 120 : 92, minHeight: large ? 52 : 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(running ? (low ? theme.check : Brand.cream) : theme.ink.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.accent.opacity(running ? 0.9 : 0.3), lineWidth: running ? 1.5 : 0.75)
                )
                .animation(.easeInOut(duration: 0.2), value: running)
                .accessibilityElement()
                .accessibilityLabel("\(color == .white ? "White" : "Black") clock")
                .accessibilityValue(Self.format(left))
                .accessibilityIdentifier("clock-\(color.rawValue)")
        }
    }

    static func format(_ seconds: Double) -> String {
        if seconds < 20 {
            return String(format: "%.1f", max(0, seconds))
        }
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Three small dots breathing in turn, while the computer chooses.
struct ThinkingDots: View {
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .phaseAnimator([0.25, 1.0]) { dot, phase in
                        dot.opacity(phase)
                    } animation: { _ in .easeInOut(duration: 0.45).delay(Double(i) * 0.15) }
            }
        }
        .transition(.opacity)
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
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 22))
                Circle()
                    .strokeBorder(LinearGradient(colors: [Color(hex: 0xFFF3D0).opacity(0.9), Color(hex: 0x5E4419)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x3D2B10).opacity(0.85))
            }
            .frame(width: 32, height: 32)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1.5)
            .saturation(enabled ? 1 : 0.2)
            .opacity(enabled ? 1 : 0.45)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
