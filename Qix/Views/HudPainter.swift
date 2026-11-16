import QixKit
import SwiftUI

/// Paints the HUD in its strip above the board: each column's name, then its value, its lives or
/// its meter. The HUD's button (pause, or settings on the title) is a view of its own over the last
/// column.
enum HudPainter {
    /// The names of the columns, in the order of `HudLayout.Column`, the pause button's excepted.
    static func label(_ column: HudLayout.Column) -> String? {
        switch column {
        case .score: "SCORE"
        case .highScore: "HIGH SCORE"
        case .level: "LEVEL"
        case .lives: "LIVES"
        case .claimed: "CLAIMED"
        case .meter: "SPARX"
        case .multiplier: "MULTIPLIER"
        case .pause: nil
        }
    }

    static func paint(_ context: inout GraphicsContext, _ hud: Hud, in strip: CGRect) {
        for (column, rect) in zip(HudLayout.Column.allCases, HudLayout.columns(in: strip)) {
            paint(&context, column, of: hud, in: rect)
        }
    }

    /// Paints `column` of `hud` in `rect`; nothing for the multiplier while there is none.
    private static func paint(
        _ context: inout GraphicsContext, _ column: HudLayout.Column, of hud: Hud, in rect: CGRect
    ) {
        guard let name = label(column), column != .multiplier || hud.multiplier != nil else { return }
        let height = rect.height
        let top = CGPoint(x: rect.midX, y: rect.minY + HudLayout.labelTop * height)
        let title = Text(name).font(.system(size: HudLayout.labelSize * height))
            .foregroundStyle(Color(Palette.hudLabel))
        context.draw(title, at: top, anchor: .top)
        let centre = CGPoint(x: rect.midX, y: rect.minY + HudLayout.valueCentre * height)
        switch column {
        case .score: value(&context, hud.score, at: centre, height: height)
        case .highScore: value(&context, hud.highScore, at: centre, height: height)
        case .level: value(&context, hud.level, at: centre, height: height)
        case .lives: lives(&context, hud.lives, at: centre, height: height)
        case .claimed: value(&context, hud.claimed, at: centre, height: height)
        case .meter: meter(&context, hud.meter, at: centre, columnWidth: rect.width, height: height)
        case .multiplier: value(&context, hud.multiplier ?? "", at: centre, height: height)
        case .pause: break
        }
    }

    /// Paints `text` as a value anchored by `anchor` at `position`, in a strip `height` high.
    private static func value(
        _ context: inout GraphicsContext, _ text: String, at position: CGPoint, anchor: UnitPoint = .center,
        height: CGFloat
    ) {
        let font = Font.system(size: HudLayout.valueSize * height, design: .monospaced)
        context.draw(Text(text).font(font).foregroundStyle(Color(Palette.hudValue)), at: position, anchor: anchor)
    }

    /// Paints `lives` as markers, or past `HudLayout.maxLifeMarkers` one marker and their count.
    private static func lives(_ context: inout GraphicsContext, _ lives: UInt32, at centre: CGPoint, height: CGFloat) {
        let radius = HudLayout.lifeSize * height / 2
        for life in HudLayout.lifeCentres(lives, centre: centre, height: height) {
            BoardPainter.marker(&context, at: life, radius: radius, inner: Palette.hudLife)
        }
        if lives > HudLayout.maxLifeMarkers {
            value(&context, "x\(lives)", at: centre, anchor: .leading, height: height)
        }
    }

    /// Paints `meter` as a bar: an outline, and inside it a fill from the left as long as the share
    /// of the countdown left, none once the meter is spent.
    private static func meter(
        _ context: inout GraphicsContext, _ meter: Meter, at centre: CGPoint, columnWidth: CGFloat, height: CGFloat
    ) {
        let (frame, fill) = HudLayout.meterRects(
            fraction: meter.fraction, centre: centre, columnWidth: columnWidth, height: height
        )
        if let next = meter.next {
            context.fill(Path(fill), with: .color(Color(Palette.meter(next))))
        }
        let outline = frame.insetBy(dx: HudLayout.meterFrameWidth / 2, dy: HudLayout.meterFrameWidth / 2)
        context.stroke(Path(outline), with: .color(Color(Palette.hudMeterFrame)), lineWidth: HudLayout.meterFrameWidth)
    }
}
