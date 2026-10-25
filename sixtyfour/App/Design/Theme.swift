import SwiftUI

enum ThemeID: String, CaseIterable, Identifiable, Codable {
    case house, walnut, slate, tournament, salon, marble, rosewood, midnight, ebony, olive
    var id: String { rawValue }
    /// The boards that come with 64 Pro.
    var isPro: Bool {
        switch self {
        case .house, .walnut, .slate, .tournament: return false
        default: return true
        }
    }
}

/// The brand's own colours, taken from the logo.
enum Brand {
    /// The logo brown, #381F11.
    static let brown = Color(hex: 0x381F11)
    static let cream = Color(hex: 0xF2E8D8)
    static let gold = Color(hex: 0xD4AF66)
    /// "iPhone" or "iPad", for copy that talks about the device on the table.
    static var device: String { UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "iPad" }
}

/// A complete material and colour system for one board and the table it sits on.
struct BoardTheme: Equatable {
    let id: ThemeID
    let name: String
    let subtitle: String

    // Materials
    let surfaceImage: String
    let rimImage: String
    /// The board's own surface around the grid, filling the rest of the screen.
    let fieldImage: String
    let rimTint: Color
    let inlay: Color
    let rimHighlight: Color
    /// A second, finer tooled line inside the frame.
    let doubleTooling: Bool

    // The table and the light over it
    let tableCenter: Color
    let tableEdge: Color
    let boardShadow: Color
    /// How quickly the lamp's pool of light falls off across the playing surface (0 = even).
    let vignette: Double
    /// Strength of the shadows the pieces cast.
    let pieceShadow: Double
    /// Film grain over the table, so large gradients never band.
    let grain: Double

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

    static let salon = BoardTheme(
        id: .salon,
        name: "Salon",
        subtitle: "Emerald shagreen, bone, gilt tooling",
        surfaceImage: "SalonSurface",
        rimImage: "SalonRim",
        fieldImage: "SalonField",
        rimTint: Color(hex: 0x020605, opacity: 0.10),
        inlay: Color(hex: 0xC9A35A),
        rimHighlight: Color(hex: 0xE9CF95, opacity: 0.30),
        doubleTooling: true,
        tableCenter: Color(hex: 0x1C2A25),
        tableEdge: Color(hex: 0x040807),
        boardShadow: Color.black.opacity(0.7),
        vignette: 0.30,
        pieceShadow: 0.55,
        grain: 0.07,
        coordinate: Color(hex: 0xC9A35A, opacity: 0.80),
        selection: Color(hex: 0xE2BE74, opacity: 0.30),
        lastMove: Color(hex: 0xD8B46A, opacity: 0.20),
        hint: Color(hex: 0xD9B66E, opacity: 0.80),
        hover: Color(hex: 0xF1D79E, opacity: 0.75),
        check: Color(hex: 0xC9442E),
        turnGlow: Color(hex: 0xE2BA70),
        ink: Color(hex: 0xEFE6D2),
        inkSecondary: Color(hex: 0xEFE6D2, opacity: 0.50),
        panel: Color(hex: 0x14201C, opacity: 0.8),
        panelStroke: Color(hex: 0xC9A35A, opacity: 0.35),
        accent: Color(hex: 0xD6B26B),
        isDark: true
    )

    static let walnut = BoardTheme(
        id: .walnut,
        name: "Walnut Nocturne",
        subtitle: "Black walnut, maple, gilt inlay",
        surfaceImage: "WalnutSurface",
        rimImage: "WalnutRim",
        fieldImage: "WalnutField",
        rimTint: Color(hex: 0x1A0F09, opacity: 0.18),
        inlay: Color(hex: 0xC9A66B),
        rimHighlight: Color(hex: 0xF3D9AE, opacity: 0.22),
        doubleTooling: false,
        tableCenter: Color(hex: 0x241A14),
        tableEdge: Color(hex: 0x080605),
        boardShadow: Color.black.opacity(0.62),
        vignette: 0.26,
        pieceShadow: 0.5,
        grain: 0.06,
        coordinate: Color(hex: 0xD8B77E, opacity: 0.62),
        selection: Color(hex: 0xE9C27A, opacity: 0.34),
        lastMove: Color(hex: 0xE2B867, opacity: 0.20),
        hint: Color(hex: 0x1E120A, opacity: 0.32),
        hover: Color(hex: 0xF6DDAA, opacity: 0.55),
        check: Color(hex: 0xC4452E),
        turnGlow: Color(hex: 0xE3BD78),
        ink: Color(hex: 0xEADBC2),
        inkSecondary: Color(hex: 0xEADBC2, opacity: 0.52),
        panel: Color(hex: 0x2A201A, opacity: 0.72),
        panelStroke: Color(hex: 0xE3BD78, opacity: 0.3),
        accent: Color(hex: 0xD9B172),
        isDark: true
    )

