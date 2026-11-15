// The seeded random number generator the game draws from.
//
// The application injects one into the core, so a seed fixes every random choice and simulations
// and tests replay exactly.

/// A SplitMix64 generator: tiny, fast, and the same sequence for a seed on every platform.
public struct Rng: Equatable, Sendable {
    /// SplitMix64 increment and output multipliers.
    private static let splitmixGamma: UInt64 = 0x9E37_79B9_7F4A_7C15
    private static let splitmixMul1: UInt64 = 0xBF58_476D_1CE4_E5B9
    private static let splitmixMul2: UInt64 = 0x94D0_49BB_1331_11EB

    /// Digits of the `Float` significand, the implicit leading one included: Rust's
    /// `f32::MANTISSA_DIGITS`.
    private static let f32MantissaDigits = Float.significandBitCount + 1

    /// Bits of a random `UInt64` dropped to make a `Float` fraction: all but the width of the
    /// `Float` significand, so every fraction is exact.
    private static let f32DroppedBits = UInt64.bitWidth - f32MantissaDigits

    private var state: UInt64

    /// A generator whose sequence is fixed by `seed`.
    public init(seed: UInt64) {
        state = seed
    }

    /// The next 64 random bits.
    public mutating func nextU64() -> UInt64 {
        state &+= Self.splitmixGamma
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* Self.splitmixMul1
        mixed = (mixed ^ (mixed >> 27)) &* Self.splitmixMul2
        return mixed ^ (mixed >> 31)
    }

    /// A uniform fraction in `[0, 1)`.
    public mutating func nextF32() -> Float {
        let bits = nextU64() >> Self.f32DroppedBits
        return Float(bits) / Float(UInt64(1) << Self.f32MantissaDigits)
    }

    /// A uniform value in `[low, high)`; `low` itself when the two are equal.
    public mutating func rangeF32(_ low: Float, _ high: Float) -> Float {
        low + (high - low) * nextF32()
    }

    /// A uniform index in `[0, len)`, from the high bits of a random `UInt64` scaled by `len`
    /// (Lemire's multiply-shift).
    ///
    /// - Precondition: `len` is positive.
    public mutating func below(_ len: Int) -> Int {
        precondition(len > 0, "no index below \(len)")
        return Int(nextU64().multipliedFullWidth(by: UInt64(len)).high)
    }
}
