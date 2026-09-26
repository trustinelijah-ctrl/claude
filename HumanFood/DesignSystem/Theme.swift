import SwiftUI
import UIKit

/// Human Food design tokens. Cool paper canvas, green-black ink, heavy SF Pro
/// headlines with tight tracking, monospaced tracked labels and a clean,
/// food-inspired score spectrum.
enum HF {
    enum Palette {
        static let canvas = Color(light: 0xF4F4F1, dark: 0x0B0D0C)
        static let surface = Color(light: 0xFFFFFF, dark: 0x171A18)
        static let surfaceRaised = Color(light: 0xF9F9F7, dark: 0x1F2320)
        /// Light grey tiles ("Compare", summary rows).
        static let surfaceMuted = Color(light: 0xECECE8, dark: 0x202522)
        static let ink = Color(light: 0x0E1411, dark: 0xF1F3F0)
        static let inkSecondary = Color(light: 0x6C716D, dark: 0x9BA29D)
        static let inkTertiary = Color(light: 0xA4A9A5, dark: 0x5F6662)
        static let hairline = Color(light: 0x0E1411, dark: 0xF1F3F0).opacity(0.07)
        static let accent = Color(light: 0x1C8C4E, dark: 0x3FC47A)
        /// Mint wash used on the home hero card.
        static let mint = Color(light: 0xD7EEDF, dark: 0x16311F)
        /// Deep green-black of the primary "Scan" tile.
        static let forest = Color(light: 0x0D1812, dark: 0x0D1812)
        static let forestLight = Color(light: 0x1C2C23, dark: 0x1E3327)

        static let excellent = Color(light: 0x1C8C4E, dark: 0x3FC47A)
        static let good = Color(light: 0x6FA83A, dark: 0x98CF5E)
        static let fair = Color(light: 0xE0A526, dark: 0xF2BE4A)
        static let limit = Color(light: 0xE7722E, dark: 0xF59255)
        static let rarely = Color(light: 0xD2402F, dark: 0xF06A58)
    }

    enum Font {
        /// Heavy SF Pro display face. Pair with `.tracking(-size * 0.035)` (see `hfDisplay`).
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .system(size: size, weight: weight)
        }
        static func numeral(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .bold).monospacedDigit()
        }
        static func mono(_ size: CGFloat, weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        static let title = SwiftUI.Font.system(size: 30, weight: .bold)
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        static let callout = SwiftUI.Font.system(size: 15, weight: .regular)
        static let caption = SwiftUI.Font.system(size: 12, weight: .medium)
        static let eyebrow = SwiftUI.Font.system(size: 12, weight: .medium, design: .monospaced)
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 36
        static let gutter: CGFloat = 20
    }

    enum Radius {
        static let card: CGFloat = 28
        static let hero: CGFloat = 34
        static let control: CGFloat = 18
        static let chip: CGFloat = 12
    }

    enum Motion {
        static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.82)
        static let soft = Animation.spring(response: 0.55, dampingFraction: 0.86)
        static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.62)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

// MARK: - Reusable modifiers

struct CardBackground: ViewModifier {
    var padding: CGFloat = HF.Space.m + 4

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.035), radius: 18, y: 6)
    }
}

struct Eyebrow: ViewModifier {
    var color: Color = HF.Palette.inkSecondary

    func body(content: Content) -> some View {
        content
            .font(HF.Font.eyebrow)
            .tracking(3)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    func hfCard(padding: CGFloat = HF.Space.m + 4) -> some View { modifier(CardBackground(padding: padding)) }
    func eyebrow(_ color: Color = HF.Palette.inkSecondary) -> some View { modifier(Eyebrow(color: color)) }

    /// Heavy, tightly tracked headline — the signature type style.
    func hfDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        font(HF.Font.display(size, weight: weight)).tracking(-size * 0.035)
    }
}

/// "● BEGIN" style label: coloured dot + monospaced tracked caps.
struct DotLabel: View {
    var text: String
    var color: Color = HF.Palette.accent

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).eyebrow()
        }
    }
}

/// Monospaced eyebrow above a heavy section title, as in "SUMMARY / What you need to know".
struct SectionTitle: View {
    var eyebrow: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow).eyebrow()
            Text(title)
                .hfDisplay(28)
                .foregroundStyle(HF.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Subtle press-down feel used on every tappable surface.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(HF.Motion.snappy, value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = HF.Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(HF.Palette.canvas)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(tint, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(HF.Motion.snappy, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(HF.Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(HF.Palette.surfaceMuted, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(HF.Motion.snappy, value: configuration.isPressed)
    }
}