    static let slate = BoardTheme(
        id: .slate,
        name: "Ivory & Slate",
        subtitle: "Honed ivory stone, cleft slate",
        surfaceImage: "SlateSurface",
        rimImage: "SlateRim",
        fieldImage: "SlateField",
        rimTint: Color(hex: 0x101114, opacity: 0.12),
        inlay: Color(hex: 0xE9E3D7),
        rimHighlight: Color.white.opacity(0.16),
        doubleTooling: false,
        tableCenter: Color(hex: 0xEDE8DF),
        tableEdge: Color(hex: 0xCFC7BA),
        boardShadow: Color(hex: 0x2B2620, opacity: 0.40),
        vignette: 0.10,
        pieceShadow: 0.36,
        grain: 0.05,
        coordinate: Color(hex: 0xE9E3D7, opacity: 0.70),
        selection: Color(hex: 0xB39256, opacity: 0.36),
        lastMove: Color(hex: 0xB89A62, opacity: 0.22),
        hint: Color(hex: 0x1C1E22, opacity: 0.28),
        hover: Color(hex: 0x8F7344, opacity: 0.60),
        check: Color(hex: 0xB8432F),
        turnGlow: Color(hex: 0xB08A4A),
        ink: Color(hex: 0x24262A),
        inkSecondary: Color(hex: 0x24262A, opacity: 0.50),
        panel: Color(hex: 0xFFFFFF, opacity: 0.55),
        panelStroke: Color(hex: 0x24262A, opacity: 0.14),
        accent: Color(hex: 0x8E6F3C),
        isDark: false
    )

    static let marble = BoardTheme(
        id: .marble,
        name: "Marble Noir",
        subtitle: "Calacatta and Nero Marquina, silver line",
        surfaceImage: "MarbleSurface",
        rimImage: "MarbleRim",
        fieldImage: "MarbleField",
        rimTint: Color(hex: 0x000000, opacity: 0.10),
        inlay: Color(hex: 0xCFCAC2),
        rimHighlight: Color.white.opacity(0.18),
        doubleTooling: false,
        tableCenter: Color(hex: 0x1C1B1D),
        tableEdge: Color(hex: 0x050506),
        boardShadow: Color.black.opacity(0.7),
        vignette: 0.28,
        pieceShadow: 0.55,
        grain: 0.06,
        coordinate: Color(hex: 0xBDB6AA, opacity: 0.8),
        selection: Color(hex: 0xD9C08A, opacity: 0.32),
        lastMove: Color(hex: 0xCDB27A, opacity: 0.22),
        hint: Color(hex: 0xC8AD72, opacity: 0.8),
        hover: Color(hex: 0xE8D6AA, opacity: 0.7),
        check: Color(hex: 0xC4442F),
        turnGlow: Color(hex: 0xDCCBA8),
        ink: Color(hex: 0xECE8E1),
        inkSecondary: Color(hex: 0xECE8E1, opacity: 0.5),
        panel: Color(hex: 0x1A1A1C, opacity: 0.8),
        panelStroke: Color(hex: 0xCFCAC2, opacity: 0.3),
        accent: Color(hex: 0xD4BC8A),
        isDark: true
    )

    static let rosewood = BoardTheme(
        id: .rosewood,
        name: "Rosewood",
        subtitle: "Santos rosewood, rippled sycamore",
        surfaceImage: "RosewoodSurface",
        rimImage: "RosewoodRim",
        fieldImage: "RosewoodField",
        rimTint: Color(hex: 0x1A0805, opacity: 0.16),
        inlay: Color(hex: 0xD2A867),
        rimHighlight: Color(hex: 0xF5D3A0, opacity: 0.22),
        doubleTooling: false,
        tableCenter: Color(hex: 0x2A120C),
        tableEdge: Color(hex: 0x0A0403),
        boardShadow: Color.black.opacity(0.65),
        vignette: 0.26,
        pieceShadow: 0.5,
        grain: 0.06,
        coordinate: Color(hex: 0xE1BC80, opacity: 0.7),
        selection: Color(hex: 0xF0C47C, opacity: 0.34),
        lastMove: Color(hex: 0xE8B867, opacity: 0.22),
        hint: Color(hex: 0x2A0E08, opacity: 0.34),
        hover: Color(hex: 0xF8DCA8, opacity: 0.55),
        check: Color(hex: 0xD04A2E),
        turnGlow: Color(hex: 0xE9B876),
        ink: Color(hex: 0xF0DFC8),
        inkSecondary: Color(hex: 0xF0DFC8, opacity: 0.52),
        panel: Color(hex: 0x2E1610, opacity: 0.75),
        panelStroke: Color(hex: 0xE9B876, opacity: 0.3),
        accent: Color(hex: 0xDDB074),
        isDark: true
    )

