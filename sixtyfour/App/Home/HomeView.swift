import SwiftUI
import ChessCore

/// Where 64 opens. Set like the first page of a fine menu: the mark, a line of italic, and
/// a few words in serif on dark wood, divided by hairlines of gold. No boxes, no icons.
struct HomeView: View {
    let session: GameSession
    @Bindable var settings: SettingsStore
    let pro: ProStore
    let feedback: FeedbackCoordinator
    let resume: () -> Void
    let playFriend: () -> Void
    let playComputer: () -> Void
    let learn: () -> Void
    var freePlay: () -> Void = {}
    let games: () -> Void
    let options: () -> Void
    let upgrade: () -> Void
    var replayWelcome: () -> Void = {}

    @State private var choosingLevel = false
    @State private var shown = false

    private var inProgress: Bool { !session.game.history.isEmpty && !session.isOver }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let wide = size.width > size.height * 1.1
            ZStack {
                backdrop(size)
                frame(size: size, safe: proxy.safeAreaInsets)
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
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = true } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home")
    }

    // MARK: Backdrop

    /// The table in lamplight: the house walnut, dark at the edges, a warm pool in the middle.
    private func backdrop(_ size: CGSize) -> some View {
        ZStack {
            Image("WalnutField")
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
            Color(hex: 0x1A0E07).opacity(0.62)
            RadialGradient(colors: [Color(hex: 0xFFD9A0).opacity(0.16), .clear],
                           center: UnitPoint(x: 0.5, y: 0.36), startRadius: 0,
                           endRadius: max(size.width, size.height) * 0.55)
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center,
                           startRadius: min(size.width, size.height) * 0.35,
                           endRadius: max(size.width, size.height) * 0.75)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: Content

    /// Type scales with the screen, so an iPad's menu reads as large as a printed card.
    private func scale(_ size: CGSize) -> CGFloat {
        min(1.45, max(1, min(size.width, size.height) / 430))
    }

    private func content(size: CGSize, wide: Bool, safe: EdgeInsets) -> some View {
        let k = scale(size)
        return Group {
            if wide {
                HStack(spacing: 64 * k) {
                    masthead(size: size, wide: true)
                    VStack(spacing: 28) {
                        menu(k)
                        footer
                    }
                    .frame(maxWidth: 420 * k)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    Spacer(minLength: 12)
                    masthead(size: size, wide: false)
                    Spacer(minLength: 20)
                    menu(k)
                        .frame(maxWidth: 460 * k)
                    Spacer(minLength: 20)
                    footer
                    Spacer(minLength: 8)
                }
            }
        }
        .padding(.horizontal, 44)
        .padding(.top, safe.top + 36)
        .padding(.bottom, safe.bottom + 32)
        .frame(maxWidth: .infinity, minHeight: size.height)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 12)
    }

    /// A fine double rule of gold around the whole screen, as on a printed menu card.
    private func frame(size: CGSize, safe: EdgeInsets) -> some View {
        let inset = max(14, min(safe.top, 24))
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Brand.gold.opacity(0.42), lineWidth: 0.75)
                .padding(inset)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Brand.gold.opacity(0.22), lineWidth: 0.5)
                .padding(inset + 5)
        }
        .padding(.top, max(0, safe.top - inset))
        .padding(.bottom, max(0, safe.bottom - inset))
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A small ornament under the tagline: a gold lozenge between two fading rules.
    private var ornament: some View {
        HStack(spacing: 10) {
            LinearGradient(colors: [.clear, Brand.gold.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 54, height: 0.75)
            Rectangle().fill(Brand.gold.opacity(0.8)).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            LinearGradient(colors: [Brand.gold.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 54, height: 0.75)
        }
        .accessibilityHidden(true)
    }

    private func menu(_ k: CGFloat) -> some View {
        VStack(spacing: 0) {
            if inProgress {
                item("Continue", k: k, note: continueNote, gold: true, id: "home-continue", action: resume)
                rule
            }
            item("Play a friend", k: k, note: "face to face on this \(Brand.device)", id: "home-friend", action: playFriend)
            rule
            item("Play 64", k: k, note: "against the computer · \(settings.botLevel.title.lowercased())", id: "home-computer") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { choosingLevel.toggle() }
            }
            if choosingLevel {
                levelPicker
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            rule
            item("Learn", k: k, note: pro.isPro ? "checkmate puzzles" : "checkmate puzzles · \(PuzzleView.freeCount) free",
                 id: "home-learn", action: learn)
            rule
            item("Free play", k: k, note: "no rules, just the pieces", id: "home-free-play", action: freePlay)
        }
    }

    private var continueNote: String {
        let moves = (session.game.history.count + 1) / 2
        let who = settings.isAgainstComputer ? "against 64" : "face to face"
        return "\(who) · move \(moves)"
    }

    /// A hairline of gold, fading out at both ends.
    private var rule: some View {
        LinearGradient(colors: [.clear, Brand.gold.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(width: 140, height: 0.75)
            .accessibilityHidden(true)
    }

    private func item(_ title: String, k menuScale: CGFloat, note: String, gold: Bool = false, id: String,
                      action: @escaping () -> Void) -> some View {
        Button {
            feedback.ui()
            action()
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(Typeface.display(34 * menuScale, bold: false))
                    .foregroundStyle(gold ? Brand.gold : Brand.cream)
                Text(note.uppercased())
                    .font(.system(size: 11 * min(menuScale, 1.25), weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(Brand.cream.opacity(0.5))
            }
            .frame(maxWidth: .infinity, minHeight: 86 * menuScale)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuPressStyle())
        .accessibilityIdentifier(id)
    }

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 28) {
                quiet("Your games", id: "home-games", action: games)
                Circle().fill(Brand.gold.opacity(0.6)).frame(width: 3, height: 3)
                quiet("Options", id: "home-options", action: options)
            }
            if !pro.isPro {
                Button {
                    feedback.ui()
                    upgrade()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill").font(.system(size: 11))
                        Text(pro.trialAvailable ? "64 PRO · TRY A WEEK FREE" : "64 PRO")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(2)
                    }
                    .foregroundStyle(Brand.gold)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 40)
                    .overlay(Capsule().strokeBorder(Brand.gold.opacity(0.5), lineWidth: 0.75))
                    .contentShape(Capsule())
                }
                .buttonStyle(MenuPressStyle())
                .accessibilityIdentifier("home-upgrade")
            }
        }
    }

    private func quiet(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            feedback.ui()
            action()
        } label: {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Brand.cream.opacity(0.7))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(MenuPressStyle())
        .accessibilityIdentifier(id)
    }

    /// Strength and side, then begin; in the same quiet type.
    private var levelPicker: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(BotLevel.allCases) { level in
                    let locked = level.isPro && !pro.isPro
                    let on = settings.botLevel == level
                    Button {
                        feedback.ui()
                        if locked { upgrade() } else { withAnimation(.easeInOut(duration: 0.2)) { settings.botLevel = level } }
                    } label: {
                        VStack(spacing: 4) {
                            Text(level.title)
                                .font(Typeface.display(16))
                                .foregroundStyle(on ? Brand.gold : Brand.cream.opacity(locked ? 0.4 : 0.8))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Rectangle().fill(on ? Brand.gold : .clear).frame(width: 18, height: 1)
                            if locked {
                                Text("PRO").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(Brand.gold.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MenuPressStyle())
                }
            }
            HStack(spacing: 22) {
                ForEach([PieceColor.white, .black], id: \.self) { c in
                    let on = settings.humanColor == c
                    Button {
                        feedback.ui()
                        withAnimation(.easeInOut(duration: 0.2)) { settings.humanColor = c }
                    } label: {
                        Text(c == .white ? "as White" : "as Black")
                            .font(Typeface.voice(17))
                            .foregroundStyle(on ? Brand.gold : Brand.cream.opacity(0.6))
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(MenuPressStyle())
                }
                Button {
                    feedback.ui()
                    playComputer()
                } label: {
                    Text("BEGIN")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Brand.brown)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 38)
                        .background(GoldCapsule())
                }
                .buttonStyle(MenuPressStyle())
                .accessibilityIdentifier("home-start")
            }
        }
        .padding(.horizontal, 8)
    }
}

/// A press that feels like touching paper: the words dim a little and settle.
struct MenuPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
