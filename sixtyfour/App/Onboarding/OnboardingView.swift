import SwiftUI
import AuthenticationServices
import ChessCore

/// The welcome: two short pages with live scenes built from the real board and pieces,
/// then a page to sign in or play as a guest, with 64 Pro offered once, plainly.
struct OnboardingView: View {
    let pro: ProStore
    let account: AccountStore
    let feedback: FeedbackCoordinator
    var showPlans: () -> Void = {}
    let finish: () -> Void

    @State private var page: Int
    @State private var signInNote: String?
    @State private var appeared = false

    static let pageCount = 3
    private let theme = BoardTheme.with(.house)

    init(pro: ProStore, account: AccountStore, feedback: FeedbackCoordinator,
         showPlans: @escaping () -> Void = {}, finish: @escaping () -> Void) {
        self.pro = pro
        self.account = account
        self.feedback = feedback
        self.showPlans = showPlans
        self.finish = finish
        let start = UserDefaults.standard.integer(forKey: "onboardingPage")
        _page = State(initialValue: min(max(start, 0), Self.pageCount - 1))
    }

    private struct Copy {
        let title: String
        let body: String
    }

    private let copy: [Copy] = [
        Copy(title: "Chess, across the table.",
             body: "Set the \(Brand.device) between you and play the person in front of you."),
        Copy(title: "Pieces you can feel.",
             body: "Every piece is modeled and lit by hand. Pick one up, set it down, and hear the wood."),
        Copy(title: "Welcome to 64.",
             body: "Sign in with Apple or play as a guest. Your games stay on this \(Brand.device)."),
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
                            .padding(.top, safe.top + 70)
                            .padding(.bottom, safe.bottom + (i == Self.pageCount - 1 ? 28 : 130))
                            .padding(.horizontal, max(32, safe.leading + 24))
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 0) {
                    topBar.padding(.top, safe.top + 16)
                    Spacer()
                    if page < Self.pageCount - 1 {
                        bottomBar
                            .padding(.bottom, safe.bottom + 36)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.3), value: page)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
        .onChange(of: page) { feedback.ui() }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding")
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Image("Logo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(height: 30)
                .foregroundStyle(Brand.cream)
                .accessibilityLabel("64")
            Spacer()
            if page < Self.pageCount - 1 {
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.4)) { page = Self.pageCount - 1 }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Brand.cream.opacity(0.65))
                .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 22) {
            HStack(spacing: 8) {
                ForEach(0..<Self.pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? theme.accent : Brand.cream.opacity(0.25))
                        .frame(width: i == page ? 22 : 7, height: 7)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
            Button {
                withAnimation(.easeInOut(duration: 0.4)) { page = min(page + 1, Self.pageCount - 1) }
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Brand.brown)
                    .frame(width: 280, height: 54)
                    .background(Capsule().fill(Brand.cream))
                    .overlay(Capsule().strokeBorder(theme.accent, lineWidth: 1))
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    // MARK: Pages

    @ViewBuilder
    private func pageView(_ i: Int, size: CGSize, wide: Bool) -> some View {
        if i == Self.pageCount - 1 {
            finale(size: size, wide: wide)
        } else {
            let visual = wide ? min(size.height * 0.56, size.width * 0.42) : min(size.width * 0.72, size.height * 0.46)
            let layout = wide ? AnyLayout(HStackLayout(spacing: 64)) : AnyLayout(VStackLayout(spacing: 40))
            layout {
                scene(i, size: visual)
                    .frame(width: visual, height: visual)
                text(copy[i], centered: !wide)
                    .frame(maxWidth: wide ? 420 : 520, alignment: wide ? .leading : .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func scene(_ i: Int, size: CGFloat) -> some View {
        let active = page == i
        switch i {
        case 0: FaceToFaceScene(theme: theme, size: size, active: active, feedback: feedback)
        default: CraftScene(theme: theme, size: size, active: active)
        }
    }

    private func text(_ c: Copy, centered: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 12) {
            Text(c.title)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Brand.cream)
                .multilineTextAlignment(centered ? .center : .leading)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(c.body)
                .font(.system(size: 19))
                .foregroundStyle(Brand.cream.opacity(0.72))
                .multilineTextAlignment(centered ? .center : .leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Finale

    private var actions: some View {
        VStack(spacing: 12) {
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
                    signInNote = "Sign in with Apple isn't available in this build. You can play as a guest and sign in later from Settings."
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(Capsule())

            Button {
                feedback.ui()
                account.continueAsGuest()
                finish()
            } label: {
                Text("Continue as Guest")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Brand.cream)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(Capsule().strokeBorder(theme.accent.opacity(0.7), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressScaleStyle())

            if let signInNote {
                Text(signInNote)
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.cream.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 400)
        .animation(.easeInOut(duration: 0.3), value: signInNote)
    }

    /// A single line about Pro, not a sales page.
    private var proLine: some View {
        Button {
            feedback.ui()
            showPlans()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pro.isPro ? "64 Pro is active" : "Try 64 Pro free for 7 days")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Brand.cream)
                    Text("More boards and sets, hints, game review, stronger opponents.")
                        .font(.system(size: 13))
                        .foregroundStyle(Brand.cream.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if !pro.isPro {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Brand.cream.opacity(0.5))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.accent.opacity(0.4), lineWidth: 0.75))
        }
        .buttonStyle(PressScaleStyle())
        .disabled(pro.isPro)
        .frame(maxWidth: 400)
        .accessibilityIdentifier("onboarding-pro")
    }

    private func finale(size: CGSize, wide: Bool) -> some View {
        let mark = Image("Logo")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(Brand.cream)
            .frame(height: min(size.height * 0.2, 220))
            .accessibilityHidden(true)
        return ViewThatFits(in: .vertical) {
            VStack(spacing: 30) {
                mark
                text(copy[Self.pageCount - 1], centered: true)
                    .frame(maxWidth: 520)
                actions
                proLine
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    mark.frame(height: 120)
                    text(copy[Self.pageCount - 1], centered: true)
                    actions
                    proLine
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
                RadialGradient(colors: [Color(hex: 0xFFE2A8).opacity(0.14), .clear],
                               center: UnitPoint(x: 0.35 + 0.15 * Double(page), y: 0.34),
                               startRadius: 0, endRadius: max(s.width, s.height) * 0.6)
                    .animation(.easeInOut(duration: 0.9), value: page)
                RadialGradient(colors: [.clear, .black.opacity(0.5)], center: .center,
                               startRadius: min(s.width, s.height) * 0.35, endRadius: max(s.width, s.height) * 0.8)
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
