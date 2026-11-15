import XCTest
@testable import QixKit

final class NumbersTests: XCTestCase {
    func testNumbersBelowAThousandHaveNoSeparator() {
        XCTAssertEqual(Numbers.thousands(0), "0")
        XCTAssertEqual(Numbers.thousands(7), "7")
        XCTAssertEqual(Numbers.thousands(999), "999")
    }

    func testEveryThreeDigitsFromTheRightAreSeparated() {
        XCTAssertEqual(Numbers.thousands(1_000), "1,000")
        XCTAssertEqual(Numbers.thousands(12_345), "12,345")
        XCTAssertEqual(Numbers.thousands(123_456), "123,456")
        XCTAssertEqual(Numbers.thousands(1_234_567), "1,234,567")
    }

    func testTheLargestScoreIsGroupedToo() {
        XCTAssertEqual(Numbers.thousands(.max), "4,294,967,295")
    }
}
