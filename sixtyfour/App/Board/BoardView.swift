import SwiftUI
import ChessCore

/// Touch state for the piece under a finger.
private struct Grip: Equatable {
    var tokenID: Int?
    var origin: Square?
    var color: PieceColor = .white
    var wasSelected = false
    var isDragging = false
    var translation: CGSize = .zero
    var hover: Square?
    /// Swing of the carried piece, in degrees, from how fast the finger is moving.
    var tilt: Double = 0
    var active = false
}

/// The table top: the board, its marks, every piece (on the board or standing in a tray),
/// and the one gesture that handles both ways of moving: tap a piece then a square, or
/// press and drag the piece itself. Everything is laid out in window coordinates.
struct BoardView: View {
    let session: GameSession
    let settings: SettingsStore
    let layout: TableLayout
    var revealed: Bool = true

    @State private var grip = Grip()
    @GestureState private var touching = false

    /// Finger travel before a press becomes a drag. Small, so drags feel immediate,
    /// but large enough that a tap with a slight roll stays a tap.
    private let dragThreshold: CGFloat = 5

    private var geometry: BoardGeometry {
        BoardGeometry(origin: layout.boardOrigin, size: layout.board, flipped: settings.boardFlipped)
    }

    var body: some View {
        let g = geometry
        let theme = settings.theme
        ZStack(alignment: .topLeading) {
            // The board itself, in its own coordinates, set into the table.
            ZStack(alignment: .topLeading) {
                BoardSurface(theme: theme, geometry: BoardGeometry(size: g.size, flipped: g.flipped),
                             showCoordinates: settings.showCoordinates,
                             mirrorCoordinates: !settings.isAgainstComputer)
                TurnEdge(theme: theme, geometry: BoardGeometry(size: g.size), side: .bottom,
                         active: !session.isOver && session.sideToMove == g.bottomColor, nudge: session.turnNudge)
                TurnEdge(theme: theme, geometry: BoardGeometry(size: g.size), side: .top,
                         active: !session.isOver && session.sideToMove != g.bottomColor, nudge: session.turnNudge)
            }
            .frame(width: g.size, height: g.size)
            .offset(x: g.origin.x, y: g.origin.y)
            .accessibilityHidden(true)

            BoardMarks(theme: theme, geometry: g, size: layout.size,
                       lastMove: session.lastMove,
                       selection: session.selection,
                       targets: Array(session.targets.keys),
                       occupiedTargets: occupiedTargets,
                       hover: grip.isDragging ? grip.hover : nil,
                       held: grip.active && grip.tokenID != nil ? grip.origin : nil,
                       checkedKing: session.checkedKing,
                       isMate: isMate,
                       showHints: settings.showMoveHints,
                       hint: session.hint)
                .animation(.easeInOut(duration: 0.25), value: session.hint)

            RippleLayer(ripples: session.ripples, geometry: g, theme: theme)

            pieces(g)

            if let p = session.pendingPromotion {
                PromotionPicker(pending: p, geometry: g, theme: theme, size: layout.size,
                                facesOpponent: settings.turnsTopPieces && p.color != g.bottomColor) { kind in
                    session.choosePromotion(kind)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: p.color == g.bottomColor ? .top : .bottom))
                    .animation(.spring(response: 0.24, dampingFraction: 0.86).delay(0.08)))
                .zIndex(10)
            }

