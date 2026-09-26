import SwiftUI
import UIKit

/// Human Food design tokens. Warm bone canvas, near-black ink, editorial serif
/// numerals and a muted, food-inspired score spectrum.
enum HF {
    enum Palette {
        static let canvas = Color(light: 0xF4F2EC, dark: 0x0D0D0B)
        static let surface = Color(light: 0xFFFFFF, dark: 0x191916)
        static let surfaceRaised = Color(light: 0xFBFAF6, dark: 0x22221E)
        static let ink = Color(light: 0x141412, dark: 0xF3F1EA)
        static let inkSecondary = Color(light: 0x6B6A64, dark: 0x9C9A92)
        static let inkTertiary = Color(light: 0xA3A198, dark: 0x5E5D57)
        static let hairline = Color(light: 0x141412, dark: 0xF3F1EA).opacity(0.08)
        static let accent = Color(light: 0x2F5A43, dark: 0x8CC49F)

        static let excellent = Color(light: 0x2E8A57, dark: 0x4CC482)
        static let good = Color(light: 0x7FA43A, dark: 0xA6CF5B)
        static let fair = Color(light: 0xD9A22B, dark: 0xF0BE4E)
        static let limit = Color(light: 0xDD7433, dark: 0xF2925A)
        static let rarely = Color(light: 0xC24A36, dark: 0xE8705C)
    }

    enum Font {
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .serif)
        }
        static func numeral(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .serif).monospacedDigit()
        }
        static let title = SwiftUI.Font.system(size: 28, weight: .regular, design: .serif)
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        static let callout = SwiftUI.Font.system(size: 14, weight: .regular)
        static let caption = SwiftUI.Font.system(size: 12, weight: .medium)
        static let eyebrow = SwiftUI.Font.system(size: 11, weight: .semibold)
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
        static let card: CGFloat = 22
        static let control: CGFloat = 16
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
            .overlay(RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous).strokeBorder(HF.Palette.hairline))
    }
}

struct Eyebrow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(HF.Font.eyebrow)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(HF.Palette.inkSecondary)
    }
}

extension View {
    func hfCard(padding: CGFloat = HF.Space.m + 4) -> some View { modifier(CardBackground(padding: padding)) }
    func eyebrow() -> some View { modifier(Eyebrow()) }
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
            .background(HF.Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(HF.Palette.hairline))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(HF.Motion.snappy, value: configuration.isPressed)
    }
}
