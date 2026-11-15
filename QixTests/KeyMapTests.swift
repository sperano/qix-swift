import QixKit
import UIKit
import XCTest
@testable import Qix

final class KeyMapTests: XCTestCase {
    func testTheArrowsMove() {
        XCTAssertEqual(KeyMap.control(.keyboardUpArrow), .up)
        XCTAssertEqual(KeyMap.control(.keyboardDownArrow), .down)
        XCTAssertEqual(KeyMap.control(.keyboardLeftArrow), .left)
        XCTAssertEqual(KeyMap.control(.keyboardRightArrow), .right)
    }

    func testZDrawsFastAndXDrawsSlow() {
        XCTAssertEqual(KeyMap.control(.keyboardZ), .fast)
        XCTAssertEqual(KeyMap.control(.keyboardX), .slow)
    }

    func testBothReturnKeysConfirmAndEscapePauses() {
        XCTAssertEqual(KeyMap.control(.keyboardReturnOrEnter), .confirm)
        XCTAssertEqual(KeyMap.control(.keypadEnter), .confirm)
        XCTAssertEqual(KeyMap.control(.keyboardEscape), .pause)
    }

    func testOtherKeysDoNothing() {
        XCTAssertNil(KeyMap.control(.keyboardA))
        XCTAssertNil(KeyMap.control(.keyboardSpacebar))
    }
}
