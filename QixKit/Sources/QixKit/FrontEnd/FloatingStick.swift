// The touch screen's floating stick, which a thumb steers with: the left one, unless left-handed.
// qix-rs has no touch controls: this is the iPhone front end's own.

/// A 4-way stick centred where the thumb lands: the dominant axis of the drag from there holds the
/// direction, once the drag reaches `deadZone`. Changing axis takes a clear move, the other axis
/// leading the held one by `axisSwitchRatio`, so a thumb on a diagonal holds one direction instead
/// of flickering between two. Lifting the thumb holds no direction.
///
/// Positions are in the screen's points, y down, as touches report them.
public struct FloatingStick: Equatable, Sendable {
    /// How far from the centre a drag must reach to hold a direction, in points: a resting thumb
    /// holds none.
    public static let deadZone: Float = 12

    /// How many times the drag along the held direction's axis the drag along the other one must
    /// be to switch to it: about 56° off the held axis, where a diagonal is 45°.
    public static let axisSwitchRatio: Float = 1.5

    /// Where the thumb landed, `nil` while the stick is not touched.
    public private(set) var centre: Vec2?
    /// Where the thumb is now, `nil` while the stick is not touched.
    public private(set) var thumb: Vec2?
    /// The direction held.
    public private(set) var dir: Dir?

    /// Not touched.
    public init() {}

    public var isTouched: Bool {
        centre != nil
    }

    /// The thumb lands at `point`, the stick's centre: no direction yet.
    public mutating func touchDown(at point: Vec2) {
        centre = point
        thumb = point
        dir = nil
    }

    /// The thumb moves to `point`; nothing happens while the stick is not touched.
    public mutating func move(to point: Vec2) {
        guard let centre else { return }
        thumb = point
        dir = Self.dir(of: point - centre, holding: dir)
    }

    /// The thumb lifts: no direction.
    public mutating func lift() {
        self = Self()
    }

    /// The direction a drag of `offset` from the centre holds after `held`: none inside
    /// `deadZone`; along the held direction's axis until the other axis leads by
    /// `axisSwitchRatio`; with no direction held, along the dominant axis, none at a tie.
    public static func dir(of offset: Vec2, holding held: Dir?) -> Dir? {
        guard offset.length >= deadZone else { return nil }
        let (across, along) = (abs(offset.x), abs(offset.y))
        let horizontal: Bool
        switch held {
        case .left, .right:
            horizontal = along <= across * axisSwitchRatio
        case .up, .down:
            horizontal = across > along * axisSwitchRatio
        case nil:
            guard across != along else { return nil }
            horizontal = across > along
        }
        if horizontal {
            return offset.x > 0 ? .right : .left
        }
        return offset.y > 0 ? .down : .up
    }
}
