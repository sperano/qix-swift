import CoreGraphics
import QixKit

/// Where the touch controls sit: the stick in the zone left of the board, the Slow button in the
/// zone right of it, each the full height of the screen less a clearance from its edges, where the
/// system's gestures start, and clear of the board. Size and opacity become settings in a later
/// step.
struct ControlsLayout: Equatable {
    /// Gap between a zone and the edges of the safe area, in points: a thumb in a zone does not
    /// start a system gesture.
    static let edgeClearance: CGFloat = 16
    /// Gap between a zone and the board, in points.
    static let boardGap: CGFloat = 8

    /// The radius of the stick's base, in points: how far from its centre the knob goes.
    static let baseRadius: CGFloat = 44
    /// The radius of the stick's knob, in points.
    static let knobRadius: CGFloat = 22
    /// The radius of the Slow button, in points.
    static let slowRadius: CGFloat = 36
    /// The size of the Slow button's label, as a fraction of its radius.
    static let slowLabelShare: CGFloat = 0.45
    /// The width of the outlines, in points.
    static let lineWidth: CGFloat = 2

    /// The opacity of a control while touched.
    static let touchedOpacity: Double = 0.7
    /// The opacity of a control while not touched.
    static let idleOpacity: Double = 0.25
    /// The opacity of the stick's base fill, as a fraction of its outline's.
    static let baseFillShare: Double = 0.3

    /// The stick's zone, empty when the board leaves no room left of it.
    let stick: CGRect
    /// The Slow button's zone, empty when the board leaves no room right of it.
    let slow: CGRect

    /// The zones in `available`, the safe area, on each side of `field`, the board.
    init(in available: CGRect, beside field: CGRect) {
        let top = available.minY + Self.edgeClearance
        let height = max(available.height - 2 * Self.edgeClearance, 0)
        let stickLeft = available.minX + Self.edgeClearance
        let slowLeft = field.maxX + Self.boardGap
        stick = CGRect(x: stickLeft, y: top, width: max(field.minX - Self.boardGap - stickLeft, 0), height: height)
        slow = CGRect(
            x: slowLeft, y: top, width: max(available.maxX - Self.edgeClearance - slowLeft, 0), height: height
        )
    }

    /// Where the stick is drawn while not touched: the middle of its zone.
    var stickRest: CGPoint {
        CGPoint(x: stick.midX, y: stick.midY)
    }

    /// Where the Slow button is drawn: the middle of its zone, all of which takes its touches.
    var slowCentre: CGPoint {
        CGPoint(x: slow.midX, y: slow.midY)
    }

    /// Where the knob is drawn for a thumb at `thumb` on a stick centred at `centre`: under the
    /// thumb, or on the base's rim towards it when the thumb is beyond it.
    static func knob(centre: CGPoint, thumb: CGPoint) -> CGPoint {
        let (dx, dy) = (thumb.x - centre.x, thumb.y - centre.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > baseRadius else { return thumb }
        let scale = baseRadius / distance
        return CGPoint(x: centre.x + dx * scale, y: centre.y + dy * scale)
    }
}

extension CGPoint {
    /// `vector`, in points.
    init(_ vector: Vec2) {
        self.init(x: CGFloat(vector.x), y: CGFloat(vector.y))
    }
}

extension Vec2 {
    /// `point`, in points.
    init(_ point: CGPoint) {
        self.init(x: Float(point.x), y: Float(point.y))
    }
}
