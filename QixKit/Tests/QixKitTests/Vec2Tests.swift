import XCTest
@testable import QixKit

/// Rounding slack of the trigonometric results.
private let epsilon: Float = 1e-6

private func assertNear(_ actual: Vec2, _ expected: Vec2, file: StaticString = #filePath, line: UInt = #line) {
    let error = (actual - expected).length
    XCTAssert(error < epsilon, "\(actual) != \(expected)", file: file, line: line)
}

final class Vec2Tests: XCTestCase {
    func testAddsSubtractsScalesAndNegates() {
        let (first, second) = (Vec2(x: 1, y: 2), Vec2(x: 3, y: -1))

        XCTAssertEqual(first + second, Vec2(x: 4, y: 1))
        XCTAssertEqual(first - second, Vec2(x: -2, y: 3))
        XCTAssertEqual(first * 2, Vec2(x: 2, y: 4))
        XCTAssertEqual(-first, Vec2(x: -1, y: -2))
    }

    func testMeasuresItsLength() {
        XCTAssertEqual(Vec2(x: 3, y: -4).length, 5)
    }

    func testScalesToALength() {
        XCTAssertEqual(Vec2(x: 3, y: -4).withLength(10), Vec2(x: 6, y: -8))
        XCTAssertEqual(Vec2().withLength(10), Vec2())
    }

    func testFindsTheMidpoint() {
        let midpoint = Vec2(x: 1, y: 2).midpoint(Vec2(x: 3, y: 6))

        XCTAssertEqual(midpoint, Vec2(x: 2, y: 4))
    }

    func testAQuarterTurnTakesXOntoY() {
        assertNear(Vec2(x: 2, y: 0).rotated(.pi / 2), Vec2(x: 0, y: 2))
    }

    func testAQuarterTurnTakesYOntoMinusX() {
        assertNear(Vec2(x: 0, y: 1).rotated(.pi / 2), Vec2(x: -1, y: 0))
        assertNear(Vec2(x: 1, y: 1).rotated(.pi / 2), Vec2(x: -1, y: 1))
    }

    func testFromAngleIsTheTurnedUnitVector() {
        assertNear(Vec2.fromAngle(.pi / 2), Vec2(x: 0, y: 1))
        assertNear(Vec2.fromAngle(0), Vec2(x: 1, y: 0))
    }

    func testCrossIsSignedByTheTurn() {
        let (x, y) = (Vec2(x: 1, y: 0), Vec2(x: 0, y: 1))
        XCTAssertEqual(x.cross(y), 1)
        XCTAssertEqual(y.cross(x), -1)
        XCTAssertEqual(x.cross(x * 3), 0)
    }

    func testALatticePointIsTheCornerOfItsCell() {
        XCTAssertEqual(Vec2(Point(x: 3, y: 7)), Vec2(x: 3, y: 7))
    }
}
