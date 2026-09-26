import SwiftUI

/// The Human Food scan mark: four rounded corners with a centre line.
struct ScanGlyph: View {
    var size: CGFloat = 24
    var lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            CornerBrackets(length: size * 0.16, radius: size * 0.2)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            Capsule()
                .frame(width: size * 0.56, height: lineWidth)
        }
        .frame(width: size, height: size * 0.86)
        .accessibilityHidden(true)
    }
}

/// Compact score dial used in the result header: thin ring, bold tier-coloured number.
struct ScoreDial: View {
    var score: Int
    var size: CGFloat = 92

    var body: some View {
        let tier = ScoreTier(score: score)
        ZStack {
            Circle()
                .stroke(HF.Palette.ink.opacity(0.08), lineWidth: size * 0.075)
            Circle()
                .trim(from: 0, to: max(0.01, CGFloat(score) / 100))
                .stroke(tier.color, style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: size * 0.4, weight: .bold).monospacedDigit())
                .tracking(-size * 0.015)
                .foregroundStyle(tier.color)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100, \(tier.title)")
    }
}

/// Round translucent button that sits on top of photos and dials.
struct FloatingCircleButton<Label: View>: View {
    var size: CGFloat = 44
    var action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            label
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HF.Palette.ink)
                .frame(width: size, height: size)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }
}

/// A white rounded container of rows separated by hairlines (Scout-style summary list).
struct ListCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.035), radius: 18, y: 6)
    }
}

/// "Beneficial Ingredients      0 ●" style row.
struct ValueRow: View {
    var title: String
    var value: String
    var dot: Color
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(HF.Palette.ink)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                    .tracking(-0.3)
                    .foregroundStyle(HF.Palette.ink)
                Circle().fill(dot).frame(width: 9, height: 9)
            }
            .padding(.horizontal, 22)
            .frame(minHeight: 60)
            if showsDivider {
                Rectangle().fill(HF.Palette.hairline).frame(height: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

/// The custom tab bar with a raised green Scan button.
struct HFTabBar: View {
    @Binding var selection: MainTabView.Tab
    var onScan: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(HF.Palette.hairline).frame(height: 1)
            HStack(alignment: .center) {
                item(.home, symbol: "house")
                item(.shelf, symbol: "bag")
                Button {
                    Haptics.lock()
                    onScan()
                } label: {
                    ScanGlyph(size: 26, lineWidth: 2.4)
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(HF.Palette.accent, in: Circle())
                        .shadow(color: HF.Palette.accent.opacity(0.35), radius: 14, y: 6)
                }
                .buttonStyle(PressableStyle(scale: 0.92))
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Scan")
                item(.you, symbol: "person")
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
        .background(HF.Palette.canvas.opacity(0.96).ignoresSafeArea(edges: .bottom))
        .background(.ultraThinMaterial)
    }

    private func item(_ tab: MainTabView.Tab, symbol: String) -> some View {
        Button {
            guard selection != tab else { return }
            Haptics.tick()
            selection = tab
        } label: {
            Image(systemName: selection == tab ? symbol + ".fill" : symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(selection == tab ? HF.Palette.ink : HF.Palette.inkTertiary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}
