/// The size of the board in cells; the playfield is one unit per cell.
///
/// A placeholder until qix-core's `tuning` module is ported: its `BOARD_W` and `BOARD_H` then
/// replace this type, and the app takes the playfield's aspect ratio from them.
public struct BoardSize: Sendable, Hashable {
    /// The arcade board, qix-core's `BOARD_W` by `BOARD_H`.
    public static let standard = Self(width: 160, height: 120)

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
