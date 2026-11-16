import CoreGraphics
import QixKit

/// Where the playfield and the HUD above it sit on the screen: qix-rs's `playfield::letterbox`, in
/// playfield units of one cell each.
struct PlayfieldLayout: Equatable {
    /// Gap between the edge of the safe area and the playfield and HUD, in points.
    static let margin: CGFloat = 8

    /// The board's size, in playfield units.
    static let boardWidth = CGFloat(Tuning.boardW)
    static let boardHeight = CGFloat(Tuning.boardH)

    /// Height of the HUD's strip above the board, in playfield units: qix-rs's `hud::HEIGHT`.
    static let hudHeight: CGFloat = 12

    /// The width of the board over the height of the board and the HUD.
    static let aspectRatio = boardWidth / (boardHeight + hudHeight)

    /// The board, on screen.
    let field: CGRect
    /// The HUD's strip, right above the board and as wide as it.
    let hud: CGRect

    /// The board and the HUD as large as they fit in `available` less the margins, centred in it.
    init(in available: CGRect) {
        let window = Self.letterbox(in: available)
        let hudHeight = window.height * Self.hudHeight / (Self.boardHeight + Self.hudHeight)
        hud = CGRect(x: window.minX, y: window.minY, width: window.width, height: hudHeight)
        field = CGRect(x: window.minX, y: hud.maxY, width: window.width, height: window.height - hudHeight)
    }

    /// Points per playfield unit.
    var scale: CGFloat {
        field.width / Self.boardWidth
    }

    /// Where the board is, for the touches aiming at it.
    var boardFrame: BoardFrame {
        BoardFrame(origin: Vec2(field.origin), pointsPerCell: Float(scale))
    }

    /// The screen position of lattice point `point`.
    func position(_ point: Point) -> CGPoint {
        position(x: CGFloat(point.x), y: CGFloat(point.y))
    }

    /// The cells `run` covers, on screen.
    func rect(of run: CellRun) -> CGRect {
        let topLeft = position(x: CGFloat(run.cols.lowerBound), y: CGFloat(run.row))
        let bottomRight = position(x: CGFloat(run.cols.upperBound), y: CGFloat(run.row) + 1)
        return CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
    }

    /// The screen position of `vector`, in playfield units.
    func position(_ vector: Vec2) -> CGPoint {
        position(x: CGFloat(vector.x), y: CGFloat(vector.y))
    }

    private func position(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: field.minX + x * scale, y: field.minY + y * scale)
    }

    /// The largest rectangle with `aspectRatio` that fits in `available` less `margin` on every
    /// side, centred in it; empty, at the centre of `available`, when the margins leave no room.
    static func letterbox(in available: CGRect, aspectRatio: CGFloat = aspectRatio) -> CGRect {
        let inner = available.insetBy(dx: margin, dy: margin)
        let centre = CGPoint(x: available.midX, y: available.midY)
        guard !inner.isNull, inner.width > 0, inner.height > 0 else {
            return CGRect(origin: centre, size: .zero)
        }
        let width = min(inner.width, inner.height * aspectRatio)
        let size = CGSize(width: width, height: width / aspectRatio)
        return CGRect(origin: CGPoint(x: centre.x - size.width / 2, y: centre.y - size.height / 2), size: size)
    }
}
