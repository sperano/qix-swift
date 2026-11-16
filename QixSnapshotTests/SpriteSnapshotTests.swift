import QixKit
import SwiftUI
import XCTest
@testable import Qix

/// The sprites, magnified on the playfield's background: the marker plain and with the inside of a
/// fast and a slow stix, then both frames of a Sparx and of a Super Sparx.
final class SpriteSnapshotTests: SnapshotTestCase {
    func testTheSprites() throws {
        try assertScreen(SpriteSheet())
    }
}

/// Every sprite in a row, centred on the screen.
private struct SpriteSheet: View {
    /// Points per sprite pixel: large enough to see each one.
    static let pixel: Float = 6

    /// Distance between the centres of two sprites, in points.
    static let spacing: Float = 72

    var body: some View {
        Canvas { context, size in
            let sprites = Self.sprites
            let left = Float(size.width) / 2 - Self.spacing * Float(sprites.count - 1) / 2
            for (i, sprite) in sprites.enumerated() {
                let centre = Vec2(x: left + Self.spacing * Float(i), y: Float(size.height) / 2)
                BoardPainter.sprite(&context, sprite(centre))
            }
        }
        .background(Color(Palette.playfieldBackground))
    }

    /// The sprites, each as its squares around a centre.
    private static var sprites: [(Vec2) -> [SpriteSquare]] {
        let markers = [Palette.marker, Palette.fastStix, Palette.slowStix].map { inner in
            { (centre: Vec2) in Sprite.marker(centre: centre, pixel: pixel, inner: inner) }
        }
        let sparks = [SparxKind.normal, .super].flatMap { kind in
            Sprite.sparkFrames.map { frame in
                { (centre: Vec2) in magnified(Sprite.spark(frame, centre: centre, kind: kind), around: centre) }
            }
        }
        return markers + sparks
    }

    /// `squares`, a sprite of `Sprite.pixel` pixels around `centre`, scaled to `pixel` pixels.
    private static func magnified(_ squares: [SpriteSquare], around centre: Vec2) -> [SpriteSquare] {
        let scale = pixel / Sprite.pixel
        return squares.map {
            SpriteSquare(
                x: centre.x + ($0.x - centre.x) * scale, y: centre.y + ($0.y - centre.y) * scale,
                side: $0.side * scale, colour: $0.colour
            )
        }
    }
}