    static let midnight = BoardTheme(
        id: .midnight,
        name: "Midnight",
        subtitle: "Navy lacquer, pearl, starlight fleck",
        surfaceImage: "MidnightSurface",
        rimImage: "MidnightRim",
        fieldImage: "MidnightField",
        rimTint: Color(hex: 0x02040C, opacity: 0.12),
        inlay: Color(hex: 0xC7B27E),
        rimHighlight: Color(hex: 0xDCE4F5, opacity: 0.2),
        doubleTooling: true,
        tableCenter: Color(hex: 0x121A33),
        tableEdge: Color(hex: 0x03050C),
        boardShadow: Color.black.opacity(0.7),
        vignette: 0.3,
        pieceShadow: 0.55,
        grain: 0.07,
        coordinate: Color(hex: 0xC7B27E, opacity: 0.8),
        selection: Color(hex: 0xE2C67E, opacity: 0.3),
        lastMove: Color(hex: 0xD8BC72, opacity: 0.22),
        hint: Color(hex: 0xD9BE76, opacity: 0.8),
        hover: Color(hex: 0xEED9A4, opacity: 0.7),
        check: Color(hex: 0xD24B36),
        turnGlow: Color(hex: 0xC9D4F0),
        ink: Color(hex: 0xE6EAF3),
        inkSecondary: Color(hex: 0xE6EAF3, opacity: 0.5),
        panel: Color(hex: 0x0E1428, opacity: 0.8),
        panelStroke: Color(hex: 0xC7B27E, opacity: 0.32),
        accent: Color(hex: 0xD6BE84),
        isDark: true
    )

    /// 64's own board, in the logo's brown: walnut-brown and cream squares on a brown leather field.
    static let house = BoardTheme(
        id: .house,
        name: "64",
        subtitle: "Brown and cream, the house board",
        surfaceImage: "HouseSurface",
        rimImage: "HouseRim",
        fieldImage: "HouseField",
        rimTint: Color(hex: 0x1A0D05, opacity: 0.1),
        inlay: Color(hex: 0xC9A35A),
        rimHighlight: Color(hex: 0xF3D9AE, opacity: 0.22),
        doubleTooling: false,
        tableCenter: Color(hex: 0x42261A),
        tableEdge: Color(hex: 0x1C0F08),
        boardShadow: Color.black.opacity(0.6),
        vignette: 0.18,
        pieceShadow: 0.5,
        grain: 0.05,
        coordinate: Color(hex: 0xF2E8D8, opacity: 0.8),
        selection: Color(hex: 0xE9C27A, opacity: 0.36),
        lastMove: Color(hex: 0xE2B867, opacity: 0.26),
        hint: Color(hex: 0x381F11, opacity: 0.34),
        hover: Color(hex: 0xF6DDAA, opacity: 0.6),
        check: Color(hex: 0xC4452E),
        turnGlow: Color(hex: 0xE3BD78),
        ink: Color(hex: 0xF2E8D8),
        inkSecondary: Color(hex: 0xF2E8D8, opacity: 0.55),
        panel: Color(hex: 0x2A170D, opacity: 0.8),
        panelStroke: Color(hex: 0xD4AF66, opacity: 0.3),
        accent: Color(hex: 0xD4AF66),
        isDark: true
    )

    static let tournament = BoardTheme(
        id: .tournament,
        name: "Tournament",
        subtitle: "Green and buff, the club board",
        surfaceImage: "TournamentSurface",
        rimImage: "TournamentRim",
        fieldImage: "TournamentField",
        rimTint: Color(hex: 0x000000, opacity: 0.08),
        inlay: Color(hex: 0xC9A35A),
        rimHighlight: Color.white.opacity(0.16),
        doubleTooling: false,
        tableCenter: Color(hex: 0x1C2A1E),
        tableEdge: Color(hex: 0x0A100B),
        boardShadow: Color.black.opacity(0.6),
        vignette: 0.12,
        pieceShadow: 0.5,
        grain: 0.05,
        coordinate: Color(hex: 0xF0EDD8, opacity: 0.85),
        selection: Color(hex: 0xE9D27A, opacity: 0.4),
        lastMove: Color(hex: 0xE8D46A, opacity: 0.32),
        hint: Color(hex: 0x1C2A1E, opacity: 0.3),
        hover: Color(hex: 0xF6EBAA, opacity: 0.6),
        check: Color(hex: 0xC4452E),
        turnGlow: Color(hex: 0xE3D078),
        ink: Color(hex: 0xEEF0E4),
        inkSecondary: Color(hex: 0xEEF0E4, opacity: 0.55),
        panel: Color(hex: 0x16211A, opacity: 0.8),
        panelStroke: Color(hex: 0xD4AF66, opacity: 0.3),
        accent: Color(hex: 0xD4AF66),
        isDark: true
    )

