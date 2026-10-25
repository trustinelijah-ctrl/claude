import SwiftUI
import ChessCore

/// Where 64 opens: continue the game on the board, start one against a friend or the
/// computer, practise with puzzles, or look back at past games.
struct HomeView: View {
    let session: GameSession
    @Bindable var settings: SettingsStore
    let pro: ProStore
    let feedback: FeedbackCoordinator
    let resume: () -> Void
    let playFriend: () -> Void
    let playComputer: () -> Void
    let learn: () -> Void
    let games: () -> Void
    let options: () -> Void
    let upgrade: () -> Void
    var replayWelcome: () -> Void = {}

    @State private var choosingLevel = false
    private let theme = BoardTheme.with(.house)

    private var inProgress: Bool { !session.game.history.isEmpty && !session.isOver }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let wide = size.width > size.height * 1.1
            ZStack {
                OnboardingBackdrop(theme: theme, page: 0)
                // A short screen (a small iPhone with the levels open) scrolls instead of clipping.
                ViewThatFits(in: .vertical) {
                    content(size: size, wide: wide, safe: proxy.safeAreaInsets)
                    ScrollView(.vertical, showsIndicators: false) {
                        content(size: size, wide: wide, safe: proxy.safeAreaInsets)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home")
    }

    private func content(size: CGSize, wide: Bool, safe: EdgeInsets) -> some View {
        let layout = wide ? AnyLayout(HStackLayout(spacing: 64)) : AnyLayout(VStackLayout(spacing: size.width < 500 ? 24 : 36))
        return layout {
            VStack(spacing: 14) {
                Image("Logo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Brand.cream)
                    .frame(height: wide ? min(size.height * 0.34, 260) : min(size.height * 0.2, 220))
                    .accessibilityLabel("64")
                    // Development builds: hold the logo to see the welcome again.
                    .onLongPressGesture(minimumDuration: 0.8) {
                        guard ProStore.isTestBuild else { return }
                        feedback.ui()
                        replayWelcome()
                    }
                Text("Chess, across the table.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Brand.cream.opacity(0.65))
            }
            menu
                .frame(maxWidth: 440)
        }
        .padding(.horizontal, size.width < 500 ? 20 : 32)
        .padding(.top, safe.top + 20)
        .padding(.bottom, safe.bottom + 20)
        .frame(maxWidth: .infinity)
    }

    private var menu: some View {
        VStack(spacing: 12) {
            if inProgress {
                entry("Continue game", detail: continueDetail, symbol: "play.fill", primary: true, id: "home-continue") {
                    resume()
                }
            }
            entry("Play a friend", detail: "Face to face on this \(Brand.device)", symbol: "person.2.fill",
                  primary: !inProgress, id: "home-friend") {
                playFriend()
            }
            entry("Play 64", detail: "Against the computer · \(settings.botLevel.title)", symbol: "cpu",
                  primary: false, id: "home-computer") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { choosingLevel.toggle() }
            }
            if choosingLevel {
                levelPicker
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            entry("Learn", detail: "Checkmate puzzles, from one move to three", symbol: "graduationcap.fill",
                  primary: false, badge: pro.isPro ? nil : "\(PuzzleView.freeCount) FREE", id: "home-learn") {
                learn()
            }
            HStack(spacing: 12) {
                small("Your games", symbol: "tray.full", id: "home-games", action: games)
                small("Options", symbol: "gearshape", id: "home-options", action: options)
            }
            if !pro.isPro {
                Button {
                    feedback.ui()
                    upgrade()
                } label: {
                    Text(pro.trialAvailable ? "Try 64 Pro free for a week" : "Upgrade to 64 Pro")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.brown)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(GoldCapsule())
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, 6)
                .accessibilityIdentifier("home-upgrade")
            }
        }
    }

    private var continueDetail: String {
        let moves = (session.game.history.count + 1) / 2
        let who = settings.isAgainstComputer ? "Against 64" : "Face to face"
        return "\(who) · move \(moves)"
    }

    /// Strength and side, then start.
    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Five levels in a row; a phone takes them in rows of three.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(BotLevel.allCases) { levelButton($0) }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(BotLevel.allCases) { levelButton($0) }
                }
            }
            HStack(spacing: 8) {
                Text("You play")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Brand.cream.opacity(0.6))
                Picker("You play", selection: $settings.humanColor) {
                    Text("White").tag(PieceColor.white)
                    Text("Black").tag(PieceColor.black)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Button {
                    feedback.ui()
                    playComputer()
                } label: {
                    Text("Start")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Brand.brown)
                        .padding(.horizontal, 18)
                        .frame(height: 34)
                        .background(Capsule().fill(Brand.cream))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("home-start")
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.18)))
    }

    private func levelButton(_ level: BotLevel) -> some View {
        let locked = level.isPro && !pro.isPro
        return Button {
            feedback.ui()
            if locked { upgrade() } else { settings.botLevel = level }
        } label: {
            HStack(spacing: 4) {
                Text(level.title)
                if locked { Image(systemName: "lock.fill").font(.system(size: 9)) }
            }
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(settings.botLevel == level ? Brand.brown : Brand.cream.opacity(locked ? 0.5 : 0.85))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(settings.botLevel == level ? Brand.cream : Color.black.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }

    private func entry(_ title: String, detail: String, symbol: String, primary: Bool, badge: String? = nil,
                       id: String, action: @escaping () -> Void) -> some View {
        Button {
            feedback.ui()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primary ? Brand.brown : theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(primary ? Brand.brown : Brand.cream)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Brand.brown)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(theme.accent))
                        }
                    }
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(primary ? Brand.brown.opacity(0.7) : Brand.cream.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primary ? Brand.brown.opacity(0.5) : Brand.cream.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 68)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(primary ? Brand.cream : Color.black.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.accent.opacity(primary ? 0.9 : 0.4), lineWidth: primary ? 1 : 0.75))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier(id)
    }

    private func small(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            feedback.ui()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Brand.cream.opacity(0.9))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.18)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.3), lineWidth: 0.75))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier(id)
    }
}
