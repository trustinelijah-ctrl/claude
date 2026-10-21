import CoreGraphics
import ChessCore

/// Maps between logical squares and points on the table.
///
/// All coordinates are in table space (the whole window). The board sits at `origin`.
/// Normally White's first rank is nearest the bottom edge; against the computer, the
/// board is `flipped` when the person plays Black so their pieces are always nearest them.
struct BoardGeometry: Equatable {
    let origin: CGPoint
    let size: CGFloat
    /// Width of the board's own rim around the squares, where coordinates are engraved.
    let rim: CGFloat
    let inner: CGFloat
    let square: CGFloat
    let flipped: Bool

    init(origin: CGPoint = .zero, size: CGFloat, flipped: Bool = false) {
        self.origin = origin
        self.size = size
        self.flipped = flipped
        // A thin gilt edge: the squares take nearly all of the board.
        rim = max(5, (size * 0.012).rounded())
        inner = size - 2 * rim
        square = inner / 8
    }

    var frame: CGRect { CGRect(origin: origin, size: CGSize(width: size, height: size)) }
    var innerRect: CGRect { CGRect(x: origin.x + rim, y: origin.y + rim, width: inner, height: inner) }
    var center: CGPoint { CGPoint(x: origin.x + size / 2, y: origin.y + size / 2) }

    /// Column and row on screen (0 = left / top) of a square.
    private func cell(_ s: Square) -> (col: Int, row: Int) {
        flipped ? (7 - s.file, s.rank) : (s.file, 7 - s.rank)
    }

    func center(_ s: Square) -> CGPoint {
        let c = cell(s)
        return CGPoint(x: origin.x + rim + (CGFloat(c.col) + 0.5) * square,
                       y: origin.y + rim + (CGFloat(c.row) + 0.5) * square)
    }

    func rect(_ s: Square) -> CGRect {
        let c = cell(s)
        return CGRect(x: origin.x + rim + CGFloat(c.col) * square, y: origin.y + rim + CGFloat(c.row) * square,
                      width: square, height: square)
    }

    func square(at p: CGPoint) -> Square? {
        let col = Int(((p.x - origin.x - rim) / square).rounded(.down))
        let row = Int(((p.y - origin.y - rim) / square).rounded(.down))
        guard (0..<8).contains(col), (0..<8).contains(row) else { return nil }
        return flipped ? Square(file: 7 - col, rank: row) : Square(file: col, rank: 7 - row)
    }

    /// The colour of the player sitting at the bottom edge of the screen.
    var bottomColor: PieceColor { flipped ? .black : .white }

    /// Where a lifted piece floats relative to the finger, so the finger does not hide it.
    /// Each player's "up" points away from their own edge of the table.
    func liftOffset(for color: PieceColor) -> CGSize {
        CGSize(width: 0, height: (color == bottomColor ? -1 : 1) * square * 0.34)
    }
}
