// Vectors in continuous playfield units, for the entities that are not bound to the lattice.

import Foundation

/// A point or a displacement in playfield units: one unit per cell, so cell `(x, y)` covers
/// `[x, x + 1) x [y, y + 1)`; `y` grows downwards.
public struct Vec2: Equatable, Sendable {
    public var x: Float
    public var y: Float

    /// The vector `(x, y)`.
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    /// The zero vector: Rust's `Vec2::default()`.
    public init() {
        self.init(x: 0, y: 0)
    }

    /// The playfield position of a lattice point: the top-left corner of cell `(x, y)` is at
    /// `(x, y)`.
    public init(_ point: Point) {
        self.init(x: Float(point.x), y: Float(point.y))
    }

    /// The unit vector at `angle` radians from the `x` axis, towards `y`.
    ///
    /// The sine and cosine come from the platform's libm (`sinf`, `cosf`), as in qix-rs.
    public static func fromAngle(_ angle: Float) -> Self {
        Self(x: cosf(angle), y: sinf(angle))
    }

    /// The Euclidean length, from the platform's libm (`hypotf`), as in qix-rs.
    public var length: Float {
        hypotf(x, y)
    }

    /// This vector scaled to `length`; the zero vector stays zero.
    public func withLength(_ length: Float) -> Self {
        let current = self.length
        return current > 0 ? self * (length / current) : self
    }

    /// The point halfway between `self` and `other`.
    public func midpoint(_ other: Self) -> Self {
        (self + other) * 0.5
    }

    /// The `z` component of the cross product: positive when `other` turns from `self` towards
    /// `y`, negative the other way, zero when the two are parallel.
    public func cross(_ other: Self) -> Float {
        x * other.y - y * other.x
    }

    /// This vector turned by `angle` radians, from the `x` axis towards `y`.
    public func rotated(_ angle: Float) -> Self {
        let (sin, cos) = (sinf(angle), cosf(angle))
        return Self(x: x * cos - y * sin, y: x * sin + y * cos)
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func * (lhs: Self, factor: Float) -> Self {
        Self(x: lhs.x * factor, y: lhs.y * factor)
    }

    public static prefix func - (vector: Self) -> Self {
        Self(x: -vector.x, y: -vector.y)
    }
}
