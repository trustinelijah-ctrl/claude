import SwiftUI
import StoreKit
import ChessCore

/// Options, opened from either player's panel and turned to face them. Four tabs keep each
/// page short: the game in hand, how the board looks, sound, and everything else.
struct SettingsCard: View {
    @Bindable var settings: SettingsStore
    let session: GameSession
    let player: PieceColor
    let pro: ProStore
    let account: AccountStore
    var showPaywall: () -> Void = {}
    var showLibrary: () -> Void = {}
    var showWelcome: () -> Void = {}
    /// Back to the home screen; nil when options were opened from there.
    var goHome: (() -> Void)? = nil
    let close: () -> Void

    enum Tab: String, CaseIterable, Identifiable {
        case game, board, sound, more
        var id: String { rawValue }
        var title: String {
            switch self {
            case .game: return "Game"
            case .board: return "Board"
            case .sound: return "Sound"
            case .more: return "More"
            }
        }
        var symbol: String {
            switch self {
            case .game: return "flag.checkered"
            case .board: return "square.grid.3x3.fill"
            case .sound: return "speaker.wave.2.fill"
            case .more: return "person.crop.circle"
            }
        }
    }

    private enum Confirm { case newGame, resign, draw }
    @State private var confirm: Confirm?
    @State private var managing = false
    @State private var tab: Tab = Tab(rawValue: UserDefaults.standard.string(forKey: "optionsTab") ?? "") ?? .game
    @Namespace private var tabMarker