            // Touch surface over the board, and the board as one accessibility element.
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: g.size, height: g.size)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("table"))
                        .updating($touching) { _, state, _ in state = true }
                        .onChanged { changed($0, g) }
                        .onEnded { ended($0, g) }
                )
                .accessibilityElement()
                .accessibilityIdentifier("board")
                .accessibilityLabel("Chessboard")
                .accessibilityValue(accessibilitySummary)
                .position(x: g.center.x, y: g.center.y)
                .zIndex(session.pendingPromotion == nil ? 5 : 1)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .coordinateSpace(name: "table")
        .onChange(of: touching) { _, isTouching in
            // A touch cancelled by the system never reaches onEnded; put the piece back.
            if !isTouching && grip.active {
                Task { @MainActor in
                    guard grip.active, !touching else { return }
                    if let id = grip.tokenID { session.settleBack(id) }
                    grip = Grip()
                }
            }
        }
    }

    // MARK: Pieces

    private func pieces(_ g: BoardGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(session.tokens) { token in
                let isGripped = grip.tokenID == token.id
                let dragging = isGripped && grip.isDragging
                let place = placement(of: token, g)
                TokenView(token: token,
                          position: place.point,
                          size: place.size,
                          rotated: place.rotated,
                          hold: hold(for: token, gripped: isGripped, dragging: dragging),
                          translation: dragging ? grip.translation : .zero,
                          lift: dragging ? g.liftOffset(for: token.piece.color) : .zero,
                          tilt: dragging ? grip.tilt : 0,
                          light: CGSize(width: (place.point.x - g.center.x) / g.inner,
                                        height: (place.point.y - g.center.y) / g.inner),
                          revealed: revealed && !isTucked(token),
                          shadowStrength: settings.theme.pieceShadow,
                          fallen: !token.isCaptured && token.piece == Piece(session.fallenKing ?? .white, .king)
                              && session.fallenKing != nil)
                    .equatable()
                    .zIndex(depth(of: token, dragging: dragging))
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where a token stands: on its square, or in the tray of the player who took it.
    private func placement(of token: PieceToken, _ g: BoardGeometry) -> (point: CGPoint, size: CGFloat, rotated: Bool) {
        if token.isCaptured, let owner = token.capturedBy {
            // Only the most recent captures stand in the tray; earlier ones fold into the counter.
            let count = max(session.trayCount(owner), token.trayIndex + 1)
            let w = layout.trayWindow(count: count)
            let index = max(0, token.trayIndex - w.hidden + w.first)
            let slot = layout.traySlot(index, count: w.slots)
            // The sprite's base sits low in its frame; centre the frame so the base meets the slot.
            let size = layout.trayPiece
            let baseShift = size * (PieceSprite.squareBase - 0.5)
            let local = CGPoint(x: slot.x, y: slot.y - baseShift)
            if owner == g.bottomColor {
                return (local, size, false)
            }
            // The far tray; its pieces face the far player only when someone sits there.
            return (layout.rotated(local), size, settings.turnsTopPieces)
        }
        return (g.center(token.square), g.square, settings.turnsTopPieces && token.piece.color != g.bottomColor)
    }

    /// A captured piece older than what the tray shows.
    private func isTucked(_ token: PieceToken) -> Bool {
        guard token.isCaptured, let owner = token.capturedBy else { return false }
        let count = max(session.trayCount(owner), token.trayIndex + 1)
        return token.trayIndex < layout.trayWindow(count: count).hidden
    }

    private func hold(for token: PieceToken, gripped: Bool, dragging: Bool) -> HoldState {
        if token.isCaptured { return .resting }
        if dragging { return .dragging }
        if token.id == session.ghostLiftID { return .carried }
        if gripped && grip.active { return .held }
        if session.selection == token.square { return .selected }
        return .resting
    }

    /// Pieces nearer their own player are drawn in front, so a tall crown reaching into the
    /// square behind passes behind the piece standing there.
    private func depth(of token: PieceToken, dragging: Bool) -> Double {
        if dragging || token.id == session.ghostLiftID { return 30 }
        if token.id == session.movingTokenID { return 20 }
        if token.isCaptured { return 0.5 + Double(token.trayIndex) * 0.01 }
        let g = geometry
        let row = g.center(token.square).y
        let facesTop = settings.turnsTopPieces && token.piece.color != g.bottomColor
        return 1 + (facesTop ? (g.frame.maxY - row) : row) / g.size
    }

    private var occupiedTargets: Set<Square> {
        Set(session.targets.keys.filter { session.game.position[$0] != nil || isEnPassant($0) })
    }

    private func isEnPassant(_ sq: Square) -> Bool {
        guard let sel = session.selection, session.game.position[sel]?.kind == .pawn else { return false }
        return session.game.position.enPassant == sq
    }

    private var isMate: Bool {
        if case .checkmate = session.result { return true }
        return false
    }

    // MARK: Gesture

    private func changed(_ value: DragGesture.Value, _ g: BoardGeometry) {
        if !grip.active {
            grip.active = true
            guard session.pendingPromotion == nil else { return }
            if let sq = g.square(at: value.startLocation), session.canPickUp(sq), let t = session.token(at: sq) {
                grip.tokenID = t.id
                grip.origin = sq
                grip.color = t.piece.color
                grip.wasSelected = session.selection == sq
                if !grip.wasSelected {
                    session.select(sq)
                    session.feedback.pickup(at: sq)
                }
            }
        }
        guard let origin = grip.origin, grip.tokenID != nil else { return }
        let t = value.translation
        if !grip.isDragging, hypot(t.width, t.height) > dragThreshold, let id = grip.tokenID {
            grip.isDragging = true
            session.beginDrag(id)
        }
        if grip.isDragging {
            grip.translation = t
            // The piece swings with the hand's motion, like an object held near its top.
            grip.tilt = max(-13, min(13, Double(value.velocity.width) * 0.011))
            let c = g.center(origin)
            let lift = g.liftOffset(for: grip.color)
            grip.hover = g.square(at: CGPoint(x: c.x + t.width + lift.width, y: c.y + t.height + lift.height))
        }
    }

    private func ended(_ value: DragGesture.Value, _ g: BoardGeometry) {
        let state = grip
        defer { grip = Grip() }

        if session.pendingPromotion != nil {
            session.cancelPromotion()
            return
        }

        if let id = state.tokenID, let origin = state.origin {
            if state.isDragging {
                if let target = state.hover, target != origin {
                    session.move(from: origin, to: target, dragged: true)
                } else {
                    session.settleBack(id)
                    if state.hover == nil { session.feedback.invalid(at: origin) } else { session.feedback.putBack(at: origin) }
                }
            } else if state.wasSelected {
                session.clearSelection()
            }
            return
        }

        // A tap that did not land on a movable piece.
        guard let sq = g.square(at: value.location) ?? g.square(at: value.startLocation) else {
            session.clearSelection()
            return
        }
        if let sel = session.selection {
            if session.targets[sq] != nil {
                session.move(from: sel, to: sq, dragged: false)
            } else {
                session.clearSelection()
                if session.game.position[sq] != nil { session.feedback.invalid(at: sq) }
            }
        } else if session.game.position[sq] != nil, !session.isOver, !session.isComputerTurn {
            session.touchedOutOfTurn(sq)
        }
    }

    private var accessibilitySummary: String {
        let side = session.sideToMove == .white ? "White" : "Black"
        let last = session.game.lastMove.map { " Last move \($0.san)." } ?? ""
        if let r = session.result { return "\(ResultText.headline(r)).\(last)" }
        let selected = session.selection.map { " Selected \($0.name)." } ?? ""
        return "\(side) to move. \(session.game.history.count) moves played.\(last)\(selected)"
    }
}

/// Rings of light where a piece is lifted, lands, or takes another.
struct RippleLayer: View {
    let ripples: [Ripple]
    let geometry: BoardGeometry
    let theme: BoardTheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(ripples) { r in
                RippleView(style: r.style, square: geometry.square, color: theme.turnGlow)
                    .position(geometry.center(r.square))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct RippleView: View {
    let style: Ripple.Style
    let square: CGFloat
    let color: Color
    @State private var open = false

    var body: some View {
        let strength: Double = style == .capture ? 0.75 : (style == .land ? 0.5 : 0.4)
        let reach: CGFloat = style == .capture ? 1.35 : (style == .land ? 1.05 : 0.9)
        ZStack {
            Circle()
                .strokeBorder(color.opacity(strength), lineWidth: max(1.5, square * (style == .capture ? 0.05 : 0.03)))
            if style != .pickup {
                Circle().fill(RadialGradient(colors: [color.opacity(strength * 0.35), .clear],
                                             center: .center, startRadius: 0, endRadius: square * 0.5))
            }
        }
        .frame(width: square, height: square)
        .scaleEffect(open ? reach : 0.35)
        .opacity(open ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: style == .pickup ? 0.45 : 0.6)) { open = true }
        }
    }
}

/// The four promotion choices, standing on the file where the pawn arrived and reaching
/// toward the centre of the board, turned to face the player who is promoting.
struct PromotionPicker: View {
    let pending: PendingPromotion
    let geometry: BoardGeometry
    let theme: BoardTheme
    let size: CGSize
    let facesOpponent: Bool
    let choose: (PieceKind) -> Void

    var body: some View {
        let g = geometry
        let sq = g.square
        let towardCenter = pending.color == .white ? -1 : 1   // in rank terms
        let squares = (0..<4).map { Square(file: pending.to.file, rank: pending.to.rank + towardCenter * $0) }
        let rects = squares.map(g.rect)
        let frame = rects.reduce(rects[0]) { $0.union($1) }.insetBy(dx: sq * 0.04, dy: sq * 0.04)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: sq * 0.16, style: .continuous)
                .fill(theme.isDark ? Color(hex: 0x1F1813) : Color(hex: 0xF7F3EC))
                .overlay(
                    RoundedRectangle(cornerRadius: sq * 0.16, style: .continuous)
                        .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: sq * 0.18, y: sq * 0.06)
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)

            ForEach(0..<4, id: \.self) { i in
                let kind = PieceKind.promotionChoices[i]
                let r = g.rect(squares[i])
                Button {
                    choose(kind)
                } label: {
                    PieceGlyph(piece: Piece(pending.color, kind))
                        .frame(width: sq * 0.92, height: sq * 0.92)
                        .rotationEffect(facesOpponent ? .degrees(180) : .zero)
                        .frame(width: sq, height: sq)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle())
                .position(x: r.midX, y: r.midY)
                .accessibilityLabel("Promote to \(kind.rawValue)")
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// A button that responds to touch like a small physical object: it gives slightly under the finger.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
