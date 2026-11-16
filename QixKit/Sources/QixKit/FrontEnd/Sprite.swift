// Pixel-art sprites: masks of characters, one per sprite pixel, turned into squares. qix-rs's
// `crates/qix/src/render/sprite.rs`, without its painting, which the app does.
//
// A mask has an odd width and height, so its middle pixel lies on the lattice point the sprite is
// centred on. Sizes are in screen points, so sprites keep their look at every screen size.

/// One painted pixel of a sprite: a square `side` points wide whose top-left corner is at `(x, y)`,
/// in screen points.
public struct SpriteSquare: Hashable, Sendable {
    public var x: Float
    public var y: Float
    public var side: Float
    public var colour: RGBA

    public init(x: Float, y: Float, side: Float, colour: RGBA) {
        self.x = x
        self.y = y
        self.side = side
        self.colour = colour
    }
}

public enum Sprite {
    /// The rows of a sprite, top first, one character per pixel. The characters are colour roles
    /// that the caller maps to colours; `transparent` is the only one with a meaning of its own.
    public typealias Mask = [String]

    /// Size of one sprite pixel in the playfield, in points.
    public static let pixel: Float = 1.25

    /// The role of a pixel that is not painted.
    public static let transparent: Character = "."

    /// The marker's outline.
    public static let outline: Character = "O"

    /// The marker's inside.
    public static let inner: Character = "I"

    /// The marker's highlight, on its upper left edge.
    public static let highlight: Character = "H"

    /// The arms of a spark.
    public static let body: Character = "B"

    /// The bright heart of a spark.
    public static let core: Character = "C"

    /// The marker: a diamond with an outline and a highlight.
    public static let markerMask: Mask = [
        "....O....",
        "...OIO...",
        "..OHIIO..",
        ".OHHIIIO.",
        "OIIIIIIIO",
        ".OIIIIIO.",
        "..OIIIO..",
        "...OIO...",
        "....O....",
    ]

    /// The two frames of a spark: the plus-shaped arms, then the diagonal ones, around the same
    /// core.
    public static let sparkFrames: [Mask] = [
        [
            "....B....",
            "....B....",
            "....B....",
            "...BCB...",
            "BBBCCCBBB",
            "...BCB...",
            "....B....",
            "....B....",
            "....B....",
        ],
        [
            "B.......B",
            ".B.....B.",
            "..B...B..",
            "...BCB...",
            "...CCC...",
            "...BCB...",
            "..B...B..",
            ".B.....B.",
            "B.......B",
        ],
    ]

    /// The width and height of `mask`, in sprite pixels.
    public static func maskSize(_ mask: Mask) -> (width: Int, height: Int) {
        (mask.first?.count ?? 0, mask.count)
    }

    /// `mask` as one `pixel`-point square per painted pixel, row by row from the top, centred on
    /// `centre`. `colourOf` gives the colour of a role, or nil to leave its pixels unpainted like
    /// `transparent` ones.
    public static func squares(
        _ mask: Mask, centre: Vec2, pixel: Float, colourOf: (Character) -> RGBA?
    ) -> [SpriteSquare] {
        let (width, height) = maskSize(mask)
        let left = centre.x - Float(width) * pixel / 2
        let top = centre.y - Float(height) * pixel / 2
        return mask.enumerated().flatMap { row, line in
            line.enumerated().compactMap { col, role -> SpriteSquare? in
                guard role != transparent, let colour = colourOf(role) else { return nil }
                return SpriteSquare(
                    x: left + Float(col) * pixel, y: top + Float(row) * pixel, side: pixel, colour: colour
                )
            }
        }
    }

    /// The marker centred on `centre` with `pixel`-point pixels, its inside painted `inner`.
    public static func marker(centre: Vec2, pixel: Float, inner: RGBA) -> [SpriteSquare] {
        squares(markerMask, centre: centre, pixel: pixel) { role in
            switch role {
            case outline: Palette.markerOutline
            case Self.inner: inner
            case highlight: Palette.markerHighlight
            default: nil
            }
        }
    }

    /// The spark showing `mask`, one of `sparkFrames`, centred on `centre` in the colours of a
    /// Sparx of `kind`.
    public static func spark(_ mask: Mask, centre: Vec2, kind: SparxKind) -> [SpriteSquare] {
        squares(mask, centre: centre, pixel: pixel) { role in
            switch role {
            case body: Palette.sparx(kind)
            case core: Palette.sparxCore(kind)
            default: nil
            }
        }
    }
}
