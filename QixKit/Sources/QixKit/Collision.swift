// Whether the Qix touches the stix or the marker drawing it.

/// One of `qix` touches `stix` (see `qixHitsStix`) or the marker drawing it at `marker` (see
/// `qixHitsMarker`).
public func qixHitsPlayer(_ qix: [Qix], _ stix: Stix, _ marker: Point) -> Bool {
    qix.contains { qixHitsStix($0, stix) || qixHitsMarker($0, marker) }
}

/// The Qix touched one of `stix`'s segments over its last tick: the area its segment swept from
/// `Qix.previous` to where it is now meets one, so a Qix crossing the stix within a tick hits it
/// too.
public func qixHitsStix(_ qix: Qix, _ stix: Stix) -> Bool {
    sweepHitsStix(qix.previous, (qix.a, qix.b), stix)
}

/// The Qix's segment, where it is now, touches one of `stix`'s segments: unlike `qixHitsStix`,
/// where it was a tick ago does not count.
public func qixTouchesStix(_ qix: Qix, _ stix: Stix) -> Bool {
    let now = (qix.a, qix.b)
    return sweepHitsStix(now, now, stix)
}

/// The area a segment sweeps moving from `before` to `after` meets one of `stix`'s segments. The
/// area is taken as the convex hull of the two segments' four ends, which holds every segment in
/// between, even one turned past itself; the four triangles of three of the ends cover that hull.
/// A segment that did not move sweeps only itself.
public func sweepHitsStix(_ before: (Vec2, Vec2), _ after: (Vec2, Vec2), _ stix: Stix) -> Bool {
    let ((a0, b0), (a1, b1)) = (before, after)
    let hull = [[a0, b0, b1], [a0, b1, a1], [a0, b0, a1], [b0, b1, a1]]
    return stix.segments().contains { from, to in
        let (start, end) = (Vec2(from), Vec2(to))
        return hull.contains { segmentMeetsTriangle(start, end, $0) }
    }
}

/// The Qix's segment touches the square of half side `Tuning.markerHitHalfSize` centred on the
/// marker at `marker`: it crosses one of the square's sides or lies inside it.
public func qixHitsMarker(_ qix: Qix, _ marker: Point) -> Bool {
    let centre = Vec2(marker)
    let corners = squareCorners(centre, Tuning.markerHitHalfSize)
    let crossesSide = corners.indices.contains { index in
        let (start, end) = (corners[index], corners[(index + 1) % corners.count])
        return segmentsIntersect(qix.a, qix.b, start, end)
    }
    return crossesSide || inSquare(qix.a, centre, Tuning.markerHitHalfSize)
}

/// The segment from `start` to `end` crosses a side of `triangle` or lies inside it.
private func segmentMeetsTriangle(_ start: Vec2, _ end: Vec2, _ triangle: [Vec2]) -> Bool {
    let crossesSide = triangle.indices.contains { index in
        let (from, to) = (triangle[index], triangle[(index + 1) % triangle.count])
        return segmentsIntersect(start, end, from, to)
    }
    return crossesSide || inTriangle(start, (triangle[0], triangle[1], triangle[2]))
}

/// The corners of the square of half side `half` centred on `centre`, in order around it.
private func squareCorners(_ centre: Vec2, _ half: Float) -> [Vec2] {
    [
        centre + Vec2(x: -half, y: -half),
        centre + Vec2(x: half, y: -half),
        centre + Vec2(x: half, y: half),
        centre + Vec2(x: -half, y: half),
    ]
}

/// `point` lies in the square of half side `half` centred on `centre`.
private func inSquare(_ point: Vec2, _ centre: Vec2, _ half: Float) -> Bool {
    abs(point.x - centre.x) <= half && abs(point.y - centre.y) <= half
}
