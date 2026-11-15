import CoreGraphics

/// The HUD's strip: its columns and the sizes of what they show, as fractions of the strip's
/// height, so the HUD scales with the letterboxed board. qix-rs's `render/hud.rs`, with a column
/// for the pause button.
enum HudLayout {
    /// The columns of the strip, left to right.
    enum Column: Int, CaseIterable {
        case score, highScore, level, lives, claimed, meter, multiplier, pause
    }

    /// Each column's share of the strip's width, in the order of `Column`.
    static let columnWeights: [CGFloat] = [3, 3, 2, 3, 4, 3, 2, 2]

    /// Size of a field's name, as a fraction of the strip's height.
    static let labelSize: CGFloat = 0.22

    /// Top of a field's name, as a fraction of the strip's height.
    static let labelTop: CGFloat = 0.12

    /// Size of a field's value, as a fraction of the strip's height.
    static let valueSize: CGFloat = 0.30

    /// Centre of a field's value, as a fraction of the strip's height.
    static let valueCentre: CGFloat = 0.66

    /// Lives drawn as markers; more show as one marker and their count.
    static let maxLifeMarkers: UInt32 = 5

    /// Width and height of a life marker, as a fraction of the strip's height.
    static let lifeSize: CGFloat = 0.24

    /// Distance between the centres of two life markers, in life marker sizes.
    static let lifeSpacing: CGFloat = 1.3

    /// Width of the Sparx meter's bar, as a fraction of its column's width.
    static let meterWidth: CGFloat = 0.8

    /// Height of the Sparx meter's bar, as a fraction of the strip's height.
    static let meterHeight: CGFloat = 0.2

    /// Width of the Sparx meter's outline, in points.
    static let meterFrameWidth: CGFloat = 1

    /// The rectangles of the columns of `strip`, left to right, in the order of `Column`.
    static func columns(in strip: CGRect) -> [CGRect] {
        let total = columnWeights.reduce(0, +)
        var left = strip.minX
        return columnWeights.map { weight in
            let width = strip.width * weight / total
            defer { left += width }
            return CGRect(x: left, y: strip.minY, width: width, height: strip.height)
        }
    }

    /// The rectangle of `column` in `strip`.
    static func rect(of column: Column, in strip: CGRect) -> CGRect {
        columns(in: strip)[column.rawValue]
    }

    /// The centres of the life markers shown for `lives` in a column centred on `centre` of a strip
    /// `height` high: a row centred on it, or past `maxLifeMarkers` one marker left of it, its count
    /// starting at the centre.
    static func lifeCentres(_ lives: UInt32, centre: CGPoint, height: CGFloat) -> [CGPoint] {
        let spacing = lifeSpacing * lifeSize * height
        if lives > maxLifeMarkers {
            return [CGPoint(x: centre.x - spacing / 2, y: centre.y)]
        }
        let span = CGFloat(max(lives, 1) - 1) * spacing
        return (0 ..< lives).map { CGPoint(x: centre.x - span / 2 + CGFloat($0) * spacing, y: centre.y) }
    }

    /// The Sparx meter's outline centred on `centre` in a column `columnWidth` wide of a strip
    /// `height` high, and its fill from the left for a countdown with `fraction` left (clamped to
    /// 0 ... 1).
    static func meterRects(fraction: Float, centre: CGPoint, columnWidth: CGFloat, height: CGFloat)
        -> (frame: CGRect, fill: CGRect)
    {
        let size = CGSize(width: meterWidth * columnWidth, height: meterHeight * height)
        let frame = CGRect(origin: CGPoint(x: centre.x - size.width / 2, y: centre.y - size.height / 2), size: size)
        var fill = frame
        fill.size.width = frame.width * CGFloat(min(max(fraction, 0), 1))
        return (frame, fill)
    }
}
