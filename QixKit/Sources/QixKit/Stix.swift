// The stix: the line the marker draws into free space, and the moves that may extend it.

/// A stix: a polyline of lattice points from where it left the border to the marker, with the
/// button that drew each segment.
///
/// Segments are straight, axis-aligned runs between consecutive points; `kinds[i]` is the kind of
/// the segment from `points[i]` to `points[i + 1]`. A step in the head segment's direction with
/// the same button lengthens that segment instead of starting a new one.
public struct Stix: Equatable, Sendable {
    /// The polyline's points, from the start to the head.
    public private(set) var points: [Point]
    /// The draw kind of each segment, from the start to the head.
    public private(set) var kinds: [DrawKind] = []

    /// A stix leaving the border at `start`, with no segment yet.
    public init(start: Point) {
        points = [start]
    }

    /// Where the stix left the border.
    public var start: Point {
        points[0]
    }

    /// The end of the stix, where the marker is.
    public var head: Point {
        points[points.count - 1]
    }

    /// The kind of claim the stix makes: `DrawKind.slow` only when it has segments and every one
    /// was drawn slow, otherwise `DrawKind.fast`.
    public func claimKind() -> DrawKind {
        let allSlow = kinds.allSatisfy { $0 == .slow }
        return allSlow && !kinds.isEmpty ? .slow : .fast
    }

    /// `point` lies on the stix: on one of its segments, or at its start when it has none.
    public func containsPoint(_ point: Point) -> Bool {
        start == point || segments().contains { onSegment($0, $1, point) }
    }

    /// The stix runs from `one` to `other` along one of its segments, in either direction. For
    /// two neighbouring lattice points, this is whether the stix covers the unit edge between them.
    public func containsSegment(_ one: Point, _ other: Point) -> Bool {
        one != other && segments().contains { onSegment($0, $1, one) && onSegment($0, $1, other) }
    }

    /// Extends the stix from its head to `next`, drawn with `kind`.
    ///
    /// Whether the move is legal is `legalStep`'s business; this only records it.
    ///
    /// - Precondition: `next` is not the head and shares its row or its column.
    public mutating func push(_ next: Point, _ kind: DrawKind) {
        let head = head
        let dir = Dir.between(head, next)
        precondition(dir != nil, "stix step \(head) -> \(next) is not straight")
        let continues = points.count >= 2 && Dir.between(points[points.count - 2], head) == dir
        if continues, kinds.last == kind {
            points[points.count - 1] = next
        } else {
            points.append(next)
            kinds.append(kind)
        }
    }

    /// The direction of the step from `point` one lattice point along the stix towards its head;
    /// `nil` at the head or off the stix. A corner of the polyline leads along the segment it
    /// starts.
    public func towardsHead(_ point: Point) -> Dir? {
        guard let (_, end) = segments().first(where: { point != $1 && onSegment($0, $1, point) }) else {
            return nil
        }
        return Dir.between(point, end)
    }

    /// The segments, as their two ends, from the start to the head.
    public func segments() -> Zip2Sequence<[Point], ArraySlice<Point>> {
        zip(points, points.dropFirst())
    }
}

/// The point one lattice step from the marker towards `dir`, if the stix may be drawn there; the
/// marker is at the stix's head.
///
/// The step must run through free space (both cells beside it free), and its end may not lie on
/// the stix already, except the start reached over an edge the stix does not cover: a loop from a
/// corner of the border back to it. The end is then either a free point inside the free area or a
/// border point, which closes the stix. The rule refuses crossing the stix, retracing it and
/// turning back on the last segment; a step along lattice lines cannot cross a segment without
/// ending on it, so there is no separate crossing check.
public func legalStep(_ marker: Marker, _ stix: Stix, _ board: Board, _ dir: Dir) -> Point? {
    assert(marker.pos == stix.head, "the marker is not at the head")
    guard let next = dir.step(marker.pos) else { return nil }
    let loopsToStart = next == stix.start && !stix.containsSegment(marker.pos, next)
    let freeEnd = !stix.containsPoint(next) || loopsToStart
    return board.isFreeEdge(marker.pos, dir) && freeEnd ? next : nil
}

/// The directions the marker may draw in, in the order of `Dir.all`. An empty result means it is
/// caught in a dead end (the "spiral death trap").
public func legalMoves(_ marker: Marker, _ stix: Stix, _ board: Board) -> [Dir] {
    Dir.all.filter { legalStep(marker, stix, board, $0) != nil }
}

/// `point` lies on the axis-aligned segment from `from` to `to`, ends included.
private func onSegment(_ from: Point, _ to: Point, _ point: Point) -> Bool {
    func inRange(_ first: UInt16, _ second: UInt16, _ value: UInt16) -> Bool {
        min(first, second) <= value && value <= max(first, second)
    }
    return inRange(from.x, to.x, point.x) && inRange(from.y, to.y, point.y)
}