    static let ebony = BoardTheme(
        id: .ebony,
        name: "Ebony & Maple",
        subtitle: "Gaboon ebony, bird's-eye maple",
        surfaceImage: "EbonySurface",
        rimImage: "EbonyRim",
        fieldImage: "EbonyField",
        rimTint: Color(hex: 0x000000, opacity: 0.1),
        inlay: Color(hex: 0xC9A35A),
        rimHighlight: Color.white.opacity(0.14),
        doubleTooling: true,
        tableCenter: Color(hex: 0x1A1614),
        tableEdge: Color(hex: 0x050404),
        boardShadow: Color.black.opacity(0.7),
        vignette: 0.24,
        pieceShadow: 0.55,
        grain: 0.06,
        coordinate: Color(hex: 0xE8D6B0, opacity: 0.75),
        selection: Color(hex: 0xE9C27A, opacity: 0.34),
        lastMove: Color(hex: 0xE2B867, opacity: 0.24),
        hint: Color(hex: 0xD9B66E, opacity: 0.8),
        hover: Color(hex: 0xF6DDAA, opacity: 0.6),
        check: Color(hex: 0xC4452E),
        turnGlow: Color(hex: 0xE3BD78),
        ink: Color(hex: 0xEDE4D6),
        inkSecondary: Color(hex: 0xEDE4D6, opacity: 0.5),
        panel: Color(hex: 0x15110F, opacity: 0.8),
        panelStroke: Color(hex: 0xD4AF66, opacity: 0.3),
        accent: Color(hex: 0xD4AF66),
        isDark: true
    )

    static let olive = BoardTheme(
        id: .olive,
        name: "Olive",
        subtitle: "Figured olive wood, pale ash",
        surfaceImage: "OliveSurface",
        rimImage: "OliveRim",
        fieldImage: "OliveField",
        rimTint: Color(hex: 0x0E0A04, opacity: 0.12),
        inlay: Color(hex: 0xC9A35A),
        rimHighlight: Color(hex: 0xF3E4AE, opacity: 0.2),
        doubleTooling: false,
        tableCenter: Color(hex: 0x2C2716),
        tableEdge: Color(hex: 0x0E0C06),
        boardShadow: Color.black.opacity(0.62),
        vignette: 0.2,
        pieceShadow: 0.5,
        grain: 0.06,
        coordinate: Color(hex: 0xEDE4C8, opacity: 0.8),
        selection: Color(hex: 0xE9CB7A, opacity: 0.36),
        lastMove: Color(hex: 0xE2C267, opacity: 0.26),
        hint: Color(hex: 0x2C2716, opacity: 0.32),
        hover: Color(hex: 0xF6E2AA, opacity: 0.6),
        check: Color(hex: 0xC4452E),
        turnGlow: Color(hex: 0xE3C478),
        ink: Color(hex: 0xEFEADA),
        inkSecondary: Color(hex: 0xEFEADA, opacity: 0.55),
        panel: Color(hex: 0x221E11, opacity: 0.8),
        panelStroke: Color(hex: 0xD4AF66, opacity: 0.3),
        accent: Color(hex: 0xD4AF66),
        isDark: true
    )

    static func with(_ id: ThemeID) -> BoardTheme {
        switch id {
        case .house: return .house
        case .tournament: return .tournament
        case .ebony: return .ebony
        case .olive: return .olive
        case .salon: return .salon
        case .walnut: return .walnut
        case .slate: return .slate
        case .marble: return .marble
        case .rosewood: return .rosewood
        case .midnight: return .midnight
        }
    }
}

/// The app's type: San Francisco throughout. Headings are semibold and slightly tight;
/// numbers that change (clocks, counts) use monospaced digits at the call site.
enum Typeface {
    static func display(_ size: CGFloat, bold: Bool = false) -> Font {
        .system(size: size, weight: bold ? .bold : .semibold)
    }

    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Clock digits.
    static func clock(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
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
    /// A taken piece is lifted off and carried to its captor's tray.
    static let toTray = Animation.spring(response: 0.62, dampingFraction: 0.82)
    static let toTrayLanding = 0.5
    static let fromTray = Animation.spring(response: 0.5, dampingFraction: 0.84)
    /// Picking a piece up: a quick, springy rise.
    static let pickup = Animation.spring(response: 0.24, dampingFraction: 0.58)
    static let castleRookDelay = 0.085
    static let fade = Animation.easeOut(duration: 0.16)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
