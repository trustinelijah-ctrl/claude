import SwiftUI
import ChessCore

/// 64 Pro, offered plainly: what it adds, the two plans, one button.
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
        Feature(symbol: "magnifyingglass", title: "Game review",
                detail: "Every finished game checked move by move, with mistakes and the better move shown"),
        Feature(symbol: "lightbulb", title: "Hints", detail: "A suggested move whenever you're stuck"),
        Feature(symbol: "brain.head.profile", title: "Master and Grandmaster", detail: "The computer at full strength"),
        Feature(symbol: "square.grid.3x3.fill", title: "Six more boards, two more sets",
                detail: "Marble, Rosewood, Midnight, Ebony, Olive, Salon; Boxwood and Gilded pieces"),
        Feature(symbol: "cloud.rain", title: "Ambience", detail: "Rain at the window or a crackling fire while you play"),
        Feature(symbol: "tray.full", title: "Every game kept", detail: "Your whole history, exportable as PGN"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("64 Pro")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(pro.isPro ? "Active. Thank you for supporting 64." : "Everything in 64, for players who want to get better.")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.inkSecondary)
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
            if !pro.isPro {
                VStack(spacing: 8) {
                    planRow(.yearly,
                            title: "Yearly",
                            price: "\(pro.price(.yearly)) a year",
                            note: pro.trialAvailable ? "7 days free, then \(pro.yearlyPerMonth) a month" : "\(pro.yearlyPerMonth) a month")
                    planRow(.monthly, title: "Monthly", price: "\(pro.price(.monthly)) a month", note: nil)
                }
                Button {
                    feedback.ui()
                    Task { await pro.purchase(plan) }
                } label: {
                    ZStack {
                        if pro.isPurchasing {
                            ProgressView().tint(Brand.brown)
                        } else {
                            Text(plan == .yearly && pro.trialAvailable ? "Start free week" : "Subscribe")
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
                HStack {
                    Text("Renews automatically. Cancel anytime in Settings.")
                    Spacer()
                    Button("Restore") {
                        feedback.ui()
                        Task { await pro.restore() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.accent)
                }
                .font(.system(size: 12))
                .foregroundStyle(theme.inkSecondary)
            }
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
                    }
                }
                Spacer()
                Text(price).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(theme.ink)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
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
        VStack(spacing: 14) {
            ViewThatFits(in: .vertical) {
                ProCard(pro: pro, theme: theme, feedback: feedback)
                ScrollView(.vertical, showsIndicators: false) {
                    ProCard(pro: pro, theme: theme, feedback: feedback)
                }
            }
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
