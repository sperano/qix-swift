// What the playfield draws of a game, as lattice points, kinds and colours: qix-rs's
// `crates/qix/src/render/board.rs`, `enemies.rs`, `claimed.rs` and `claim_fill.rs`, without their
// painting, which the app does.

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

/// A horizontal run of claimed cells of the same kind in one row.
public struct CellRun: Hashable, Sendable {
    public var row: UInt16
    public var cols: Range<UInt16>
    public var kind: DrawKind

    public init(row: UInt16, cols: Range<UInt16>, kind: DrawKind) {
        self.row = row
        self.cols = cols
        self.kind = kind
    }
}

public enum BoardShapes {
    /// Game ticks between two flickers of the stix being drawn, when it swaps between the colour of
    /// its kind and `Palette.stixFlicker`.
    public static let stixFlickerTicks: UInt64 = 3

    /// Ticks between two flickers of a spark, when its two frames swap.
    public static let sparkFlickerTicks: UInt64 = 4

    /// Every claimed cell of `board` as maximal runs along its rows, top row first and left to
    /// right within a row.
    public static func claimedRuns(_ board: Board) -> [CellRun] {
        var runs: [CellRun] = []
        for row in 0 ..< board.height {
            for col in 0 ..< board.width {
                guard case let .claimed(kind) = board.cell(x: Int32(col), y: Int32(row)) else { continue }
                if let last = runs.last, last.row == row, last.cols.upperBound == col, last.kind == kind {
                    runs[runs.count - 1].cols = last.cols.lowerBound ..< col + 1
                } else {
                    runs.append(CellRun(row: row, cols: col ..< col + 1, kind: kind))
                }
            }
        }
        return runs
    }

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

    /// The colour of the stix's segments drawn with `kind` after `ticks` game ticks: it alternates
    /// with `Palette.stixFlicker` every `stixFlickerTicks`, starting with the colour of its kind.
    public static func stixColour(_ kind: DrawKind, ticks: UInt64) -> RGBA {
        (ticks / stixFlickerTicks).isMultiple(of: 2) ? Palette.stix(kind) : Palette.stixFlicker
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

    /// The frame of a spark after `ticks` ticks: it swaps between `Sprite.sparkFrames` every
    /// `sparkFlickerTicks`.
    public static func sparkFrame(ticks: UInt64) -> Sprite.Mask {
        Sprite.sparkFrames[(ticks / sparkFlickerTicks).isMultiple(of: 2) ? 0 : 1]
    }

    /// The colour of cells claimed with `kind` once their animation is `progress` through, from 0
    /// at the claim to 1 at its end: from `Palette.claimFlash` to the colour of their fill, fast at
    /// first and slowing down towards the fill.
    public static func fillColour(_ kind: DrawKind, progress: Float) -> RGBA {
        let clamped = min(max(progress, 0), 1)
        let eased = 1 - (1 - clamped) * (1 - clamped)
        return Palette.claimFlash.lerpToGamma(Palette.fill(kind), eased)
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
