import SwiftUI

/// Responsive arrangement of the board and the two players' panels for any window size.
///
/// The board is always the largest square that leaves each player a usable panel. The
/// panels sit either below/above the board (strips) or beside it (columns), whichever
/// gives the bigger board. Only White's panel is laid out; Black's is the same layer
/// turned 180 degrees about the centre of the window, so it lands on Black's side,
/// facing Black.
struct TableLayout: Equatable {
    enum Arrangement { case strips, columns }

    let size: CGSize
    let margin: CGFloat
    let board: CGFloat
    let arrangement: Arrangement
    /// White's panel, in window coordinates.
    let panel: CGRect
    /// True when the panel has little room and should use its condensed form.
    let compact: Bool

    static let minStrip: CGFloat = 60
    static let minColumn: CGFloat = 128
    static let gap: CGFloat = 14

    init(size: CGSize, safeArea: EdgeInsets) {
        self.size = size
        // Symmetric margins keep the two halves true mirror images of each other.
        let inset = max(safeArea.top, safeArea.bottom, safeArea.leading, safeArea.trailing)
        margin = max(14, inset + 6)

        let asStrips = min(size.width - 2 * margin, size.height - 2 * (margin + Self.minStrip + Self.gap))
        let asColumns = min(size.height - 2 * margin, size.width - 2 * (margin + Self.minColumn + Self.gap))
        arrangement = asColumns > asStrips ? .columns : .strips
        board = max(160, floor(max(asStrips, asColumns)))

        let mid = CGPoint(x: size.width / 2, y: size.height / 2)
        switch arrangement {
        case .strips:
            let top = mid.y + board / 2 + Self.gap
            let height = max(Self.minStrip, size.height - margin - top)
            panel = CGRect(x: mid.x - board / 2, y: top, width: board, height: height)
            compact = height < 92
        case .columns:
            let left = mid.x + board / 2 + Self.gap
            let width = max(Self.minColumn, size.width - margin - left)
            panel = CGRect(x: left, y: mid.y, width: width, height: board / 2)
            compact = width < 170
        }
    }

    var boardCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
}
