import CoreGraphics
import QixKit

/// The sizes of a screen's text over the board, in points: lines `lineShare` of the board's
/// height, smaller where the screen would not fit the board otherwise. The other sizes are
/// multiples of the line size in qix-rs's proportions, so a screen keeps them as it shrinks.
enum ScreenLayout {
    /// The largest line size, as a fraction of the board's height.
    static let lineShare: CGFloat = 0.05

    /// The heading's size, in line sizes: qix-rs's 40 points over its 18-point lines.
    static let headingScale: CGFloat = 40.0 / 18.0

    /// Height of a row of text, in sizes of its font.
    static let rowHeight: CGFloat = 1.25

    /// Space between the heading and the first row, and between the table and the lines, in line
    /// sizes: qix-rs's 16 points.
    static let gap: CGFloat = 16.0 / 18.0

    /// Space between the text and the edge of its panel, in line sizes: qix-rs's 24 points.
    static let padding: CGFloat = 24.0 / 18.0

    /// Corner radius of the panel, in line sizes: qix-rs's 8 points.
    static let cornerRadius: CGFloat = 8.0 / 18.0

    /// The most of the board's height the panel may take.
    static let maxPanelShare: CGFloat = 0.94

    /// The panel's height for `screen`, in line sizes.
    static func panelHeight(_ screen: Screen) -> CGFloat {
        let rows = CGFloat(screen.table.count + screen.lines.count)
        let tableGap = screen.table.isEmpty ? 0 : gap
        return headingScale * rowHeight + gap + rows * rowHeight + tableGap + 2 * padding
    }

    /// The line size of `screen` on a board `fieldHeight` high: `lineShare` of it, or less, so the
    /// panel takes at most `maxPanelShare` of it.
    static func lineSize(_ screen: Screen, fieldHeight: CGFloat) -> CGFloat {
        min(lineShare * fieldHeight, maxPanelShare * fieldHeight / panelHeight(screen))
    }
}
