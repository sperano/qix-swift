import XCTest
@testable import QixKit

/// Tolerance for comparing screen coordinates, in points.
private let spriteEpsilon: Float = 1e-3

/// A centre to place sprites around.
private let spriteCentre = Vec2(x: 40, y: 30)

/// Points per sprite pixel in the tests that do not use `Sprite.pixel`.
private let bigPixel: Float = 4

private let white = RGBA.grey(.max)

private let allMasks = [Sprite.markerMask] + Sprite.sparkFrames

/// The smallest rectangle holding every square of `squares`.
private func bounds(_ squares: [SpriteSquare]) -> (min: Vec2, max: Vec2) {
    (
        Vec2(x: squares.map(\.x).min() ?? 0, y: squares.map(\.y).min() ?? 0),
        Vec2(x: squares.map { $0.x + $0.side }.max() ?? 0, y: squares.map { $0.y + $0.side }.max() ?? 0)
    )
}

/// Asserts `squares` are centred on `centre` and `width` by `height` sprite pixels of `pixel`.
private func assertPlaced(
    _ squares: [SpriteSquare], width: Int, height: Int, pixel: Float, file: StaticString = #filePath,
    line: UInt = #line
) {
    let (low, high) = bounds(squares)
    XCTAssertEqual((low.x + high.x) / 2, spriteCentre.x, accuracy: spriteEpsilon, file: file, line: line)
    XCTAssertEqual((low.y + high.y) / 2, spriteCentre.y, accuracy: spriteEpsilon, file: file, line: line)
    XCTAssertEqual(high.x - low.x, Float(width) * pixel, accuracy: spriteEpsilon, file: file, line: line)
    XCTAssertEqual(high.y - low.y, Float(height) * pixel, accuracy: spriteEpsilon, file: file, line: line)
}

private func count(_ squares: [SpriteSquare], _ colour: RGBA) -> Int {
    squares.filter { $0.colour == colour }.count
}

private func roles(_ mask: Sprite.Mask, _ role: Character) -> Int {
    mask.joined().filter { $0 == role }.count
}

final class SpriteTests: XCTestCase {
    func testEveryRowOfAMaskHasTheSameOddWidthAndThereIsAnOddNumberOfRows() {
        for mask in allMasks {
            let (width, height) = Sprite.maskSize(mask)

            XCTAssertTrue(width % 2 == 1 && height % 2 == 1, "\(mask)")
            XCTAssertTrue(mask.allSatisfy { $0.count == width }, "\(mask)")
        }
    }

    func testTheSizeOfAnEmptyMaskIsZero() {
        let size = Sprite.maskSize([])

        XCTAssertEqual(size.width, 0)
        XCTAssertEqual(size.height, 0)
    }

    func testTheMiddlePixelOfEveryMaskIsPainted() {
        for mask in allMasks {
            let (width, height) = Sprite.maskSize(mask)
            let middle = Array(mask[height / 2])[width / 2]

            XCTAssertNotEqual(middle, Sprite.transparent, "\(mask)")
        }
    }

    func testTheMarkerIsADiamondSymmetricAboutItsMiddle() {
        let outline = { (row: String) in row.map { $0 == Sprite.transparent } }
        for (row, mirror) in zip(Sprite.markerMask, Sprite.markerMask.reversed()) {
            XCTAssertEqual(outline(row), outline(mirror))
            XCTAssertEqual(outline(row), outline(row).reversed())
        }
    }

    func testTheSparkFramesShareACoreAndDifferInTheirArms() {
        let (plus, cross) = (Sprite.sparkFrames[0], Sprite.sparkFrames[1])

        XCTAssertEqual(Sprite.sparkFrames.count, 2)
        XCTAssertNotEqual(plus, cross)
        XCTAssertEqual(roles(plus, Sprite.core), roles(cross, Sprite.core))
        XCTAssertGreaterThan(roles(plus, Sprite.body), 0)
        XCTAssertGreaterThan(roles(cross, Sprite.body), 0)
    }

