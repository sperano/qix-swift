import XCTest
@testable import Qix

final class GamePadTests: XCTestCase {
    func testTheDPadWinsWhenPushedFurther() {
        XCTAssertEqual(GamePad.further(0.2, -1), -1)
    }

    func testTheStickWinsWhenPushedFurther() {
        XCTAssertEqual(GamePad.further(0.8, 0), 0.8)
    }

    func testATieKeepsTheStick() {
        XCTAssertEqual(GamePad.further(-0.5, 0.5), -0.5)
    }
}
