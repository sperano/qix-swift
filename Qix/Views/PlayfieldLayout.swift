import CoreGraphics
import QixKit

/// Where the playfield sits on the screen: qix-rs's `playfield::letterbox`, without the HUD yet.
enum PlayfieldLayout {
    /// Gap between the edge of the safe area and the playfield, in points.
    static let margin: CGFloat = 8

    /// Width of the playfield's border line, in points, drawn inside the playfield.
    static let borderWidth: CGFloat = 2

    /// The board's width over its height.
    static let aspectRatio = CGFloat(BoardSize.standard.aspectRatio)

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
