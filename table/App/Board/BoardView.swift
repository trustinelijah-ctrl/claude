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
    var active = false
}

/// The playable board. One gesture handles both ways of moving:
/// tap a piece then a square, or press and drag the piece itself.
struct BoardView: View {
    let session: GameSession
    let settings: SettingsStore
    let size: CGFloat
    var revealed: Bool = true

    @State private var grip = Grip()
    @GestureState private var touching = false

    /// Finger travel before a press becomes a drag. Small, so drags feel immediate,
    /// but large enough that a tap with a slight roll stays a tap.
    private let dragThreshold: CGFloat = 5

    var body: some View {
        let g = BoardGeometry(size: size)
        let theme = settings.theme
        ZStack(alignment: .topLeading) {
            BoardSurface(theme: theme, geometry: g, showCoordinates: settings.showCoordinates)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("board")
                .accessibilityLabel("Chessboard")
                .accessibilityValue(accessibilitySummary)

            TurnEdge(theme: theme, geometry: g, side: .bottom,
                     active: !session.isOver && session.sideToMove == .white, nudge: session.turnNudge)
            TurnEdge(theme: theme, geometry: g, side: .top,
                     active: !session.isOver && session.sideToMove == .black, nudge: session.turnNudge)

            BoardMarks(theme: theme, geometry: g,
                       lastMove: session.lastMove,
                       selection: session.selection,
                       targets: Array(session.targets.keys),
                       occupiedTargets: occupiedTargets,
                       hover: grip.isDragging ? grip.hover : nil,
                       checkedKing: session.checkedKing,
                       isMate: isMate,
                       showHints: settings.showMoveHints)

            pieces(g)

            if let p = session.pendingPromotion {
                PromotionPicker(pending: p, geometry: g, theme: theme,
                                facesOpponent: settings.pieceFacing == .eachPlayer && p.color == .black) { kind in
                    session.choosePromotion(kind)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: p.color == .white ? .top : .bottom))
                    .animation(.spring(response: 0.24, dampingFraction: 0.86).delay(0.08)))
                .zIndex(10)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .updating($touching) { _, state, _ in state = true }
                .onChanged { changed($0, g) }
                .onEnded { ended($0, g) }
        )
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
                TokenView(token: token,
                          geometry: g,
                          facesOpponent: settings.pieceFacing == .eachPlayer && token.piece.color == .black,
                          hold: hold(for: token, gripped: isGripped, dragging: dragging),
                          translation: dragging ? grip.translation : .zero,
                          lift: dragging ? g.liftOffset(for: token.piece.color) : .zero,
                          revealed: revealed,
                          shadowStrength: settings.theme.pieceShadow)
                    .zIndex(depth(of: token, dragging: dragging))
            }
        }
        .frame(width: g.size, height: g.size)
        .allowsHitTesting(false)
    }

    /// Pieces nearer their own player are drawn in front, so a tall crown reaching into the
    /// square behind passes behind the piece standing there.
    private func depth(of token: PieceToken, dragging: Bool) -> Double {
        if dragging { return 30 }
        if token.id == session.movingTokenID { return 20 }
        if token.isCaptured { return 0 }
        let towardViewer = settings.pieceFacing == .eachPlayer && token.piece.color == .black
            ? Double(token.square.rank) : Double(7 - token.square.rank)
        return 1 + towardViewer
    }

    private func hold(for token: PieceToken, gripped: Bool, dragging: Bool) -> HoldState {
        if dragging { return .dragging }
        if gripped && grip.active { return .held }
        if session.selection == token.square && !token.isCaptured { return .selected }
        return .resting
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
        } else if session.game.position[sq] != nil, !session.isOver {
            session.touchedOutOfTurn(sq)
        }
    }

    private var accessibilitySummary: String {
        let side = session.sideToMove == .white ? "White" : "Black"
        let last = session.game.lastMove.map { " Last move \($0.san)." } ?? ""
        if let r = session.result { return "\(ResultText.headline(r)).\(last)" }
        return "\(side) to move. \(session.game.history.count) moves played.\(last)"
    }
}

/// The four promotion choices, standing on the file where the pawn arrived and reaching
/// toward the centre of the board, turned to face the player who is promoting.
struct PromotionPicker: View {
    let pending: PendingPromotion
    let geometry: BoardGeometry
    let theme: BoardTheme
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
                        .frame(width: sq * 0.86, height: sq * 0.86)
                        .rotationEffect(facesOpponent ? .degrees(180) : .zero)
                        .frame(width: sq, height: sq)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle())
                .position(x: r.midX, y: r.midY)
                .accessibilityLabel("Promote to \(kind.rawValue)")
            }
        }
        .frame(width: g.size, height: g.size, alignment: .topLeading)
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
