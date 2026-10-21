import SwiftUI
import ChessCore

/// Settings and game controls, opened from either player's panel and turned to face them.
struct SettingsCard: View {
    @Bindable var settings: SettingsStore
    let session: GameSession
    let player: PieceColor
    let close: () -> Void

    private enum Confirm { case newGame, resign, draw }
    @State private var confirm: Confirm?

    private var theme: BoardTheme { settings.theme }

    var body: some View {
        VStack(spacing: 0) {
            header
            ViewThatFits(in: .vertical) {
                sections
                ScrollView(.vertical, showsIndicators: false) { sections }
            }
        }
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(theme.isDark ? Color(hex: 0x1D1713) : Color(hex: 0xF9F6F0))
                .shadow(color: .black.opacity(theme.isDark ? 0.55 : 0.22), radius: 40, y: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(theme.panelStroke, lineWidth: 1)
        )
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings")
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("Opponent") {
                Picker("Opponent", selection: $settings.opponent) {
                    Text("A friend").tag(Opponent.friend)
                    Text("TABLE").tag(Opponent.computer)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if settings.isAgainstComputer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Strength").font(.system(size: 15)).foregroundStyle(theme.ink)
                        Picker("Strength", selection: $settings.botLevel) {
                            ForEach(BotLevel.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You play").font(.system(size: 15)).foregroundStyle(theme.ink)
                        Picker("You play", selection: $settings.humanColor) {
                            Text("White").tag(PieceColor.white)
                            Text("Black").tag(PieceColor.black)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: settings.isAgainstComputer)
            section("Board") {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(ThemeID.allCases) { id in
                        ThemeSwatch(theme: .with(id), selected: settings.themeID == id, ink: theme) {
                            session.feedback.ui()
                            withAnimation(.easeInOut(duration: 0.35)) { settings.themeID = id }
                        }
                    }
                }
            }
            section("Sound") {
                row("Sound effects") {
                    Toggle("", isOn: $settings.soundEnabled).labelsHidden().tint(theme.accent)
                }
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill").font(.system(size: 11))
                    Slider(value: $settings.volume, in: 0...1, onEditingChanged: { editing in
                        if !editing { session.feedback.audio.play(.place, gain: 0.9) }
                    })
                    .tint(theme.accent)
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 11))
                }
                .foregroundStyle(theme.inkSecondary)
                .disabled(!settings.soundEnabled)
                .opacity(settings.soundEnabled ? 1 : 0.4)
            }
            section("On the board") {
                row("Coordinates") {
                    Toggle("", isOn: $settings.showCoordinates).labelsHidden().tint(theme.accent)
                }
                row("Legal move hints") {
                    Toggle("", isOn: $settings.showMoveHints).labelsHidden().tint(theme.accent)
                }
                if !settings.isAgainstComputer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Black's pieces")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.ink)
                    Picker("Black's pieces", selection: $settings.pieceFacing) {
                        Text("Face Black").tag(PieceFacing.eachPlayer)
                        Text("Face White").tag(PieceFacing.white)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                }
            }
            section("Game") { gameControls }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TABLE")
                    .font(Typeface.display(28))
                    .tracking(8)
                    .foregroundStyle(theme.ink)
                Text("Chess, together.")
                    .font(Typeface.italic(17))
                    .foregroundStyle(theme.inkSecondary)
            }
            Spacer()
            Button {
                session.feedback.ui()
                close()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.panelStroke).frame(height: 1)
        }
    }

    @ViewBuilder
    private var gameControls: some View {
        switch confirm {
        case nil:
            VStack(spacing: 10) {
                wideButton("New Game", prominent: true) { confirm = .newGame }
                HStack(spacing: 10) {
                    if !settings.isAgainstComputer {
                        wideButton("Agree to Draw", prominent: false) { confirm = .draw }
                            .disabled(session.isOver)
                    }
                    wideButton("Resign", prominent: false) { confirm = .resign }
                        .disabled(session.isOver)
                }
                .opacity(session.isOver ? 0.4 : 1)
            }
        case .newGame?:
            confirmation("Put the pieces back and start again?", action: "New Game") {
                session.newGame()
                close()
            }
        case .draw?:
            confirmation("Both players agree to a draw?", action: "Draw") {
                session.agreeDraw()
                close()
            }
        case .resign?:
            confirmation("Resign this game as \(player == .white ? "White" : "Black")?", action: "Resign") {
                session.resign(player)
                close()
            }
        }
    }

    private func confirmation(_ text: String, action: String, perform: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(theme.ink)
            HStack(spacing: 10) {
                wideButton("Cancel", prominent: false) { confirm = nil }
                wideButton(action, prominent: true, perform: perform)
            }
        }
        .transition(.opacity)
    }

    private func wideButton(_ title: String, prominent: Bool, perform: @escaping () -> Void) -> some View {
        Button {
            session.feedback.ui()
            withAnimation(.easeInOut(duration: 0.2)) { perform() }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(prominent ? (theme.isDark ? Color(hex: 0x1D1713) : .white) : theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(prominent ? theme.accent : theme.ink.opacity(0.07))
                )
        }
        .buttonStyle(PressScaleStyle())
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(theme.inkSecondary)
            content()
        }
    }

    private func row<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(title).font(.system(size: 15)).foregroundStyle(theme.ink)
            Spacer()
            trailing()
        }
    }
}

/// A small sample of a board's materials.
struct ThemeSwatch: View {
    let theme: BoardTheme
    let selected: Bool
    let ink: BoardTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Image(theme.rimImage).resizable().scaledToFill()
                    Image(theme.surfaceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 128, height: 128)       // shows a 2 x 2 corner of the board
                        .frame(width: 64, height: 64, alignment: .bottomLeading)
                        .clipped()
                        .overlay(Rectangle().strokeBorder(theme.inlay.opacity(0.8), lineWidth: 0.75).padding(-2))
                    HStack(spacing: -4) {
                        PieceGlyph(piece: Piece(.white, .knight)).frame(width: 34, height: 34)
                        PieceGlyph(piece: Piece(.black, .bishop)).frame(width: 34, height: 34)
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? ink.accent : .clear, lineWidth: 2)
                        .padding(-4)
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(ink.ink)
                    Text(theme.subtitle).font(.system(size: 11)).foregroundStyle(ink.inkSecondary).lineLimit(2)
                }
                .frame(width: 100, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