    private var theme: BoardTheme { settings.theme }
    private var surface: Color { theme.isDark ? Color(hex: 0x1D1713) : Color(hex: 0xF9F6F0) }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    switch tab {
                    case .game: gamePage
                    case .board: boardPage
                    case .sound: soundPage
                    case .more: morePage
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(tab)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: 600, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(surface)
                .shadow(color: .black.opacity(theme.isDark ? 0.55 : 0.22), radius: 40, y: 18)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(theme.panelStroke, lineWidth: 1)
        )
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .animation(.easeInOut(duration: 0.2), value: tab)
        .manageSubscriptionsSheet(isPresented: $managing)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings")
    }

    // MARK: Frame

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("Logo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(height: 24)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text("Options")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(theme.ink)
            Spacer()
            Button {
                session.feedback.ui()
                close()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.isDark ? Color(hex: 0x1D1713) : .white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 34)
                    .background(Capsule().fill(theme.accent))
                    .frame(minHeight: 44)
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases) { t in
                Button {
                    session.feedback.ui()
                    confirm = nil
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { tab = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.symbol).font(.system(size: 16, weight: .semibold))
                        Text(t.title).font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(tab == t ? theme.accent : theme.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background {
                        if tab == t {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.accent.opacity(0.13))
                                .matchedGeometryEffect(id: "tab", in: tabMarker)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab-\(t.rawValue)")
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.ink.opacity(0.05)))
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    // MARK: Pages

    @ViewBuilder
    private var gamePage: some View {
        group("This game") { gameControls.padding(14) }
        group("Opponent") {
            VStack(alignment: .leading, spacing: 0) {
                Picker("Opponent", selection: $settings.opponent) {
                    Text("A friend").tag(Opponent.friend)
                    Text("64").tag(Opponent.computer)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(14)
                if settings.isAgainstComputer {
                    divider
                    row("Strength", detail: pro.isPro ? nil : "Master and Grandmaster come with 64 Pro") {
                        Picker("Strength", selection: strength) {
                            ForEach(BotLevel.allCases) { level in
                                Text(level.isPro && !pro.isPro ? "\(level.title) (Pro)" : level.title).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(theme.accent)
                    }
                    divider
                    row("You play") {
                        Picker("You play", selection: $settings.humanColor) {
                            Text("White").tag(PieceColor.white)
                            Text("Black").tag(PieceColor.black)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 180)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: settings.isAgainstComputer)
        group("Clock", footer: settings.timeControl == .off ? "No clock. Take as long as you like."
                                : "Each clock starts after White's first move. Changing this resets both.") {
            row("Time control") {
                Picker("Clock", selection: $settings.timeControl) {
                    ForEach(TimeControl.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(theme.accent)
                .accessibilityIdentifier("time-control")
            }
        }
    }

    @ViewBuilder
    private var boardPage: some View {
        group("Board") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12, alignment: .top)],
                      alignment: .leading, spacing: 18) {
                ForEach(ThemeID.allCases) { id in
                    ThemeSwatch(theme: .with(id), selected: settings.themeID == id, ink: theme,
                                locked: id.isPro && !pro.isPro) {
                        session.feedback.ui()
                        if id.isPro && !pro.isPro { showPaywall(); return }
                        withAnimation(.easeInOut(duration: 0.35)) { settings.themeID = id }
                    }
                }
            }
            .padding(16)
        }
        group("Pieces") {
            HStack(spacing: 10) {
                ForEach(PieceSet.allCases) { set in pieceSetButton(set) }
            }
            .padding(12)
        }
        group("On the board") {
            VStack(spacing: 0) {
                toggleRow("Coordinates", isOn: $settings.showCoordinates)
                divider
                toggleRow("Legal move hints", isOn: $settings.showMoveHints)
                if !settings.isAgainstComputer {
                    divider
                    row("Black's pieces") {
                        Picker("Black's pieces", selection: $settings.pieceFacing) {
                            Text("Face Black").tag(PieceFacing.eachPlayer)
                            Text("Face White").tag(PieceFacing.white)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var soundPage: some View {
        group("Sound effects") {
            VStack(spacing: 0) {
                toggleRow("Pieces, clock and board", isOn: $settings.soundEnabled)
                divider
                volumeRow(value: $settings.volume, enabled: settings.soundEnabled) {
                    session.feedback.audio.play(.placeHeavy, gain: 0.9)
                }
                divider
                row("Play in silent mode", detail: "Hear the pieces even with the silent switch on.") {
                    Toggle("", isOn: $settings.playInSilentMode).labelsHidden().tint(theme.accent)
                }
                if session.feedback.haptics.hasHardware {
                    divider
                    toggleRow("Vibration", isOn: $settings.hapticsEnabled)
                }
            }
        }
        group("Ambience", badge: pro.isPro ? nil : "PRO",
              footer: "Plays softly under the game, with its own volume.") {
            VStack(spacing: 0) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                    ForEach(Ambience.available) { a in ambienceTile(a) }
                }
                .padding(12)
                .accessibilityIdentifier("ambience")
                divider
                volumeRow(value: $settings.ambienceVolume, enabled: settings.ambience != .off, preview: nil)
            }
        }
    }

    @ViewBuilder
    private var morePage: some View {
        if ProStore.isTestBuild {
            group("Developer", footer: "Only in development builds; the App Store version doesn't have this.") {
                VStack(spacing: 0) {
                    navRow("Show the welcome", symbol: "sparkles", value: nil, id: "dev-welcome") {
                        // Also offer Pro again after it, as a first launch would.
                        UserDefaults.standard.removeObject(forKey: "paywall.afterWelcome")
                        showWelcome()
                    }
                    divider
                    navRow("Show the Pro welcome", symbol: "crown", value: nil, id: "dev-pro-welcome") {
                        close()
                        pro.welcome = .subscribed(trialEnds: Date().addingTimeInterval(7 * 86_400))
                    }
                    if pro.hasTestUnlock {
                        divider
                        navRow("End the Pro test", symbol: "arrow.uturn.backward", value: nil, id: "dev-end-pro") {
                            pro.endTestUnlock()
                        }
                    }
                }
            }
        }
        group("Your games") {
            navRow(session.library.games.isEmpty ? "No finished games yet" : "Replay your games",
                   symbol: "film.stack", value: "\(session.library.games.count)", id: "open-library") {
                showLibrary()
            }
        }
        group("64 Pro") {
            VStack(spacing: 0) {
                row(pro.isPro ? "Active" : "Not subscribed", detail: pro.isPro ? "Thank you for supporting 64." : "Boards, sets, review, hints, ambience and more") {
                    if !pro.isPro {
                        capsuleButton("See plans") { showPaywall() }
                    } else if pro.hasTestUnlock {
                        capsuleButton("End test") { pro.endTestUnlock() }
                    } else {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 20)).foregroundStyle(theme.accent)
                    }
                }
                if pro.activePlan?.isSubscription == true {
                    divider
                    navRow("Manage subscription", symbol: "creditcard", value: nil, id: "manage-subscription") {
                        managing = true
                    }
                }
                if !pro.isPro {
                    divider
                    navRow("Restore purchases", symbol: "arrow.clockwise", value: nil, id: "restore") {
                        Task { await pro.restore() }
                    }
                }
                if let message = pro.message {
                    divider
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }
        }
        group("Help") {
            VStack(spacing: 0) {
                navRow("Show the welcome again", symbol: "sparkles", value: nil, id: "show-welcome") {
                    showWelcome()
                }
                divider
                Link(destination: ProCard.privacyURL) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised").font(.system(size: 15)).foregroundStyle(theme.accent).frame(width: 22)
                        Text("Privacy Policy").font(.system(size: 15)).foregroundStyle(theme.ink)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.inkSecondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                }
                divider
                Link(destination: ProCard.termsURL) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text").font(.system(size: 15)).foregroundStyle(theme.accent).frame(width: 22)
                        Text("Terms of Use").font(.system(size: 15)).foregroundStyle(theme.ink)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.inkSecondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                }
            }
        }
        Text("64 · version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
            .font(.system(size: 12))
            .foregroundStyle(theme.inkSecondary.opacity(0.7))
            .frame(maxWidth: .infinity)
    }

    // MARK: Game controls

    @ViewBuilder
    private var gameControls: some View {
        switch confirm {
        case nil:
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                if let goHome {
                    actionTile("Home", symbol: "house.fill", perform: goHome)
                        .accessibilityIdentifier("settings-home")
                }
                actionTile("New game", symbol: "arrow.counterclockwise") { confirm = .newGame }
                if !settings.isAgainstComputer {
                    actionTile("Agree to draw", symbol: "equal.circle.fill", enabled: !session.isOver) { confirm = .draw }
                }
                actionTile("Resign", symbol: "flag.fill", tint: theme.check, enabled: !session.isOver) { confirm = .resign }
            }
        case .newGame?:
            confirmation("Put the pieces back and start again?", action: "New game") {
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

    private func actionTile(_ title: String, symbol: String, tint: Color? = nil, enabled: Bool = true,
                            perform: @escaping () -> Void) -> some View {
        Button {
            session.feedback.ui()
            withAnimation(.easeInOut(duration: 0.2)) { perform() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint ?? theme.accent)
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.ink.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(theme.ink.opacity(0.06), lineWidth: 0.75))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func confirmation(_ text: String, action: String, perform: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.system(size: 15, weight: .medium))
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

    // MARK: Pieces of a page

    /// Choosing a Pro opponent without Pro opens the offer instead.
    private var strength: Binding<BotLevel> {
        Binding(get: { settings.botLevel }, set: { level in
            if level.isPro && !pro.isPro { showPaywall() } else { settings.botLevel = level }
        })
    }

    private func ambienceTile(_ a: Ambience) -> some View {
        let selected = settings.ambience == a
        let locked = a != .off && !pro.isPro
        return Button {
            session.feedback.ui()
            if locked { showPaywall(); return }
            withAnimation(.easeInOut(duration: 0.2)) { settings.ambience = a }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: a.symbol)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selected ? theme.accent : theme.ink.opacity(0.75))
                    .frame(height: 26)
                HStack(spacing: 3) {
                    Text(a.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ink)
                    if locked { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(theme.accent) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? theme.accent.opacity(0.14) : theme.ink.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? theme.accent : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(a.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
                        .lineLimit(1).minimumScaleFactor(0.8)
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

    /// A titled, rounded group of rows, like a page of a well-kept notebook.
    private func group<Content: View>(_ title: String, badge: String? = nil, footer: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(theme.inkSecondary)
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Brand.brown)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.accent))
                }
            }
            .padding(.leading, 4)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.ink.opacity(0.045)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(theme.ink.opacity(0.07), lineWidth: 0.75))
            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(theme.ink.opacity(0.08)).frame(height: 0.75).padding(.leading, 14)
    }

    private func row<Trailing: View>(_ title: String, detail: String? = nil,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15)).foregroundStyle(theme.ink)
                if let detail {
                    Text(detail).font(.system(size: 12)).foregroundStyle(theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        row(title) { Toggle("", isOn: isOn).labelsHidden().tint(theme.accent) }
    }

    private func volumeRow(value: Binding<Double>, enabled: Bool, preview: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill").font(.system(size: 11))
            Slider(value: value, in: 0...1, onEditingChanged: { editing in
                if !editing { preview?() }
            })
            .tint(theme.accent)
            Image(systemName: "speaker.wave.3.fill").font(.system(size: 11))
        }
        .foregroundStyle(theme.inkSecondary)
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func navRow(_ title: String, symbol: String, value: String?, id: String,
                        action: @escaping () -> Void) -> some View {
        Button {
            session.feedback.ui()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(theme.accent).frame(width: 22)
                Text(title).font(.system(size: 15)).foregroundStyle(theme.ink)
                Spacer()
                if let value { Text(value).font(.system(size: 15)).foregroundStyle(theme.inkSecondary) }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.inkSecondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func capsuleButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            session.feedback.ui()
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .overlay(Capsule().strokeBorder(theme.accent.opacity(0.6), lineWidth: 1))
                .frame(minHeight: 44)
        }
        .buttonStyle(PressScaleStyle())
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
