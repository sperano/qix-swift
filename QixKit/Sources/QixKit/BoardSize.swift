/// The size of the board in cells; the playfield is one unit per cell.
///
/// A placeholder for the app until it reads `Tuning.boardW` and `Tuning.boardH` itself: the app
/// takes the playfield's aspect ratio from `standard`.
public struct BoardSize: Sendable, Hashable {
    /// The arcade board, `Tuning.boardW` by `Tuning.boardH`.
    public static let standard = Self(width: Tuning.boardW, height: Tuning.boardH)

    /// Board width in cells.
    public let width: UInt16
    /// Board height in cells.
    public let height: UInt16

    public init(width: UInt16, height: UInt16) {
        self.width = width
        self.height = height
    }

    /// Width over height: the shape the playfield keeps at any size.
    public var aspectRatio: Double {
        Double(width) / Double(height)
    }
}
