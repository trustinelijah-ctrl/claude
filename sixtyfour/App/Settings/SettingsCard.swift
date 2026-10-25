import SwiftUI
import ChessCore

/// Settings and game controls, opened from either player's panel and turned to face them.
struct SettingsCard: View {
    @Bindable var settings: SettingsStore
    let session: GameSession
    let player: PieceColor
    let pro: ProStore
    let account: AccountStore
    var showPaywall: () -> Void = {}
    var showLibrary: () -> Void = {}
    var showWelcome: () -> Void = {}
    /// Back to the home screen; nil when settings were opened from there.
    var goHome: (() -> Void)? = nil
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
            // The game itself first: home, new game, draw and resign without scrolling.
            section("Game") { gameControls }
            section("Opponent") {
                Picker("Opponent", selection: $settings.opponent) {
                    Text("A friend").tag(Opponent.friend)
                    Text("64").tag(Opponent.computer)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if settings.isAgainstComputer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Strength").font(.system(size: 15)).foregroundStyle(theme.ink)
                        Picker("Strength", selection: strength) {
                            ForEach(BotLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        if !pro.isPro {
                            Text("Master and Grandmaster come with 64 Pro.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.inkSecondary)
                        }
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
            section("Clock") {
                Picker("Clock", selection: $settings.timeControl) {
                    ForEach(TimeControl.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("time-control")
                Text(settings.timeControl == .off ? "No clock. Take as long as you like."
                                                  : "Each side's clock starts after White's first move. Changing this resets both clocks.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.inkSecondary)
            }
            section("Board") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3),
                          alignment: .leading, spacing: 16) {
                    ForEach(ThemeID.allCases) { id in
                        ThemeSwatch(theme: .with(id), selected: settings.themeID == id, ink: theme,
                                    locked: id.isPro && !pro.isPro) {
                            session.feedback.ui()
                            if id.isPro && !pro.isPro { showPaywall(); return }
                            withAnimation(.easeInOut(duration: 0.35)) { settings.themeID = id }
                        }
                    }
                }
            }
            section("Pieces") {
                HStack(spacing: 10) {
                    ForEach(PieceSet.allCases) { set in
                        pieceSetButton(set)
                    }
                }
            }
            section("Your games") {
                Button {
                    session.feedback.ui()
                    showLibrary()
                } label: {
                    HStack {
                        Image(systemName: "film.stack").foregroundStyle(theme.accent)
                        Text(session.library.games.isEmpty ? "No finished games yet" : "Replay your games")
                            .font(.system(size: 15))
                            .foregroundStyle(theme.ink)
                        Spacer()
                        Text("\(session.library.games.count)")
                            .font(.system(size: 15))
                            .foregroundStyle(theme.inkSecondary)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.inkSecondary)
                    }
                    .frame(minHeight: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("open-library")
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Ambience").font(.system(size: 15)).foregroundStyle(theme.ink)
                        if !pro.isPro {
                            Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(theme.inkSecondary)
                        }
                    }
                    Picker("Ambience", selection: ambience) {
                        ForEach(Ambience.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("ambience")
                    Text(pro.isPro ? "Rain at the window, or a fire in the grate, under the game."
                                   : "Rain and a fireplace come with 64 Pro.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.inkSecondary)
                }
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
            section("Account") { accountRows }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    /// Choosing a Pro opponent without Pro opens the offer instead.
    private var strength: Binding<BotLevel> {
        Binding(get: { settings.botLevel }, set: { level in
            if level.isPro && !pro.isPro { showPaywall() } else { settings.botLevel = level }
        })
    }

    private var ambience: Binding<Ambience> {
        Binding(get: { settings.ambience }, set: { choice in
            if choice != .off && !pro.isPro { showPaywall() } else { settings.ambience = choice }
        })
    }

    private func pieceSetButton(_ set: PieceSet) -> some View {
        let selected = settings.pieceSet == set
        let locked = set.isPro && !pro.isPro
        return Button {
            session.feedback.ui()
            if locked { showPaywall(); return }
            withAnimation(.easeInOut(duration: 0.3)) { settings.pieceSet = set }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: -10) {
                    StandingPiece(piece: Piece(.white, .queen), size: 46, shadow: 0.3)
                    StandingPiece(piece: Piece(.black, .knight), size: 46, shadow: 0.3)
                }
                .environment(\.pieceSet, set)
                HStack(spacing: 4) {
                    Text(set.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ink)
                    if locked { Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(theme.accent) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.ink.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? theme.accent : .clear, lineWidth: 2))
            .opacity(locked ? 0.75 : 1)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(set.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var accountRows: some View {
        row(account.kind == .apple ? "Signed in\(account.name.map { " as \($0)" } ?? " with Apple")" : "Playing as a guest") {
            if account.kind == .apple {
                Button("Sign out") { account.signOut() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
        }
        row(pro.isPro ? "64 Pro is active" : "64 Pro") {
            if !pro.isPro {
                Button("See plans") {
                    session.feedback.ui()
                    showPaywall()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.accent)
            } else if pro.hasTestUnlock {
                Button("End test") { pro.endTestUnlock() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.accent)
            } else {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(theme.accent)
            }
        }
        Button {
            session.feedback.ui()
            showWelcome()
        } label: {
            Text(account.kind == .apple ? "Show the welcome again" : "Sign in or show the welcome again")
                .font(.system(size: 14))
                .foregroundStyle(theme.inkSecondary)
                .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Image("Logo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(height: 30)
                .foregroundStyle(theme.ink)
                .accessibilityLabel("64")
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
                HStack(spacing: 10) {
                    if let goHome {
                        wideButton("Home", prominent: false, perform: goHome)
                            .accessibilityIdentifier("settings-home")
                    }
                    wideButton("New Game", prominent: true) { confirm = .newGame }
                }
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
    var locked = false
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
                .overlay(alignment: .topTrailing) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: 0x2A1D0A))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color(hex: 0xD4AF66)))
                            .offset(x: 6, y: -6)
                    }
                }
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
