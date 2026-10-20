import CoreGraphics
import ChessCore

/// Maps between logical squares and points on a board of a given size.
/// White's first rank is always at the bottom; the board never flips.
struct BoardGeometry: Equatable {
    let size: CGFloat
    /// Width of the frame around the playing surface.
    let rim: CGFloat
    let inner: CGFloat
    let square: CGFloat

    init(size: CGFloat) {
        self.size = size
        rim = max(10, (size * 0.036).rounded())
        inner = size - 2 * rim
        square = inner / 8
    }

    var innerRect: CGRect { CGRect(x: rim, y: rim, width: inner, height: inner) }

    func center(_ s: Square) -> CGPoint {
        CGPoint(x: rim + (CGFloat(s.file) + 0.5) * square,
                y: rim + (CGFloat(7 - s.rank) + 0.5) * square)
    }

    func rect(_ s: Square) -> CGRect {
        CGRect(x: rim + CGFloat(s.file) * square, y: rim + CGFloat(7 - s.rank) * square,
               width: square, height: square)
    }

    func square(at p: CGPoint) -> Square? {
        let f = Int(((p.x - rim) / square).rounded(.down))
        let r = 7 - Int(((p.y - rim) / square).rounded(.down))
        guard (0..<8).contains(f), (0..<8).contains(r) else { return nil }
        return Square(file: f, rank: r)
    }

    /// Where a lifted piece floats relative to the finger, so the finger does not hide it.
    /// Each player's "up" points away from their own edge of the table.
    func liftOffset(for color: PieceColor) -> CGSize {
        CGSize(width: 0, height: (color == .white ? -1 : 1) * square * 0.34)
    }
}
