import QixKit
import SwiftUI

/// Paints the board and its enemies: the claimed cells and over them the claim being animated, the
/// border, the stix by kind, flickering, and the marker's sprite (qix-rs's `render/board.rs` and
/// `render/claim_fill.rs`), then each Qix's trail, the Sparx's sprites and the fuse
/// (`render/enemies.rs`).
///
/// Line widths and sprite sizes are in points, so they keep their look at every screen size;
/// positions go through the layout.
enum BoardPainter {
    /// Width of the border lines, in points.
    static let borderWidth: CGFloat = 2

    /// Width of the stix, in points.
    static let stixWidth: CGFloat = 2

    /// Width of each segment of the Qix's trail, in points.
    static let qixWidth: CGFloat = 1.5

    /// Radius of the fuse's bright dot, in points.
    static let fuseRadius: CGFloat = 2.5

    /// Radius of the outermost ring of the fuse's glow, in points.
    static let fuseGlowRadius: CGFloat = 7

    /// Translucent rings the fuse's glow is made of: they stack towards the dot, so the glow fades
    /// outwards.
    static let fuseGlowRings = 3

    /// Opacity of each ring of the fuse's glow.
    static let fuseGlowOpacity: Double = 0.3

    /// Paints `scene`'s board and enemies on the board of `layout`.
    static func paint(_ context: inout GraphicsContext, _ scene: PlayfieldScene, _ layout: PlayfieldLayout) {
        if let claimed = scene.board.claimed {
            context.draw(Image(decorative: claimed, scale: 1).interpolation(.none), in: layout.field)
        }
        if let claim = scene.claim {
            claimFill(&context, claim.runs, progress: claim.progress, layout)
        }
        border(&context, scene.board.border, layout)
        let game = scene.game
        if let stix = game.stix {
            self.stix(&context, stix, ticks: game.ticks, layout)
        }
        let marker = Vec2(layout.position(game.marker.pos))
        sprite(&context, Sprite.marker(centre: marker, pixel: Sprite.pixel, inner: BoardShapes.markerInner(game.stix)))
        for qix in game.qix {
            trail(&context, qix, ticks: game.ticks, layout)
        }
        let frame = BoardShapes.sparkFrame(ticks: game.ticks)
        for sparx in game.sparx {
            sprite(&context, Sprite.spark(frame, centre: Vec2(layout.position(sparx.pos)), kind: sparx.kind))
        }
        if let point = BoardShapes.fusePoint(game) {
            fuse(&context, at: layout.position(point))
        }
    }

    /// Paints `squares`, a sprite's pixels, one path per colour and without antialiasing, so pixels
    /// that share an edge leave no seam. The pixels never overlap, so the colours' order is free.
    static func sprite(_ context: inout GraphicsContext, _ squares: [SpriteSquare]) {
        for (colour, squares) in Dictionary(grouping: squares, by: \.colour) {
            let path = Path { path in
                path.addRects(squares.map {
                    CGRect(x: CGFloat($0.x), y: CGFloat($0.y), width: CGFloat($0.side), height: CGFloat($0.side))
                })
            }
            context.fill(path, with: .color(Color(colour)), style: FillStyle(antialiased: false))
        }
    }

    /// Paints the cells of `runs`, those of the claim being animated, `progress` through its
    /// animation: one path per kind over the fill the claimed cells' image paints them with.
    private static func claimFill(
        _ context: inout GraphicsContext, _ runs: [CellRun], progress: Float, _ layout: PlayfieldLayout
    ) {
        for kind in [DrawKind.fast, .slow] {
            let path = Path { path in
                path.addRects(runs.filter { $0.kind == kind }.map { layout.rect(of: $0) })
            }
            context.fill(path, with: .color(Color(BoardShapes.fillColour(kind, progress: progress))))
        }
    }

    /// Paints the border's segments, their ends squared off so that the corners are filled.
    private static func border(
        _ context: inout GraphicsContext,
        _ segments: [LatticeSegment],
        _ layout: PlayfieldLayout
    ) {
        let path = Path { path in
            for segment in segments {
                path.move(to: layout.position(segment.from))
                path.addLine(to: layout.position(segment.to))
            }
        }
        let style = StrokeStyle(lineWidth: borderWidth, lineCap: .square)
        context.stroke(path, with: .color(Color(Palette.border)), style: style)
    }

    /// Paints the stix, each run of segments in the colour of its kind as it flickers after `ticks`
    /// game ticks (`BoardShapes.stixColour`).
    private static func stix(_ context: inout GraphicsContext, _ stix: Stix, ticks: UInt64, _ layout: PlayfieldLayout) {
        for run in BoardShapes.stixRuns(stix) {
            let path = Path { $0.addLines(run.points.map { layout.position($0) }) }
            let style = StrokeStyle(lineWidth: stixWidth, lineCap: .square, lineJoin: .miter)
            context.stroke(path, with: .color(Color(BoardShapes.stixColour(run.kind, ticks: ticks))), style: style)
        }
    }

    /// Paints a Qix's trail, oldest segment first, so the current segment lies on top.
    private static func trail(
        _ context: inout GraphicsContext,
        _ qix: QixKit.Qix,
        ticks: UInt64,
        _ layout: PlayfieldLayout
    ) {
        let colours = BoardShapes.trailColours(qix.trail.count, ticks: ticks)
        for ((a, b), colour) in zip(qix.trail, colours) {
            let segment = Path { $0.addLines([layout.position(a), layout.position(b)]) }
            context.stroke(segment, with: .color(Color(colour)), lineWidth: qixWidth)
        }
    }

    /// Paints the fuse at `centre`: the rings of its glow, outermost first, then its bright dot.
    private static func fuse(_ context: inout GraphicsContext, at centre: CGPoint) {
        let step = (fuseGlowRadius - fuseRadius) / CGFloat(fuseGlowRings)
        let glow = Color(Palette.fuseGlow).opacity(fuseGlowOpacity)
        for ring in 0 ..< fuseGlowRings {
            context.fill(circle(centre, fuseGlowRadius - step * CGFloat(ring)), with: .color(glow))
        }
        context.fill(circle(centre, fuseRadius), with: .color(Color(Palette.fuse)))
    }

    private static func circle(_ centre: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: 2 * radius, height: 2 * radius))
    }
}
