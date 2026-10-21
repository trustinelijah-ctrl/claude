import SwiftUI
import AuthenticationServices
import ChessCore

/// The welcome: five short pages in the house style, each with a live scene built from the
/// real pieces and board, ending at the table with a choice to sign in or play as a guest,
/// and a look at TABLE Pro.
struct OnboardingView: View {
    let pro: ProStore
    let account: AccountStore
    let feedback: FeedbackCoordinator
    let finish: () -> Void

    @State private var page: Int
    @State private var signInNote: String?
    @State private var appeared = false

    static let pageCount = 5
    private let theme = BoardTheme.with(.salon)

    init(pro: ProStore, account: AccountStore, feedback: FeedbackCoordinator, finish: @escaping () -> Void) {
        self.pro = pro
        self.account = account
        self.feedback = feedback
        self.finish = finish
        let start = UserDefaults.standard.integer(forKey: "onboardingPage")
        _page = State(initialValue: min(max(start, 0), Self.pageCount - 1))
    }

    private struct Copy {
        let kicker: String
        let title: String
        let body: String
    }

    private let copy: [Copy] = [
        Copy(kicker: "Chess, together",
             title: "Play someone real again.",
             body: "Put the phone games down. TABLE turns your iPad into a real board between two people. Sit across from each other, look up, and play the person — not an algorithm."),
        Copy(kicker: "Made from scratch",
             title: "Every piece, made by us.",
             body: "All thirty-two pieces were modelled, lit and rendered from nothing: ivory and ebony, a thread of gold, standing under a warm lamp. Nothing stock. Nothing borrowed."),
        Copy(kicker: "Lift · Land · Feel",
             title: "You'll hear it land.",
             body: "Pick a piece up and it rises off the board and casts its shadow. Set it down and it lands with a recorded knock of wood on wood — and a tap you can feel."),
        Copy(kicker: "Nobody across from you?",
             title: "Then play TABLE.",
             body: "A quiet opponent that moves its pieces as if by an invisible hand. Casual for a gentle game, Club for a real one — and, with Pro, Master and Grandmaster when you want to be humbled."),
        Copy(kicker: "Welcome",
             title: "Pull up a chair.",
             body: "Sign in to keep your record with your Apple ID, or just start playing as a guest."),
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safe = proxy.safeAreaInsets
            let wide = size.width > size.height * 1.12
            ZStack {
                OnboardingBackdrop(theme: theme, page: page)

                TabView(selection: $page) {
                    ForEach(0..<Self.pageCount, id: \.self) { i in
                        pageView(i, size: size, wide: wide)
                            .padding(.top, safe.top + 64)
                            .padding(.bottom, safe.bottom + (i == Self.pageCount - 1 ? 24 : 120))
                            .padding(.horizontal, max(28, safe.leading + 20))
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 0) {
                    topBar.padding(.top, safe.top + 14)
                    Spacer()
                    if page < Self.pageCount - 1 {
                        bottomBar
                            .padding(.bottom, safe.bottom + 34)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.3), value: page)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { appeared = true } }
        .onChange(of: page) { feedback.ui() }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding")
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Text("TABLE")
                .font(Typeface.display(22))
                .tracking(9)
                .foregroundStyle(gold)
            Spacer()
            if page < Self.pageCount - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.45)) { page = Self.pageCount - 1 }
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.ink.opacity(0.6))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 22) {
            HStack(spacing: 8) {
                ForEach(0..<Self.pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? theme.accent : theme.ink.opacity(0.22))
                        .frame(width: i == page ? 26 : 7, height: 7)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
            Button {
                withAnimation(.easeInOut(duration: 0.45)) { page = min(page + 1, Self.pageCount - 1) }
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2A1D0A))
                    .frame(width: 260, height: 54)
                    .background(GoldCapsule())
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private var gold: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xF3DFA8), theme.accent, Color(hex: 0x9C7A3E)], startPoint: .top, endPoint: .bottom)
    }

    // MARK: Pages

    @ViewBuilder
    private func pageView(_ i: Int, size: CGSize, wide: Bool) -> some View {
        if i == Self.pageCount - 1 {
            finale(size: size, wide: wide)
        } else {
            let visual = wide ? min(size.height * 0.6, size.width * 0.44) : min(size.width * 0.74, size.height * 0.44)
            let layout = wide ? AnyLayout(HStackLayout(spacing: 56)) : AnyLayout(VStackLayout(spacing: 34))
            layout {
                scene(i, size: visual)
                    .frame(width: visual, height: visual)
                text(copy[i], centered: !wide)
                    .frame(maxWidth: wide ? 440 : 560, alignment: wide ? .leading : .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func scene(_ i: Int, size: CGFloat) -> some View {
        let active = page == i
        switch i {
        case 0: FaceToFaceScene(theme: theme, size: size, active: active, feedback: feedback)
        case 1: CraftScene(theme: theme, size: size, active: active)
        case 2: FeelScene(theme: theme, size: size, active: active, feedback: feedback)
        default: GhostScene(theme: theme, size: size, active: active)
        }
    }

    private func text(_ c: Copy, centered: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 14) {
            Text(c.kicker.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(3)
                .foregroundStyle(theme.accent)
            Text(c.title)
                .font(Typeface.display(52))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(centered ? .center : .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            Text(c.body)
                .font(Typeface.italic(23))
                .foregroundStyle(theme.ink.opacity(0.72))
                .multilineTextAlignment(centered ? .center : .leading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Finale

    private func finale(size: CGSize, wide: Bool) -> some View {
        let actions = VStack(spacing: 14) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                        account.signedIn(credential)
                        feedback.ui()
                        finish()
                    }
                case .failure(let error):
                    if (error as? ASAuthorizationError)?.code == .canceled { return }
                    // Without the Sign in with Apple capability (a free developer team, say)
                    // the request fails at once; say so plainly and offer the guest seat.
                    signInNote = "Sign in with Apple isn't available in this build. Play as a guest — your games stay on this iPad, and you can sign in later from Settings."
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(Capsule())

            Button {
                feedback.ui()
                account.continueAsGuest()
                finish()
            } label: {
                Text("Continue as Guest")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .overlay(Capsule().strokeBorder(theme.accent.opacity(0.55), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressScaleStyle())

            if let signInNote {
                Text(signInNote)
                    .font(Typeface.italic(17))
                    .foregroundStyle(theme.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 420)
        .animation(.easeInOut(duration: 0.3), value: signInNote)

        let head = VStack(spacing: 18) {
            WelcomeCrest(theme: theme, active: page == Self.pageCount - 1)
                .frame(height: min(size.height * 0.2, 210))
            text(copy[Self.pageCount - 1], centered: true)
                .frame(maxWidth: 520)
        }

        return ViewThatFits(in: .vertical) {
            Group {
                if wide {
                    HStack(alignment: .center, spacing: 48) {
                        VStack(spacing: 26) { head; actions }
                        ProCard(pro: pro, theme: theme, feedback: feedback)
                            .frame(maxWidth: 440)
                    }
                } else {
                    VStack(spacing: 26) {
                        head
                        actions
                        ProCard(pro: pro, theme: theme, feedback: feedback)
                            .frame(maxWidth: 520)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 26) {
                    head
                    actions
                    ProCard(pro: pro, theme: theme, feedback: feedback)
                        .frame(maxWidth: 520)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// The house surface behind the welcome, with the lamp drifting a little as the pages turn.
struct OnboardingBackdrop: View {
    let theme: BoardTheme
    let page: Int

    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size
            ZStack {
                Image(theme.fieldImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: s.width, height: s.height)
                    .clipped()
                Color.black.opacity(0.35)
                RadialGradient(colors: [Color(hex: 0xFFE2A8).opacity(0.2), .clear],
                               center: UnitPoint(x: 0.3 + 0.1 * Double(page), y: 0.34),
                               startRadius: 0, endRadius: max(s.width, s.height) * 0.6)
                    .animation(.easeInOut(duration: 0.9), value: page)
                RadialGradient(colors: [.clear, .black.opacity(0.65)], center: .center,
                               startRadius: min(s.width, s.height) * 0.3, endRadius: max(s.width, s.height) * 0.8)
                Image("Grain")
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(theme.grain * 1.6)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(theme.inlay.opacity(0.5), lineWidth: 1)
                    .padding(9)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.inlay.opacity(0.25), lineWidth: 0.6)
                    .padding(14)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A gold-leaf capsule for the primary action.
struct GoldCapsule: View {
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(hex: 0xF7E6B4), Color(hex: 0xD4AF66), Color(hex: 0xA27A3A)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(Capsule().strokeBorder(Color(hex: 0xFFF3D0).opacity(0.8), lineWidth: 0.75))
            .shadow(color: Color(hex: 0xD4AF66).opacity(0.35), radius: 14, y: 4)
    }
}
