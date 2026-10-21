// Core value types shared by the rules engine and the app.

public enum PieceColor: String, Codable, CaseIterable, Sendable {
    case white, black

    public var opposite: PieceColor { self == .white ? .black : .white }

    /// Direction pawns of this colour advance in rank terms.
    var forward: Int { self == .white ? 1 : -1 }
    var homeRank: Int { self == .white ? 0 : 7 }
    var pawnStartRank: Int { self == .white ? 1 : 6 }
    var promotionRank: Int { self == .white ? 7 : 0 }
}

public enum PieceKind: String, Codable, CaseIterable, Sendable {
    case pawn, knight, bishop, rook, queen, king

    public static let promotionChoices: [PieceKind] = [.queen, .rook, .bishop, .knight]

    /// Conventional material value, used for the captured-material balance.
    public var value: Int {
        switch self {
        case .pawn: return 1
        case .knight, .bishop: return 3
        case .rook: return 5
        case .queen: return 9
        case .king: return 0
        }
    }

    var fenLetter: Character {
        switch self {
        case .pawn: return "p"
        case .knight: return "n"
        case .bishop: return "b"
        case .rook: return "r"
        case .queen: return "q"
        case .king: return "k"
        }
    }

    var sanLetter: String {
        self == .pawn ? "" : String(fenLetter).uppercased()
    }

    init?(fenLetter: Character) {
        switch fenLetter.lowercased() {
        case "p": self = .pawn
        case "n": self = .knight
        case "b": self = .bishop
        case "r": self = .rook
        case "q": self = .queen
        case "k": self = .king
        default: return nil
        }
    }
}

public struct Piece: Codable, Hashable, Sendable {
    public let color: PieceColor
    public let kind: PieceKind

    public init(_ color: PieceColor, _ kind: PieceKind) {
        self.color = color
        self.kind = kind
    }

    var fenLetter: Character {
        color == .white ? Character(String(kind.fenLetter).uppercased()) : kind.fenLetter
    }
}

/// A board square. File 0 is the a-file, rank 0 is the first rank (white's home rank).
public struct Square: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public let file: Int
    public let rank: Int

    public init(file: Int, rank: Int) {
        precondition((0..<8).contains(file) && (0..<8).contains(rank), "Square out of range")
        self.file = file
        self.rank = rank
    }

    public init(index: Int) {
        self.init(file: index % 8, rank: index / 8)
    }

    /// Parses algebraic notation such as "e4".
    public init?(_ name: String) {
        let chars = Array(name.lowercased())
        guard chars.count == 2,
              let f = chars[0].asciiValue, let r = chars[1].asciiValue,
              (97...104).contains(f), (49...56).contains(r) else { return nil }
        self.init(file: Int(f) - 97, rank: Int(r) - 49)
    }

    public var index: Int { rank * 8 + file }
    public var isLight: Bool { (file + rank) % 2 == 1 }

    public var name: String {
        let files = Array("abcdefgh")
        return "\(files[file])\(rank + 1)"
    }

    public var description: String { name }

    public func offset(file df: Int, rank dr: Int) -> Square? {
        let f = file + df, r = rank + dr
        guard (0..<8).contains(f), (0..<8).contains(r) else { return nil }
        return Square(file: f, rank: r)
    }

    public static func < (lhs: Square, rhs: Square) -> Bool { lhs.index < rhs.index }

    public static let all: [Square] = (0..<64).map(Square.init(index:))
}

public struct Move: Hashable, Codable, Sendable, CustomStringConvertible {
    public let from: Square
    public let to: Square
    public let promotion: PieceKind?

    public init(from: Square, to: Square, promotion: PieceKind? = nil) {
        self.from = from
        self.to = to
        self.promotion = promotion
    }

    /// Long algebraic (UCI-style) notation, e.g. "e7e8q".
    public var description: String {
        from.name + to.name + (promotion.map { String($0.fenLetter) } ?? "")
    }

    public init?(uci: String) {
        let s = Array(uci)
        guard s.count == 4 || s.count == 5,
              let from = Square(String(s[0...1])),
              let to = Square(String(s[2...3])) else { return nil }
        var promo: PieceKind?
        if s.count == 5 {
            guard let k = PieceKind(fenLetter: s[4]), PieceKind.promotionChoices.contains(k) else { return nil }
            promo = k
        }
        self.init(from: from, to: to, promotion: promo)
    }
}

public struct CastlingRights: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let whiteKingside = CastlingRights(rawValue: 1)
    public static let whiteQueenside = CastlingRights(rawValue: 2)
    public static let blackKingside = CastlingRights(rawValue: 4)
    public static let blackQueenside = CastlingRights(rawValue: 8)
    public static let all: CastlingRights = [.whiteKingside, .whiteQueenside, .blackKingside, .blackQueenside]

    static func kingside(_ c: PieceColor) -> CastlingRights { c == .white ? .whiteKingside : .blackKingside }
    static func queenside(_ c: PieceColor) -> CastlingRights { c == .white ? .whiteQueenside : .blackQueenside }
}
