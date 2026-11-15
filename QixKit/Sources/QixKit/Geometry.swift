// Geometry of the playfield.

/// A corner of a cell: a point of the `(W+1) x (H+1)` lattice the marker, the stix and the Sparx
/// move on.
///
/// Point `(x, y)` is the top-left corner of cell `(x, y)`; `y` grows downwards.
public struct Point: Hashable, Sendable {
    public var x: UInt16
    public var y: UInt16

    /// The lattice point at `(x, y)`.
    public init(x: UInt16, y: UInt16) {
        self.x = x
        self.y = y
    }
}

/// One of the four directions the marker moves in.
public enum Dir: Hashable, Sendable {
    case up
    case down
    case left
    case right

    /// Every direction, in declaration order.
    public static let all: [Self] = [.up, .down, .left, .right]

    /// The direction pointing the other way.
    public var opposite: Self {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }

    /// The lattice point one step from `point` in this direction, or `nil` when the step leaves
    /// the coordinate range.
    ///
    /// The step is not bounded by a board: checking that the result lies on a given board's
    /// lattice is the caller's job.
    public func step(_ point: Point) -> Point? {
        let (x, y) = (point.x, point.y)
        switch self {
        case .up: return y > 0 ? Point(x: x, y: y - 1) : nil
        case .down: return y < .max ? Point(x: x, y: y + 1) : nil
        case .left: return x > 0 ? Point(x: x - 1, y: y) : nil
        case .right: return x < .max ? Point(x: x + 1, y: y) : nil
        }
    }

    /// The direction from `from` straight to `to`, or `nil` when the two are the same point or
    /// share neither a row nor a column.
    public static func between(_ from: Point, _ to: Point) -> Self? {
        if from.x == to.x, from.y > to.y { return .up }
        if from.x == to.x, from.y < to.y { return .down }
        if from.y == to.y, from.x > to.x { return .left }
        if from.y == to.y, from.x < to.x { return .right }
        return nil
    }
}

/// The closed segments from `start` to `end` and from `otherStart` to `otherEnd` share a point:
/// they cross, or one touches the other with an end, or they overlap on a line.
public func segmentsIntersect(_ start: Vec2, _ end: Vec2, _ otherStart: Vec2, _ otherEnd: Vec2) -> Bool {
    let (sideStart, sideEnd) = (orientation(otherStart, otherEnd, start), orientation(otherStart, otherEnd, end))
    let (sideOtherStart, sideOtherEnd) = (orientation(start, end, otherStart), orientation(start, end, otherEnd))
    if oppositeSigns(sideStart, sideEnd), oppositeSigns(sideOtherStart, sideOtherEnd) {
        return true
    }
    return (sideStart == 0 && inBox(otherStart, otherEnd, start))
        || (sideEnd == 0 && inBox(otherStart, otherEnd, end))
        || (sideOtherStart == 0 && inBox(start, end, otherStart))
        || (sideOtherEnd == 0 && inBox(start, end, otherEnd))
}

/// `point` lies inside `triangle` or on one of its sides. A triangle with no area holds no point:
/// its sides, as segments, are the caller's to test.
public func inTriangle(_ point: Vec2, _ triangle: (Vec2, Vec2, Vec2)) -> Bool {
    let (first, second, third) = triangle
    if orientation(first, second, third) == 0 {
        return false
    }
    let sides = [orientation(first, second, point), orientation(second, third, point), orientation(third, first, point)]
    return sides.allSatisfy { $0 >= 0 } || sides.allSatisfy { $0 <= 0 }
}

/// Which side of the line from `from` to `to` `point` lies on: the sign of the cross product, zero
/// on the line.
private func orientation(_ from: Vec2, _ to: Vec2, _ point: Vec2) -> Float {
    (to - from).cross(point - from)
}

/// One of `first` and `second` is positive and the other negative.
private func oppositeSigns(_ first: Float, _ second: Float) -> Bool {
    (first > 0 && second < 0) || (first < 0 && second > 0)
}

/// `point` lies in the bounding box of `from` and `to`, edges included: on the segment, for a
/// point already known to be on its line.
private func inBox(_ from: Vec2, _ to: Vec2, _ point: Vec2) -> Bool {
    Float.minimum(from.x, to.x) <= point.x
        && point.x <= Float.maximum(from.x, to.x)
        && Float.minimum(from.y, to.y) <= point.y
        && point.y <= Float.maximum(from.y, to.y)
}
