import XCTest
@testable import QixKit

final class PaletteTests: XCTestCase {
    func testEachDrawKindHasItsFillAndStixColour() {
        XCTAssertEqual(Palette.fill(.fast), Palette.fastFill)
        XCTAssertEqual(Palette.fill(.slow), Palette.slowFill)
        XCTAssertEqual(Palette.stix(.fast), Palette.fastStix)
        XCTAssertEqual(Palette.stix(.slow), Palette.slowStix)
    }

    func testTheMeterTakesTheColourOfTheSparxItLeadsTo() {
        XCTAssertEqual(Palette.meter(.release), Palette.sparx)
        XCTAssertEqual(Palette.meter(.super), Palette.superSparx)
    }

    func testEachSparxKindHasItsColourAndCore() {
        XCTAssertEqual(Palette.sparx(.normal), Palette.sparx)
        XCTAssertEqual(Palette.sparx(.super), Palette.superSparx)
        XCTAssertEqual(Palette.sparxCore(.normal), Palette.sparxCore)
        XCTAssertEqual(Palette.sparxCore(.super), Palette.superSparxCore)
    }

    func testTheHelpersBuildGreysAndTranslucentBlacks() {
        XCTAssertEqual(RGBA.grey(150), RGBA(red: 150, green: 150, blue: 150, alpha: 255))
        XCTAssertEqual(RGBA.black(alpha: 110), RGBA(red: 0, green: 0, blue: 0, alpha: 110))
        XCTAssertEqual(RGBA.transparent.alpha, 0)
    }

    func testALerpStartsOnTheColourAndEndsOnTheOther() {
        let from = RGBA(red: 10, green: 20, blue: 30, alpha: 40)
        let to = RGBA(red: 200, green: 100, blue: 0, alpha: 255)

        XCTAssertEqual(from.lerpToGamma(to, 0), from)
        XCTAssertEqual(from.lerpToGamma(to, 1), to)
    }

    func testALerpRoundsEachChannelToTheNearestValue() {
        let black = RGBA.black(alpha: 0)
        let white = RGBA.grey(.max)

        // 255 / 2 is 127.5, which rounds up; 255 / 4 is 63.75, which rounds up too.
        XCTAssertEqual(black.lerpToGamma(white, 0.5), RGBA(red: 128, green: 128, blue: 128, alpha: 128))
        XCTAssertEqual(black.lerpToGamma(white, 0.25), RGBA(red: 64, green: 64, blue: 64, alpha: 64))
        // 255 / 10 is 25.5, which rounds up; 4 / 10 of 255 is 102.
        XCTAssertEqual(black.lerpToGamma(white, 0.1).red, 26)
        XCTAssertEqual(black.lerpToGamma(white, 0.4).red, 102)
    }

    func testALerpPastEitherEndSaturates() {
        let grey = RGBA.grey(100)
        let white = RGBA.grey(.max)

        XCTAssertEqual(grey.lerpToGamma(white, 2), white)
        XCTAssertEqual(grey.lerpToGamma(white, -1), RGBA(red: 0, green: 0, blue: 0, alpha: 255))
    }
}
