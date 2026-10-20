import SwiftUI

enum ThemeID: String, CaseIterable, Identifiable, Codable {
    case walnut, slate
    var id: String { rawValue }
}

/// A complete material and colour system for one board.
struct BoardTheme: Equatable {
    let id: ThemeID
    let name: String
    let subtitle: String

    // Materials
    let surfaceImage: String
    let rimImage: String
    let rimTint: Color
    let inlay: Color
    let rimHighlight: Color

    // The table the board sits on
    let tableCenter: Color
    let tableEdge: Color
    let boardShadow: Color

    // Marks on the board
    let coordinate: Color
    let selection: Color
    let lastMove: Color
    let hint: Color
    let hover: Color
    let check: Color
    let turnGlow: Color

    // Interface
    let ink: Color
    let inkSecondary: Color
    let panel: Color
    let panelStroke: Color
    let accent: Color
    let isDark: Bool

    static let walnut = BoardTheme(
        id: .walnut,
        name: "Walnut Nocturne",
        subtitle: "Black walnut, maple, gilt inlay",
        surfaceImage: "WalnutSurface",
        rimImage: "WalnutRim",
        rimTint: Color(hex: 0x1A0F09, opacity: 0.18),
        inlay: Color(hex: 0xC9A66B),
        rimHighlight: Color(hex: 0xF3D9AE, opacity: 0.22),
        tableCenter: Color(hex: 0x1D1612),
        tableEdge: Color(hex: 0x0B0807),
        boardShadow: Color.black.opacity(0.62),
        coordinate: Color(hex: 0xD8B77E, opacity: 0.62),
        selection: Color(hex: 0xE9C27A, opacity: 0.34),
        lastMove: Color(hex: 0xE2B867, opacity: 0.20),
        hint: Color(hex: 0x1E120A, opacity: 0.30),
        hover: Color(hex: 0xF6DDAA, opacity: 0.55),
        check: Color(hex: 0xC4452E),
        turnGlow: Color(hex: 0xE3BD78),
        ink: Color(hex: 0xEADBC2),
        inkSecondary: Color(hex: 0xEADBC2, opacity: 0.52),
        panel: Color(hex: 0x2A201A, opacity: 0.72),
        panelStroke: Color(hex: 0xE3BD78, opacity: 0.16),
        accent: Color(hex: 0xD9B172),
        isDark: true
    )

    static let slate = BoardTheme(
        id: .slate,
        name: "Ivory & Slate",
        subtitle: "Honed ivory stone, cleft slate",
        surfaceImage: "SlateSurface",
        rimImage: "SlateRim",
        rimTint: Color(hex: 0x101114, opacity: 0.12),
        inlay: Color(hex: 0xE9E3D7),
        rimHighlight: Color.white.opacity(0.16),
        tableCenter: Color(hex: 0xEAE5DC),
        tableEdge: Color(hex: 0xD5CEC2),
        boardShadow: Color(hex: 0x2B2620, opacity: 0.38),
        coordinate: Color(hex: 0xE9E3D7, opacity: 0.66),
        selection: Color(hex: 0xB39256, opacity: 0.36),
        lastMove: Color(hex: 0xB89A62, opacity: 0.22),
        hint: Color(hex: 0x1C1E22, opacity: 0.26),
        hover: Color(hex: 0x8F7344, opacity: 0.60),
        check: Color(hex: 0xB8432F),
        turnGlow: Color(hex: 0x9C7C45),
        ink: Color(hex: 0x24262A),
        inkSecondary: Color(hex: 0x24262A, opacity: 0.50),
        panel: Color(hex: 0xFFFFFF, opacity: 0.55),
        panelStroke: Color(hex: 0x24262A, opacity: 0.08),
        accent: Color(hex: 0x8E6F3C),
        isDark: false
    )

    static func with(_ id: ThemeID) -> BoardTheme {
        switch id {
        case .walnut: return .walnut
        case .slate: return .slate
        }
    }
}

/// Motion constants, tuned on device-sized boards rather than taken from defaults.
enum Motion {
    /// A piece travelling across the board decelerates like an object being set down.
    static func travelDuration(squares: Double) -> Double {
        min(0.27, 0.15 + 0.018 * squares)
    }
    static let travelCurve = (0.22, 0.0, 0.12, 1.0)
    /// The moment within a travel animation at which the piece reads as landed.
    static let landingFraction = 0.78

    static let lift = Animation.spring(response: 0.15, dampingFraction: 0.8)
    static let settle = Animation.spring(response: 0.16, dampingFraction: 0.85)
    static let settleLanding = 0.075
    static let returnHome = Animation.spring(response: 0.22, dampingFraction: 0.84)
    static let undo = Animation.spring(response: 0.26, dampingFraction: 0.9)
    static let capture = 0.2
    static let castleRookDelay = 0.085
    static let fade = Animation.easeOut(duration: 0.16)
}
