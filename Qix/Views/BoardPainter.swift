import QixKit
import SwiftUI

/// Paints the board and its enemies: the claimed cells, the border, the stix by kind and the marker
/// (qix-rs's `render/board.rs`), then each Qix's trail, the Sparx and the fuse (`render/enemies.rs`).
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

    /// Distance from the marker's centre to each of its corners, in points.
    static let markerRadius: CGFloat = 5.5

    /// Width of the marker's outline, as a fraction of its radius.
    static let markerOutlineShare: CGFloat = 0.25

    /// Distance from a Sparx's centre to the tip of each of its arms, in points.
    static let sparxRadius: CGFloat = 5.5

    /// Width of a Sparx's arms, in points.
    static let sparxArmWidth: CGFloat = 1.5

    /// Radius of a Sparx's bright heart, in points.
    static let sparxCoreRadius: CGFloat = 1.75

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
        border(&context, scene.board.border, layout)
        let game = scene.game
        if let stix = game.stix {
            self.stix(&context, stix, layout)
        }
        marker(
            &context,
            at: layout.position(game.marker.pos),
            radius: markerRadius,
            inner: BoardShapes.markerInner(game.stix)
        )
        for qix in game.qix {
            trail(&context, qix, ticks: game.ticks, layout)
        }
        for sparx in game.sparx {
            self.sparx(&context, sparx, layout)
        }
        if let point = BoardShapes.fusePoint(game) {
            fuse(&context, at: layout.position(point))
        }
    }

    /// Paints the marker centred on `centre`: a diamond `radius` from its centre to each corner,
    /// `inner` inside its outline.
    static func marker(_ context: inout GraphicsContext, at centre: CGPoint, radius: CGFloat, inner: RGBA) {
        let diamond = Path { path in
            path.move(to: CGPoint(x: centre.x, y: centre.y - radius))
            path.addLine(to: CGPoint(x: centre.x + radius, y: centre.y))
            path.addLine(to: CGPoint(x: centre.x, y: centre.y + radius))
            path.addLine(to: CGPoint(x: centre.x - radius, y: centre.y))
            path.closeSubpath()
        }
        context.fill(diamond, with: .color(Color(inner)))
        context.stroke(diamond, with: .color(Color(Palette.markerOutline)), lineWidth: radius * markerOutlineShare)
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

    /// Paints the stix, each run of segments in the colour of its kind.
    private static func stix(_ context: inout GraphicsContext, _ stix: Stix, _ layout: PlayfieldLayout) {
        for run in BoardShapes.stixRuns(stix) {
            let path = Path { $0.addLines(run.points.map { layout.position($0) }) }
            let style = StrokeStyle(lineWidth: stixWidth, lineCap: .square, lineJoin: .miter)
            context.stroke(path, with: .color(Color(Palette.stix(run.kind))), style: style)
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

    /// Paints a Sparx on its lattice point: a cross in the colour of its kind around a bright heart.
    private static func sparx(_ context: inout GraphicsContext, _ sparx: Sparx, _ layout: PlayfieldLayout) {
        let centre = layout.position(sparx.pos)
        let arms = Path { path in
            path.addLines([
                CGPoint(x: centre.x - sparxRadius, y: centre.y),
                CGPoint(x: centre.x + sparxRadius, y: centre.y),
            ])
            path.addLines([
                CGPoint(x: centre.x, y: centre.y - sparxRadius),
                CGPoint(x: centre.x, y: centre.y + sparxRadius),
            ])
        }
        context.stroke(arms, with: .color(Color(Palette.sparx(sparx.kind))), lineWidth: sparxArmWidth)
        context.fill(circle(centre, sparxCoreRadius), with: .color(Color(Palette.sparxCore(sparx.kind))))
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
