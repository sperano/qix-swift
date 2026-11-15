import CoreGraphics
import XCTest
@testable import Qix

/// A strip whose width is 10 points per unit of `HudLayout.columnWeights`.
private let strip = CGRect(x: 10, y: 5, width: 220, height: 20)

/// Where the tests centre the lives and the meter.
private let centre = CGPoint(x: 100, y: 50)

/// Tolerance for comparing screen coordinates, in points.
private let epsilon: CGFloat = 1e-9

final class HudLayoutTests: XCTestCase {
    func testTheColumnsSpanTheStripSideBySideByTheirWeights() {
        let widths: [CGFloat] = [30, 30, 20, 30, 40, 30, 20, 20]
        var left = strip.minX
        let expected = widths.map { width in
            defer { left += width }
            return CGRect(x: left, y: strip.minY, width: width, height: strip.height)
        }

        XCTAssertEqual(HudLayout.columns(in: strip), expected)
        XCTAssertEqual(expected.last?.maxX, strip.maxX)
    }

    func testThePauseButtonHasTheLastColumn() {
        XCTAssertEqual(HudLayout.rect(of: .pause, in: strip), CGRect(x: 210, y: 5, width: 20, height: 20))
        XCTAssertEqual(HudLayout.Column.allCases.count, HudLayout.columnWeights.count)
    }

    func testLivesAreARowOfMarkersCentredOnTheColumn() {
        let lives = HudLayout.lifeCentres(3, centre: centre, height: strip.height)

        // 1.3 marker sizes of 0.24 strip heights apart: 6.24 points.
        let xs = lives.map(\.x)
        XCTAssertEqual(xs.count, 3)
        XCTAssertEqual(xs[0], 93.76, accuracy: epsilon)
        XCTAssertEqual(xs[1], 100, accuracy: epsilon)
        XCTAssertEqual(xs[2], 106.24, accuracy: epsilon)
        XCTAssertEqual(Set(lives.map(\.y)), [centre.y])
    }

    func testNoLifeIsNoMarker() {
        XCTAssertEqual(HudLayout.lifeCentres(0, centre: centre, height: strip.height), [])
    }

    func testAsManyMarkersAsLivesUpToTheMostShown() {
        for lives in 0 ... HudLayout.maxLifeMarkers {
            XCTAssertEqual(HudLayout.lifeCentres(lives, centre: centre, height: strip.height).count, Int(lives))
        }
    }

    func testMoreLivesShowAsOneMarkerLeftOfTheCentre() {
        let lives = HudLayout.lifeCentres(HudLayout.maxLifeMarkers + 1, centre: centre, height: strip.height)

        XCTAssertEqual(lives.count, 1)
        XCTAssertEqual(lives[0].x, 100 - 3.12, accuracy: epsilon)
    }

    func testTheMeterFillsItsShareOfTheBarFromTheLeft() {
        let (frame, fill) = HudLayout.meterRects(fraction: 0.5, centre: centre, columnWidth: 40, height: strip.height)

        XCTAssertEqual(frame, CGRect(x: 84, y: 48, width: 32, height: 4))
        XCTAssertEqual(fill, CGRect(x: 84, y: 48, width: 16, height: 4))
    }

    func testTheMeterFillStaysInsideTheBar() {
        let over = HudLayout.meterRects(fraction: 1.5, centre: centre, columnWidth: 40, height: strip.height)
        let under = HudLayout.meterRects(fraction: -1, centre: centre, columnWidth: 40, height: strip.height)

        XCTAssertEqual(over.fill, over.frame)
        XCTAssertEqual(under.fill.width, 0)
    }

    func testEachFieldIsNamedButThePauseButton() {
        let names = HudLayout.Column.allCases.map(HudPainter.label)

        XCTAssertEqual(names, ["SCORE", "HIGH SCORE", "LEVEL", "LIVES", "CLAIMED", "SPARX", "MULTIPLIER", nil])
    }
}
