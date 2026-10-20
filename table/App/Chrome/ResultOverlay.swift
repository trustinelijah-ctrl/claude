import SwiftUI
import ChessCore

enum ResultText {
    static func headline(_ r: GameResult) -> String {
        switch r {
        case .checkmate: return "Checkmate"
        case .resignation: return "Resignation"
        case .draw(let reason):
            switch reason {
            case .stalemate: return "Stalemate"
            default: return "Draw"
            }
        }
    }

    static func detail(_ r: GameResult) -> String {
        switch r {
        case .checkmate(let w): return "\(name(w)) wins"
        case .resignation(let w): return "\(name(w.opposite)) resigns · \(name(w)) wins"
        case .draw(let reason):
            switch reason {
            case .stalemate: return "No legal moves, and no check"
            case .insufficientMaterial: return "Neither side can mate"
            case .threefoldRepetition: return "Threefold repetition"
            case .fivefoldRepetition: return "Fivefold repetition"
            case .fiftyMoveRule: return "Fifty moves without a capture or pawn move"
            case .seventyFiveMoveRule: return "Seventy-five moves without progress"
            case .agreement: return "By agreement"
            }
        }
    }

    static func name(_ c: PieceColor) -> String { c == .white ? "White" : "Black" }
}

/// The end of the game, written once for each player so both can read it from their seat.
struct ResultOverlay: View {
    let result: GameResult
    let theme: BoardTheme
    let boardSize: CGFloat
    let playAgain: () -> Void
    let dismiss: () -> Void

    var body: some View {
        let width = min(boardSize * 0.72, 460)
        VStack(spacing: 0) {
            half(for: .black)
                .rotationEffect(.degrees(180))
            Rectangle()
                .fill(LinearGradient(colors: [.clear, theme.accent.opacity(0.55), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
                .padding(.horizontal, 28)
            half(for: .white)
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.isDark ? Color(hex: 0x1B1511) : Color(hex: 0xFAF7F1))
                .shadow(color: .black.opacity(0.5), radius: 40, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("result")
    }

    private func half(for seat: PieceColor) -> some View {
        let won = result.winner == seat
        let compact = boardSize < 520
        return VStack(spacing: compact ? 10 : 14) {
            if let w = result.winner {
                PieceGlyph(piece: Piece(w, .king))
                    .frame(width: compact ? 34 : 44, height: compact ? 34 : 44)
            }
            VStack(spacing: 4) {
                Text(ResultText.headline(result))
                    .font(.system(size: compact ? 24 : 30, weight: .regular, design: .serif))
                    .foregroundStyle(theme.ink)
                Text(won ? "Well played" : ResultText.detail(result))
                    .font(.system(size: compact ? 12 : 13, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(won ? theme.accent : theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                Button(action: dismiss) {
                    Text("Dismiss")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.ink.opacity(0.07)))
                }
                .buttonStyle(PressScaleStyle())
                Button(action: playAgain) {
                    Text("Play Again")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.isDark ? Color(hex: 0x1B1511) : .white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.accent))
                }
                .buttonStyle(PressScaleStyle())
            }
        }
        .padding(.horizontal, compact ? 18 : 28)
        .padding(.vertical, compact ? 16 : 24)
    }
}