    func testThereIsOneSquarePerPaintedPixel() {
        let squares = Sprite.squares(["..X", ".XX", "X.X"], centre: spriteCentre, pixel: bigPixel) { _ in white }

        XCTAssertEqual(squares.count, 5)
    }

    func testTransparentPixelsStayUnpaintedWhateverTheCallerMapsThemTo() {
        let squares = Sprite.squares(["...", ".X.", "..."], centre: spriteCentre, pixel: bigPixel) { _ in white }

        XCTAssertEqual(squares.count, 1)
    }

    func testRolesWithoutAColourStayUnpainted() {
        let squares = Sprite.squares(["XYX"], centre: spriteCentre, pixel: bigPixel) { $0 == "X" ? white : nil }

        XCTAssertEqual(squares.count, 2)
    }

    func testTheSquaresAreCentredOnTheirPointAndSizedByThePixel() {
        let mask = ["XXX", "XXX", "XXX", "XXX", "XXX"]

        let squares = Sprite.squares(mask, centre: spriteCentre, pixel: bigPixel) { _ in white }

        assertPlaced(squares, width: 3, height: 5, pixel: bigPixel)
        XCTAssertTrue(squares.allSatisfy { $0.side == bigPixel })
    }

    func testPixelsKeepTheirPlaceInTheMask() {
        let red = RGBA(red: 255, green: 0, blue: 0)
        let blue = RGBA(red: 0, green: 0, blue: 255)

        let squares = Sprite.squares(["X.", ".Y"], centre: spriteCentre, pixel: bigPixel) { $0 == "X" ? red : blue }

        XCTAssertEqual(
            squares,
            [
                SpriteSquare(x: spriteCentre.x - bigPixel, y: spriteCentre.y - bigPixel, side: bigPixel, colour: red),
                SpriteSquare(x: spriteCentre.x, y: spriteCentre.y, side: bigPixel, colour: blue),
            ]
        )
    }

    func testTheMarkerIsPaintedInItsOutlineHighlightAndInnerColours() {
        let inner = RGBA(red: 1, green: 2, blue: 3)
        let mask = Sprite.markerMask

        let squares = Sprite.marker(centre: spriteCentre, pixel: Sprite.pixel, inner: inner)

        XCTAssertEqual(count(squares, Palette.markerOutline), roles(mask, Sprite.outline))
        XCTAssertEqual(count(squares, Palette.markerHighlight), roles(mask, Sprite.highlight))
        XCTAssertEqual(count(squares, inner), roles(mask, Sprite.inner))
        XCTAssertEqual(
            squares.count, roles(mask, Sprite.outline) + roles(mask, Sprite.highlight) + roles(mask, Sprite.inner)
        )
    }

    func testTheMarkerIsCentredOnItsPoint() {
        let (width, height) = Sprite.maskSize(Sprite.markerMask)

        let squares = Sprite.marker(centre: spriteCentre, pixel: Sprite.pixel, inner: Palette.marker)

        assertPlaced(squares, width: width, height: height, pixel: Sprite.pixel)
    }

    func testASparkIsPaintedInTheBodyAndCoreColoursOfItsKind() {
        let cases: [(SparxKind, RGBA, RGBA)] = [
            (.normal, Palette.sparx, Palette.sparxCore),
            (.super, Palette.superSparx, Palette.superSparxCore),
        ]
        for (kind, body, core) in cases {
            for frame in Sprite.sparkFrames {
                let squares = Sprite.spark(frame, centre: spriteCentre, kind: kind)

                XCTAssertEqual(count(squares, body), roles(frame, Sprite.body))
                XCTAssertEqual(count(squares, core), roles(frame, Sprite.core))
                XCTAssertEqual(squares.count, roles(frame, Sprite.body) + roles(frame, Sprite.core))
            }
        }
    }

    func testASparkIsCentredOnItsPointInEveryFrame() {
        for frame in Sprite.sparkFrames {
            let (width, height) = Sprite.maskSize(frame)

            let squares = Sprite.spark(frame, centre: spriteCentre, kind: .normal)

            assertPlaced(squares, width: width, height: height, pixel: Sprite.pixel)
        }
    }
}
