import CoreGraphics
import QixKit

/// Where the touch controls sit and how they look: the stick in the zone left of the board and the
/// Slow button in the zone right of it, swapped when left-handed, each the full height of the
/// screen less a clearance from its edges, where the system's gestures start, and clear of the
/// board; the stick at the size and the controls at the opacity the settings choose. Following the
/// finger, the board is the steering's zone and there is no stick.
struct ControlsLayout: Equatable {
    /// Gap between a zone and the edges of the safe area, in points: a thumb in a zone does not
    /// start a system gesture.
    static let edgeClearance: CGFloat = 16
    /// Gap between a zone and the board, in points.
    static let boardGap: CGFloat = 8

    /// The radius of the stick's base at its standard size, in points: how far from its centre the
    /// knob goes.
    static let standardBaseRadius: CGFloat = 44
    /// The radius of the stick's knob at its standard size, in points.
    static let standardKnobRadius: CGFloat = 22
    /// The radius of the Slow button, in points.
    static let slowRadius: CGFloat = 36
    /// The size of the Slow button's label, as a fraction of its radius.
    static let slowLabelShare: CGFloat = 0.45
    /// The width of the outlines, in points.
    static let lineWidth: CGFloat = 2
    /// The radius of the ring the steering's target is drawn as, in points: about the marker's
    /// size, so it shows around the marker on it.
    static let cursorRadius: CGFloat = 8
    /// The width of the target's ring, in points.
    static let cursorWidth: CGFloat = 1.5

    /// The opacity of a control while not touched, as a fraction of its opacity while touched.
    static let idleShare: Double = 0.35
    /// The opacity of the stick's base fill, as a fraction of its outline's.
    static let baseFillShare: Double = 0.3

    /// The stick's zone, empty when the board leaves no room on its side or the finger steers.
    let stick: CGRect
    /// The board's zone, where a finger steers, empty unless the finger steers.
    let board: CGRect
    /// The Slow button's zone, empty when the board leaves no room on its side.
    let slow: CGRect
    /// The radius of the stick's base, in points.
    let baseRadius: CGFloat
    /// The radius of the stick's knob, in points.
    let knobRadius: CGFloat
    /// The opacity of a control while touched.
    let touchedOpacity: Double

    /// The zones in `available`, the safe area, on each side of `field`, the board, with the
    /// stick and the opacity of `settings`.
    init(in available: CGRect, beside field: CGRect, settings: Settings = Settings()) {
        let top = available.minY + Self.edgeClearance
        let height = max(available.height - 2 * Self.edgeClearance, 0)
        let leftX = available.minX + Self.edgeClearance
        let rightX = field.maxX + Self.boardGap
        let left = CGRect(x: leftX, y: top, width: max(field.minX - Self.boardGap - leftX, 0), height: height)
        let right = CGRect(
            x: rightX, y: top, width: max(available.maxX - Self.edgeClearance - rightX, 0), height: height
        )
        let followsTheFinger = settings.controlScheme == .followTheFinger
        stick = followsTheFinger ? .zero : (settings.leftHanded ? right : left)
        board = followsTheFinger ? field : .zero
        slow = settings.leftHanded ? left : right
        let scale = CGFloat(settings.stickSize.get)
        baseRadius = Self.standardBaseRadius * scale
        knobRadius = Self.standardKnobRadius * scale
        touchedOpacity = Double(settings.controlsOpacity.get)
    }

    /// The opacity of a control while not touched.
    var idleOpacity: Double {
        touchedOpacity * Self.idleShare
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
    func knob(centre: CGPoint, thumb: CGPoint) -> CGPoint {
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
