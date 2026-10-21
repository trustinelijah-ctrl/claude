import SwiftUI
import ChessCore

/// Every finished game, newest first. The latest one is free to replay; the whole library
/// comes with TABLE Pro.
struct LibraryView: View {
    let library: GameLibrary
    let pro: ProStore
    let theme: BoardTheme
    let feedback: FeedbackCoordinator
    let open: (SavedGame) -> Void
    let unlock: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your games")
                        .font(Typeface.display(32))
                        .foregroundStyle(theme.ink)
                    Text(library.games.isEmpty ? "Finished games will appear here." : "\(library.games.count) kept · touch one to replay it")
                        .font(Typeface.italic(17))
                        .foregroundStyle(theme.inkSecondary)
                }
                Spacer()
                Button("Done") {
                    feedback.ui()
                    close()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 12)
            Rectangle().fill(theme.panelStroke).frame(height: 1)
            // Only as tall as its games, scrolling once they no longer fit.
            ViewThatFits(in: .vertical) {
                list
                ScrollView { list }
            }
        }
        .frame(maxWidth: 520, maxHeight: 680)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(theme.isDark ? Color(hex: 0x1D1713) : Color(hex: 0xF9F6F0))
                .shadow(color: .black.opacity(0.5), radius: 40, y: 18)
        )
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(theme.panelStroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library")
    }

    private var list: some View {
        VStack(spacing: 10) {
            ForEach(Array(library.games.enumerated()), id: \.element.id) { i, saved in
                let locked = !pro.isPro && i > 0
                Button {
                    feedback.ui()
                    if locked { unlock() } else { open(saved) }
                } label: {
                    row(saved, locked: locked)
                }
                .buttonStyle(PressScaleStyle())
            }
            if !pro.isPro && library.games.count > 1 {
                Button {
                    feedback.ui()
                    unlock()
                } label: {
                    Label("Keep every game with TABLE Pro", systemImage: "lock.open.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2A1D0A))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(GoldCapsule())
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, 6)
            }
        }
        .padding(20)
    }

    private func row(_ saved: SavedGame, locked: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                if let w = saved.game.result?.winner {
                    StandingPiece(piece: Piece(w, .king), size: 44, shadow: 0.3)
                } else {
                    HStack(spacing: -18) {
                        StandingPiece(piece: Piece(.white, .king), size: 38, shadow: 0.3)
                        StandingPiece(piece: Piece(.black, .king), size: 38, shadow: 0.3)
                    }
                }
            }
            .frame(width: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(saved))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("\(saved.opponentTitle) · \((saved.game.history.count + 1) / 2) moves")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.inkSecondary)
                Text(saved.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.inkSecondary.opacity(0.8))
            }
            Spacer()
            Image(systemName: locked ? "lock.fill" : "play.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(theme.accent)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.ink.opacity(0.05)))
        .opacity(locked ? 0.6 : 1)
        .contentShape(Rectangle())
    }

    private func title(_ saved: SavedGame) -> String {
        guard let result = saved.game.result else { return "Unfinished" }
        if saved.level != nil, let human = saved.humanColor {
            guard let w = result.winner else { return "Drawn · \(ResultText.headline(result))" }
            return "\(w == human ? "You" : "TABLE") won · \(ResultText.headline(result))"
        }
        if let w = result.winner { return "\(ResultText.name(w)) won · \(ResultText.headline(result))" }
        return "Drawn · \(ResultText.headline(result))"
    }
}
