import SwiftUI

/// The whole window is the board: the playing grid spans its width (portrait) or height
/// (landscape), and the rest of the surface is the board's own frame, where each player
/// keeps their name, a tray for the pieces they have taken, and two pins for controls.
///
/// Only the bottom player's zone is laid out. The top player's zone is the same layer
/// turned 180 degrees about the centre, so it lands at the far end, facing them;
/// `rotated(_:)` maps its points into window coordinates.
struct TableLayout: Equatable {
    enum Arrangement { case ends, sides }

    let size: CGSize
    let safe: EdgeInsets
    let board: CGFloat
    let boardOrigin: CGPoint
    let arrangement: Arrangement
    /// The bottom player's zone, in window coordinates.
    let zone: CGRect
    /// Where captured pieces stand, inside the zone.
    let tray: CGRect
    /// Height of a piece standing in the tray.
    let trayPiece: CGFloat
    let compact: Bool

    static let minEnd: CGFloat = 84

    init(size: CGSize, safeArea: EdgeInsets) {
        self.size = size
        safe = safeArea
        // The board runs edge to edge across the short side.
        let edge: CGFloat = 0
        let portraitish = size.height >= size.width
        arrangement = portraitish ? .ends : .sides
        let side = portraitish ? size.width : size.height
        let long = portraitish ? size.height : size.width
        // The board takes the full short side, unless that would leave the players no room.
        board = floor(min(side - 2 * edge, long - 2 * Self.minEnd))
        boardOrigin = CGPoint(x: (size.width - board) / 2, y: (size.height - board) / 2)

        let inset = max(safeArea.bottom, safeArea.top, 10)
        let sideInset = max(safeArea.leading, safeArea.trailing, 18)
        switch arrangement {
        case .ends:
            let top = boardOrigin.y + board
            zone = CGRect(x: sideInset, y: top + 8, width: size.width - 2 * sideInset,
                          height: max(60, size.height - top - 8 - inset))
            compact = zone.height < 120
            // Captured pieces stand along the left of the strip; the clock and pins take the right.
            let trayH = min(zone.height * 0.7, board / 8 * 0.9)
            let trayW = min(zone.width * 0.5, board * 0.48)
            tray = CGRect(x: zone.minX, y: zone.midY - trayH / 2, width: trayW, height: trayH)
        case .sides:
            let left = boardOrigin.x + board
            zone = CGRect(x: left + 10, y: size.height / 2, width: max(80, size.width - left - 10 - sideInset),
                          height: size.height / 2 - inset)
            compact = zone.width < 170
            let trayW = zone.width
            let trayH = min(zone.height * 0.48, board / 8 * 1.9)
            tray = CGRect(x: zone.minX, y: zone.minY + 8, width: trayW, height: trayH)
        }
        switch arrangement {
        case .ends: trayPiece = min(board / 8 * 0.66, tray.height * 0.95)
        case .sides: trayPiece = min(board / 8 * 0.62, tray.width * 0.42)
        }
    }

    var boardRect: CGRect { CGRect(origin: boardOrigin, size: CGSize(width: board, height: board)) }

    /// A point in the bottom player's layer, as it appears for the top player.
    func rotated(_ p: CGPoint) -> CGPoint { CGPoint(x: size.width - p.x, y: size.height - p.y) }

    /// How many captured pieces stand in a tray at once; earlier ones are counted, not shown.
    var trayCapacity: Int {
        switch arrangement {
        case .ends: return max(3, min(9, Int((tray.width - trayPiece * 0.5) / (trayPiece * 0.56))))
        case .sides: return max(3, min(8, 2 * Int((tray.width - trayPiece * 0.3) / (trayPiece * 0.62))))
        }
    }

    /// How a tray holding `count` pieces is laid out across `slots` places. The most recent
    /// pieces stand from slot `first`; when some are `hidden`, slot 0 holds a "+N" counter.
    func trayWindow(count: Int) -> (slots: Int, first: Int, hidden: Int) {
        let cap = trayCapacity
        if count <= cap { return (count, 0, 0) }
        return (cap, 1, count - (cap - 1))
    }

    /// Where the `index`-th captured piece stands in a tray (bottom player's frame).
    func traySlot(_ index: Int, count: Int) -> CGPoint {
        let s = trayPiece
        switch arrangement {
        case .ends:
            // A row from the left edge of the strip; the tray shows at most `trayCapacity`.
            let step = s * 0.56
            return CGPoint(x: tray.minX + s * 0.5 + step * CGFloat(index), y: tray.midY + s * 0.3)
        case .sides:
            let perRow = max(2, Int((tray.width - s * 0.3) / (s * 0.62)))
            let row = index / perRow, col = index % perRow
            let step = (tray.width - s) / CGFloat(max(perRow - 1, 1))
            return CGPoint(x: tray.minX + s * 0.5 + step * CGFloat(col),
                           y: tray.minY + s * 1.0 + CGFloat(row) * s * 0.7)
        }
    }
}
