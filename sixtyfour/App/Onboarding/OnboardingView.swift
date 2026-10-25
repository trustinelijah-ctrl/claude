import SwiftUI
import ChessCore

/// The welcome: the board between two seats, then a knight to pick up and hear land, then
/// "Start playing". 64 Pro is offered once, after the welcome, never in the way of it.
struct OnboardingView: View {
    let pro: ProStore
    let account: AccountStore
    let feedback: FeedbackCoordinator
    var showPlans: () -> Void = {}
    let finish: () -> Void

    @State private var page: Int
    @State private var appeared = false
    @State private var knightLanded = false
    @State private var forward = true

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
        Copy(title: "Pick up the knight.",
             body: "Tap it, then a glowing square, or drag it there. Sound on."),
        Copy(title: "Welcome to 64.",
             body: "Your games stay on this \(Brand.device). Turn the sound up: every piece has its own voice."),
    ]

    private let landedCopy = Copy(title: "Hear that?",
                                  body: "Every piece has its own weight and sound. Heavier pieces knock deeper.")

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safe = proxy.safeAreaInsets
            let wide = size.width > size.height * 1.12
            ZStack {
                OnboardingBackdrop(theme: theme, page: page)

                // Pages slide by button or swipe; a custom pager, so dragging the knight on
                // page two never turns the page by accident.
                pageView(page, size: size, wide: wide)
                    .padding(.top, safe.top + 70)
                    .padding(.bottom, safe.bottom + (page == Self.pageCount - 1 ? 28 : 130))
                    .padding(.horizontal, max(32, safe.leading + 24))
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                        guard abs(v.translation.width) > abs(v.translation.height), abs(v.translation.width) > 60 else { return }
                        go(to: page + (v.translation.width < 0 ? 1 : -1))
                    })

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
                Button("Skip") { go(to: Self.pageCount - 1) }
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
                go(to: page + 1)
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

    private func go(to target: Int) {
        let t = min(max(target, 0), Self.pageCount - 1)
        guard t != page else { return }
        forward = t > page
        withAnimation(.easeInOut(duration: 0.4)) { page = t }
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
                text(i == 1 && knightLanded ? landedCopy : copy[i], centered: !wide)
                    .animation(.easeInOut(duration: 0.3), value: knightLanded)
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
        default: KnightScene(theme: theme, size: size, active: active, feedback: feedback) { knightLanded = true }
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
        Button {
            feedback.ui()
            account.continueAsGuest()
            finish()
        } label: {
            Text("Start playing")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Brand.brown)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(Brand.cream))
                .overlay(Capsule().strokeBorder(theme.accent, lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .frame(maxWidth: 400)
        .accessibilityIdentifier("onboarding-start")
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    mark.frame(height: 120)
                    text(copy[Self.pageCount - 1], centered: true)
                    actions
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
