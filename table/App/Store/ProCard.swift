import SwiftUI
import ChessCore

/// TABLE Pro, offered plainly: what it adds, what it costs, one button.
struct ProCard: View {
    let pro: ProStore
    let theme: BoardTheme
    let feedback: FeedbackCoordinator

    private struct Feature: Identifiable {
        let symbol: String, title: String, detail: String
        var id: String { title }
    }

    private let features: [Feature] = [
        Feature(symbol: "square.grid.3x3.fill", title: "Three more boards", detail: "Marble Noir, Rosewood and Midnight"),
        Feature(symbol: "crown.fill", title: "Gilded pieces", detail: "Polished gold against gunmetal"),
        Feature(symbol: "brain.head.profile", title: "Master and Grandmaster", detail: "TABLE at full strength"),
        Feature(symbol: "film.stack", title: "Every game kept", detail: "Replay any game move by move and see how it turned"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TABLE PRO")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(3)
                        .foregroundStyle(theme.accent)
                    Text(pro.isPro ? "The full set is yours." : "The full set.")
                        .font(Typeface.display(32))
                        .foregroundStyle(theme.ink)
                }
                Spacer()
                if !pro.isPro {
                    Text(pro.displayPrice)
                        .font(Typeface.display(28, bold: true))
                        .foregroundStyle(theme.accent)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(features) { f in
                    HStack(spacing: 14) {
                        Image(systemName: f.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                            Text(f.detail).font(.system(size: 13)).foregroundStyle(theme.inkSecondary)
                        }
                    }
                }
            }
            if pro.isPro {
                Label("Unlocked — thank you", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 48)
            } else {
                Button {
                    feedback.ui()
                    Task { await pro.purchase() }
                } label: {
                    ZStack {
                        if pro.isPurchasing {
                            ProgressView().tint(Color(hex: 0x2A1D0A))
                        } else {
                            Text("Unlock Pro · \(pro.displayPrice)")
                        }
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2A1D0A))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(GoldCapsule())
                }
                .buttonStyle(PressScaleStyle())
                .disabled(pro.isPurchasing)
                .accessibilityIdentifier("unlock-pro")
                HStack {
                    Text("One purchase. Yours on every iPad you own.")
                    Spacer()
                    Button("Restore") {
                        feedback.ui()
                        Task { await pro.restore() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.accent)
                }
                .font(.system(size: 13))
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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill((theme.isDark ? Color.black : Color.white).opacity(0.22)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color(hex: 0xF3DFA8), theme.accent.opacity(0.5), Color(hex: 0x8A672E)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: pro.isPro)
    }
}

/// The Pro offer on its own, over the table: opened from a locked board or opponent.
struct PaywallSheet: View {
    let pro: ProStore
    let theme: BoardTheme
    let feedback: FeedbackCoordinator
    let close: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: -24) {
                StandingPiece(piece: Piece(.white, .queen), size: 92, shadow: 0.5)
                StandingPiece(piece: Piece(.black, .king), size: 104, shadow: 0.5)
            }
            ProCard(pro: pro, theme: theme, feedback: feedback)
            Button(pro.isPro ? "Done" : "Not now") {
                feedback.ui()
                close()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.ink.opacity(0.7))
            .frame(minHeight: 44)
        }
        .frame(maxWidth: 460)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall")
    }
}
