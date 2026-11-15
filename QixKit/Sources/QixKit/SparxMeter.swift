// The Sparx meter: the countdown that releases more Sparx, then turns every Sparx Super.

/// What the Sparx meter does when its countdown runs out.
public enum MeterExpiry: Hashable, Sendable {
    /// The first expiry: more Sparx are released at the top centre.
    case release
    /// The second expiry: every Sparx turns Super.
    case `super`

    /// The expiry after this one, `nil` after the last.
    var next: Self? {
        switch self {
        case .release: .super
        case .super: nil
        }
    }
}

/// Counts down twice per level, the same length each time: first to a `MeterExpiry.release`, then
/// to a `MeterExpiry.super`; after that it is spent and stays at zero until reset.
public struct SparxMeter: Hashable, Sendable {
    /// Ticks of one countdown, at least one.
    public let length: UInt32
    /// Ticks left of the current countdown; zero once spent.
    public private(set) var remaining: UInt32
    /// What the current countdown leads to, `nil` once both expiries have passed.
    public private(set) var nextExpiry: MeterExpiry?

    /// A full meter counting down `length` ticks (at least one) to its `MeterExpiry.release`.
    public init(length: UInt32) {
        let length = max(length, 1)
        self.length = length
        remaining = length
        nextExpiry = .release
    }

    /// Counts one tick down; returns the expiry when this tick ends the countdown, which then
    /// starts over towards the next expiry. A spent meter does nothing.
    @discardableResult
    public mutating func tick() -> MeterExpiry? {
        guard let expiry = nextExpiry else { return nil }
        remaining -= 1
        if remaining > 0 {
            return nil
        }
        nextExpiry = expiry.next
        if nextExpiry != nil {
            remaining = length
        }
        return expiry
    }

    /// Fills the meter again, back to counting down to its `MeterExpiry.release`.
    public mutating func reset() {
        self = Self(length: length)
    }
}
