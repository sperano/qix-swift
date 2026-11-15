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
}
