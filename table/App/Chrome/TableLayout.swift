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

    static let minEnd: CGFloat = 92

    init(size: CGSize, safeArea: EdgeInsets) {
        self.size = size
        safe = safeArea
        let edge: CGFloat = 4
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
            let trayH = min(zone.height * 0.62, board / 8 * 0.95)
            let trayW = min(zone.width * 0.52, board * 0.5)
            tray = CGRect(x: zone.midX - trayW / 2, y: zone.midY - trayH / 2, width: trayW, height: trayH)
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
        case .ends: trayPiece = min(board / 8 * 0.82, tray.height * 1.05)
        case .sides: trayPiece = min(board / 8 * 0.62, tray.width * 0.42)
        }
    }

    var boardRect: CGRect { CGRect(origin: boardOrigin, size: CGSize(width: board, height: board)) }

    /// A point in the bottom player's layer, as it appears for the top player.
    func rotated(_ p: CGPoint) -> CGPoint { CGPoint(x: size.width - p.x, y: size.height - p.y) }

    /// Where the `index`-th captured piece stands in a tray (bottom player's frame).
    func traySlot(_ index: Int, count: Int) -> CGPoint {
        let s = trayPiece
        switch arrangement {
        case .ends:
            let usable = tray.width - s * 0.6
            let step = min(s * 0.56, count > 1 ? usable / CGFloat(max(count - 1, 1)) : s)
            let span = step * CGFloat(max(count - 1, 0))
            let x0 = tray.midX - span / 2
            return CGPoint(x: x0 + step * CGFloat(index), y: tray.maxY - tray.height * 0.16)
        case .sides:
            let perRow = max(4, Int((tray.width - s * 0.6) / (s * 0.5)) + 1)
            let row = index / perRow, col = index % perRow
            let step = (tray.width - s * 0.7) / CGFloat(max(perRow - 1, 1))
            return CGPoint(x: tray.minX + s * 0.35 + step * CGFloat(col),
                           y: tray.minY + s * 0.55 + CGFloat(row) * s * 0.62)
        }
    }
}
