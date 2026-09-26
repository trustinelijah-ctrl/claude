import SwiftUI

/// The web app's tokens, unchanged: vellum ground, iron-gall ink, a bronze
/// accent, burgundy for tension and forest for agreement. Parchment only:
/// the brief never had a dark variant, and the app pins light appearance.
extension Color {
    static let vellum = Color(hex: 0xF3EEE3)
    static let vellum2 = Color(hex: 0xEDE5D6)
    static let vellum3 = Color(hex: 0xE5DBC8)
    static let vellum4 = Color(hex: 0xDCCFB6)
    static let ink = Color(hex: 0x23201C)
    static let ink2 = Color(hex: 0x5C5348)
    static let ink3 = Color(hex: 0x6E6757)
    static let ink4 = Color(hex: 0x8A8272)
    static let bronze = Color(hex: 0x8A6A2F)
    static let bronze2 = Color(hex: 0xB29A63)
    static let burgundy = Color(hex: 0x6E2233)
    static let forest = Color(hex: 0x2F4438)
    static let rule = Color(hex: 0xD6CAB3)
    static let ruleSoft = Color(hex: 0xE3D9C6)

    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

extension UIColor {
    static let vellum = UIColor(red: 0xF3 / 255, green: 0xEE / 255, blue: 0xE3 / 255, alpha: 1)
    static let ink = UIColor(red: 0x23 / 255, green: 0x20 / 255, blue: 0x1C / 255, alpha: 1)
    static let ink4 = UIColor(red: 0x8A / 255, green: 0x82 / 255, blue: 0x72 / 255, alpha: 1)
    static let rule = UIColor(red: 0xD6 / 255, green: 0xCA / 255, blue: 0xB3 / 255, alpha: 1)
}

/// Iowan Old Style ships with iOS; every size scales with Dynamic Type.
enum Typo {
    static let serifName = "Iowan Old Style"
    static func serif(_ size: CGFloat, _ style: Font.TextStyle = .body) -> Font { .custom(serifName, size: size, relativeTo: style) }
    static func serifBold(_ size: CGFloat, _ style: Font.TextStyle = .title) -> Font { .custom("IowanOldStyle-Bold", size: size, relativeTo: style) }
    static func serifItalic(_ size: CGFloat, _ style: Font.TextStyle = .body) -> Font { .custom("IowanOldStyle-Italic", size: size, relativeTo: style) }

    static let display = serifBold(34, .largeTitle)
    static let h1 = serifBold(30, .title)
    static let h2 = serifBold(23, .title2)
    static let h3 = serif(20, .title3)
    static let passage = serif(21, .body)
    static let passageSmall = serif(18.5, .body)
    static let body = serif(17, .body)
    static let meta = Font.system(size: 15, weight: .regular, design: .default)
    static let rubric = Font.system(size: 11.5, weight: .semibold, design: .default)
    static let counter = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let button = Font.system(size: 13, weight: .semibold, design: .default)
}

enum Metrics {
    static let gutter: CGFloat = 22
    static let block: CGFloat = 26
    static let readable: CGFloat = 640
}
