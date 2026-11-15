// What the playfield draws of a game, as lattice points, kinds and colours: qix-rs's
// `crates/qix/src/render/board.rs`, `enemies.rs` and `claimed.rs`, without their painting, which
// the app does.

/// A straight line between two lattice points.
public struct LatticeSegment: Hashable, Sendable {
    public var from: Point
    public var to: Point

    public init(from: Point, to: Point) {
        self.from = from
        self.to = to
    }
}

/// A polyline of consecutive stix segments drawn with the same kind.
public struct StixRun: Hashable, Sendable {
    public var kind: DrawKind
    /// The run's points, from the end nearer the stix's start.
    public var points: [Point]

    public init(kind: DrawKind, points: [Point]) {
        self.kind = kind
        self.points = points
    }
}

public enum BoardShapes {
    /// The border of `board` as maximal straight segments between lattice points: the horizontal
    /// ones top row first, then the vertical ones left column first.
    public static func borderSegments(_ board: Board) -> [LatticeSegment] {
        let (width, height) = (board.width, board.height)
        let horizontal = (0 ... height).flatMap { y in
            mergeRuns(width) { board.isBorderEdge(Point(x: $0, y: y), .right) }
                .map { LatticeSegment(from: Point(x: $0.lowerBound, y: y), to: Point(x: $0.upperBound, y: y)) }
        }
        let vertical = (0 ... width).flatMap { x in
            mergeRuns(height) { board.isBorderEdge(Point(x: x, y: $0), .down) }
                .map { LatticeSegment(from: Point(x: x, y: $0.lowerBound), to: Point(x: x, y: $0.upperBound)) }
        }
        return horizontal + vertical
    }

    /// The stix as polylines of consecutive segments drawn with the same kind, from the start to
    /// the head; consecutive polylines share their meeting point. A stix with no segment has none.
    public static func stixRuns(_ stix: Stix) -> [StixRun] {
        var runs: [StixRun] = []
        for (i, kind) in stix.kinds.enumerated() {
            if runs.last?.kind == kind {
                runs[runs.count - 1].points.append(stix.points[i + 1])
            } else {
                runs.append(StixRun(kind: kind, points: [stix.points[i], stix.points[i + 1]]))
            }
        }
        return runs
    }

    /// The colour of the marker's inside: that of the kind of the stix's last segment while it
    /// draws one, plain otherwise.
    public static func markerInner(_ stix: Stix?) -> RGBA {
        stix?.kinds.last.map(Palette.stix) ?? Palette.marker
    }

    /// The colours of a trail of `count` segments after `ticks` ticks, oldest first: one step
    /// through `Palette.qixTrail` per segment, so a segment keeps its colour as long as it stays in
    /// the trail.
    ///
    /// The Qix records one segment per tick, so its newest segment is that of tick `ticks`.
    public static func trailColours(_ count: Int, ticks: UInt64) -> [RGBA] {
        let cycle = Palette.qixTrail.count
        let newest = Int(ticks % UInt64(cycle))
        return (0 ..< count).map { i in
            let age = (count - 1 - i) % cycle
            return Palette.qixTrail[(newest + cycle - age) % cycle]
        }
    }

    /// The lattice point the lit fuse of `game` has burnt to, if it is lit.
    public static func fusePoint(_ game: Game) -> Point? {
        guard let stix = game.stix, let fuse = game.fuse, stix.points.indices.contains(fuse.pos) else { return nil }
        return stix.points[fuse.pos]
    }

    /// Bytes per pixel of `claimedPixels`.
    public static let bytesPerPixel = 4

    /// `board`'s cells as an image of one pixel per cell, row by row from the top, `bytesPerPixel`
    /// bytes each in red, green, blue, alpha order: each claimed cell in the fill of its kind, the
    /// free ones transparent.
    public static func claimedPixels(_ board: Board) -> [UInt8] {
        var pixels: [UInt8] = []
        pixels.reserveCapacity(Int(board.width) * Int(board.height) * bytesPerPixel)
        for y in 0 ..< Int32(board.height) {
            for x in 0 ..< Int32(board.width) {
                let colour = switch board.cell(x: x, y: y) {
                case let .claimed(kind): Palette.fill(kind)
                case .free: RGBA.transparent
                }
                pixels.append(colour.red)
                pixels.append(colour.green)
                pixels.append(colour.blue)
                pixels.append(colour.alpha)
            }
        }
        return pixels
    }

    /// The maximal runs of indices in `0..<count` where `isOn` holds, in increasing order, as
    /// half-open ranges.
    private static func mergeRuns(_ count: UInt16, _ isOn: (UInt16) -> Bool) -> [Range<UInt16>] {
        var runs: [Range<UInt16>] = []
        for i in 0 ..< count where isOn(i) {
            if let last = runs.last, last.upperBound == i {
                runs[runs.count - 1] = last.lowerBound ..< i + 1
            } else {
                runs.append(i ..< i + 1)
            }
        }
        return runs
    }
}
