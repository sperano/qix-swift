// The cells a straight segment in playfield units passes through.

/// The functions of qix-core's `segment` module.
enum Segment {
    /// The cells, as `(x, y)`, that the segment from `from` to `to` passes through, in order from
    /// the cell of `from` to the cell of `to`.
    ///
    /// Consecutive cells share a side: a segment through a lattice point crosses into one of the
    /// two cells beside the diagonal step, not both. The coordinates are not bounded by any board.
    static func cells(_ from: Vec2, _ to: Vec2) -> Cells {
        Cells(x: Axis(from.x, to.x), y: Axis(from.y, to.y))
    }

    /// The sequence `cells` returns.
    struct Cells: Sequence, IteratorProtocol {
        fileprivate var x: Axis
        fileprivate var y: Axis
        fileprivate var done = false

        mutating func next() -> (Int32, Int32)? {
            if done {
                return nil
            }
            let cell = (x.cell, y.cell)
            // An axis that is already in the end cell never steps, so rounding in the crossing
            // times cannot walk past the end.
            if x.left == 0, y.left == 0 {
                done = true
            } else if y.left == 0 || (x.left > 0 && x.next < y.next) {
                x.advance()
            } else {
                y.advance()
            }
            return cell
        }
    }
}

/// The walk along one axis: the current cell coordinate and when, as a fraction of the segment,
/// the next cell boundary is crossed.
private struct Axis {
    var cell: Int32
    /// `1` or `-1` towards the end, `0` along a segment with no extent on this axis.
    let step: Int32
    /// The fraction of the segment at which the next boundary lies.
    var next: Float
    /// The fraction of the segment between two boundaries.
    let delta: Float
    /// The boundaries left to cross.
    var left: UInt32

    init(_ from: Float, _ to: Float) {
        let cell = from.rounded(.down)
        let extent = to - from
        let toBoundary: Float
        if extent > 0 {
            (step, toBoundary) = (1, cell + 1 - from)
        } else if extent < 0 {
            (step, toBoundary) = (-1, from - cell)
        } else {
            (step, toBoundary) = (0, .infinity)
        }
        delta = 1 / abs(extent)
        self.cell = saturatingInt32(cell)
        next = toBoundary * delta
        left = UInt32((Int64(saturatingInt32(to.rounded(.down))) - Int64(self.cell)).magnitude)
    }

    mutating func advance() {
        cell += step
        next += delta
        left -= 1
    }
}

/// `value` as an `Int32` the way Rust's `as` casts it: saturated at the type's bounds, NaN as
/// zero, where Swift's conversion would trap.
private func saturatingInt32(_ value: Float) -> Int32 {
    if value.isNaN {
        return 0
    }
    if value <= Float(Int32.min) {
        return .min
    }
    if value >= Float(Int32.max) {
        return .max
    }
    return Int32(value)
}
