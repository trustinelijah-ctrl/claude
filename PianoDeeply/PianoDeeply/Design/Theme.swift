import SwiftUI
import UIKit

/// Warm ivory and graphite, a deep forest green for anything you can press,
/// and brass used sparingly for highlights (the bass note, the bottleneck).
/// Every color resolves separately for light, dark, and increased contrast.
enum Palette {
    static let canvas = dynamic(light: 0xF5F0E6, dark: 0x161513, lightHC: 0xFBF8F1, darkHC: 0x000000)
    static let surface = dynamic(light: 0xFFFCF5, dark: 0x22211E, lightHC: 0xFFFFFF, darkHC: 0x1C1B19)
    static let surfaceSunk = dynamic(light: 0xEDE6D8, dark: 0x1C1B18, lightHC: 0xE6DECE, darkHC: 0x111110)
    static let hairline = dynamic(light: 0xE0D8C7, dark: 0x3A3833, lightHC: 0x9C9383, darkHC: 0x77726A)

    static let ink = dynamic(light: 0x1D1C19, dark: 0xF2EDE3, lightHC: 0x000000, darkHC: 0xFFFFFF)
    /// Secondary text, still ≥ 4.5:1 on canvas and surface.
    static let inkSoft = dynamic(light: 0x57534B, dark: 0xB9B2A5, lightHC: 0x36332E, darkHC: 0xDAD4C8)

    static let forest = dynamic(light: 0x2D5A43, dark: 0x88C2A2, lightHC: 0x1B3D2B, darkHC: 0xB0E3C5)
    static let onForest = dynamic(light: 0xFBF7EE, dark: 0x0E1A13, lightHC: 0xFFFFFF, darkHC: 0x000000)
    static let forestWash = dynamic(light: 0xE3ECE5, dark: 0x1D2B23, lightHC: 0xD5E4D9, darkHC: 0x15251B)

    static let brass = dynamic(light: 0x86611F, dark: 0xD8B46C, lightHC: 0x5E430F, darkHC: 0xF0D398)
    static let brassWash = dynamic(light: 0xF1E6CC, dark: 0x352C1A, lightHC: 0xEAD9B1, darkHC: 0x3E3218)

    // Piano keys keep their real colors in dark mode.
    static let whiteKey = dynamic(light: 0xFFFDF7, dark: 0xE8E2D5, lightHC: 0xFFFFFF, darkHC: 0xFFFFFF)
    static let blackKey = dynamic(light: 0x23211E, dark: 0x0E0D0C, lightHC: 0x000000, darkHC: 0x000000)
    static let keyEdge = dynamic(light: 0xCFC6B3, dark: 0x6D675C, lightHC: 0x7D7465, darkHC: 0x9A9387)

    private static func dynamic(light: UInt32, dark: UInt32, lightHC: UInt32, darkHC: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let highContrast = traits.accessibilityContrast == .high
            switch (traits.userInterfaceStyle == .dark, highContrast) {
            case (false, false): return UIColor(hex: light)
            case (false, true): return UIColor(hex: lightHC)
            case (true, false): return UIColor(hex: dark)
            case (true, true): return UIColor(hex: darkHC)
            }
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Font {
    /// New York, the system serif, for a few display moments. Scales with
    /// Dynamic Type like every other style here.
    static let display = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let displayTitle = Font.system(.title2, design: .serif).weight(.semibold)
    static let displayHeadline = Font.system(.title3, design: .serif).weight(.semibold)
}
