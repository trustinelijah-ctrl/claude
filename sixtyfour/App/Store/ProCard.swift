import SwiftUI
import ChessCore

/// 64 Pro, offered plainly: what it adds, three ways to have it, one button. The plans and
/// button stay pinned; on a small screen only the list of features scrolls.
struct ProCard: View {
    let pro: ProStore
    let theme: BoardTheme
    let feedback: FeedbackCoordinator

    @State private var plan: ProStore.Plan = .yearly

    struct Feature: Identifiable {
        let symbol: String, title: String, detail: String
        var id: String { title }
    }

    static let features: [Feature] = [
        Feature(symbol: "square.grid.3x3.fill", title: "Six more boards, two more sets",
                detail: "Marble, Rosewood, Midnight, Ebony, Olive, Salon; Boxwood and Gilded pieces"),
        Feature(symbol: "cloud.rain", title: "Ambience", detail: "Rain at the window, a crackling fire, a summer night"),
        Feature(symbol: "graduationcap", title: "Every puzzle", detail: "All checkmate puzzles, from one move to three"),
        Feature(symbol: "magnifyingglass", title: "Game review",
                detail: "Every finished game checked move by move, with the better move shown"),
        Feature(symbol: "brain.head.profile", title: "Master and Grandmaster", detail: "The computer at full strength, with hints"),
        Feature(symbol: "tray.full", title: "Every game kept", detail: "Your whole history, exportable as PGN"),
    ]

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://play64.netlify.app/privacy")!

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .vertical) {
                info
                // A short screen scrolls the features; the fade says there is more below.
                ScrollView(.vertical, showsIndicators: false) { info.padding(.bottom, 18) }
                    .mask(VStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 28)
                    })
            }
            if !pro.isPro { purchase }
            if let message = pro.message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.isDark ? Color(hex: 0x1E120B) : Color(hex: 0xFBF8F2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color(hex: 0xF3DFA8), theme.accent.opacity(0.5), Color(hex: 0x8A672E)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: pro.isPro)
        .animation(.easeInOut(duration: 0.2), value: plan)
    }

    /// The headline and what Pro adds.
    private var info: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("64 Pro")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(pro.isPro ? "Active. Thank you for supporting 64."
                               : "Every board, every set, and rain or a fire while you play. Shared with your family.")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Self.features) { f in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: f.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                            Text(f.detail).font(.system(size: 13)).foregroundStyle(theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Plans, the button, and the small print. Always on screen. Until the App Store has
    /// answered with real prices, it says so and offers to try again, rather than guessing.
    @ViewBuilder
    private var purchase: some View {
        if pro.storeReady { plans } else { connecting }
    }

    private var connecting: some View {
        VStack(spacing: 12) {
            if pro.isLoading {
                ProgressView()
                Text("Connecting to the App Store…")
            } else {
                Text("The App Store isn't answering right now.")
                Button("Try again") {
                    feedback.ui()
                    Task { await pro.load() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(theme.accent)
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(theme.inkSecondary)
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var plans: some View {
        let lifetime = pro.lifetimePlan
        return VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 8) {
                planRow(.yearly, title: "Yearly", price: "\(pro.price(.yearly)) a year",
                        note: pro.trialAvailable ? "7 days free, then \(pro.price(.yearly)) a year (\(pro.yearlyPerMonth) a month)"
                                                 : "\(pro.yearlyPerMonth) a month, billed yearly")
                planRow(.monthly, title: "Monthly", price: "\(pro.price(.monthly)) a month", note: nil)
                planRow(lifetime, title: lifetime == .founder ? "Founder lifetime" : "Lifetime",
                        price: pro.price(lifetime),
                        note: lifetime == .founder ? "Pay once. Launch price, for the first weeks only" : "Pay once, yours for good")
            }
            Button {
                feedback.ui()
                Task { await pro.purchase(plan) }
            } label: {
                ZStack {
                    if pro.isPurchasing {
                        ProgressView().tint(Brand.brown)
                    } else {
                        Text(buttonTitle)
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Brand.brown)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(GoldCapsule())
            }
            .buttonStyle(PressScaleStyle())
            .disabled(pro.isPurchasing)
            .accessibilityIdentifier("unlock-pro")
            HStack(alignment: .top, spacing: 6) {
                Text(disclosure)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("Restore") {
                    feedback.ui()
                    Task { await pro.restore() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(theme.accent)
            }
            .font(.system(size: 12))
            .foregroundStyle(theme.inkSecondary)
            HStack(spacing: 14) {
                Link("Terms of Use", destination: Self.termsURL)
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(theme.inkSecondary)
        }
        .onChange(of: pro.lifetimePlan) { _, now in
            if !plan.isSubscription { plan = now }
        }
    }

    /// What will be charged, and when, in plain words under the button (App Store guideline 3.1.2).
    private var disclosure: String {
        switch plan {
        case .yearly where pro.trialAvailable:
            return "Free for 7 days, then \(pro.price(.yearly)) a year. Renews automatically until cancelled; cancel at least a day before the trial ends to pay nothing."
        case .yearly:
            return "\(pro.price(.yearly)) a year. Renews automatically until cancelled."
        case .monthly:
            return "\(pro.price(.monthly)) a month. Renews automatically until cancelled."
        case .lifetime, .founder:
            return "One payment of \(pro.price(plan)). No subscription."
        }
    }

    private var buttonTitle: String {
        if !plan.isSubscription { return "Buy once for \(pro.price(plan))" }
        return plan == .yearly && pro.trialAvailable ? "Start free week" : "Subscribe"
    }

    private func planRow(_ p: ProStore.Plan, title: String, price: String, note: String?) -> some View {
        let selected = plan == p
        return Button {
            plan = p
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? theme.accent : theme.inkSecondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                    if let note {
                        Text(note).font(.system(size: 12)).foregroundStyle(theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Text(price).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(theme.ink)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.ink.opacity(selected ? 0.08 : 0.03)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? theme.accent : theme.ink.opacity(0.12), lineWidth: selected ? 1.5 : 0.75))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The Pro offer on its own, over the table.
struct PaywallSheet: View {
    let pro: ProStore
    let theme: BoardTheme
    let feedback: FeedbackCoordinator
    let close: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ProCard(pro: pro, theme: theme, feedback: feedback)
            Button(pro.isPro ? "Done" : "Not now") {
                feedback.ui()
                close()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Brand.cream.opacity(0.8))
            .frame(minHeight: 44)
        }
        .frame(maxWidth: 460)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall")
    }
}

/// A gold-leaf capsule for the primary purchase action.
struct GoldCapsule: View {
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(hex: 0xF7E6B4), Color(hex: 0xD4AF66), Color(hex: 0xA27A3A)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(Capsule().strokeBorder(Color(hex: 0xFFF3D0).opacity(0.8), lineWidth: 0.75))
            .shadow(color: Color(hex: 0xD4AF66).opacity(0.3), radius: 10, y: 3)
    }
}
