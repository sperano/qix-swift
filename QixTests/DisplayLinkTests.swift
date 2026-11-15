import XCTest
@testable import Qix

final class DisplayLinkTests: XCTestCase {
    func testAFrameStandsForTheTimeSinceTheFrameBefore() {
        XCTAssertEqual(DisplayLink.frameTime(previous: 10, now: 10.25, duration: 0.5), 0.25)
    }

    func testTheFirstFrameStandsForTheDisplaysFrameDuration() {
        XCTAssertEqual(DisplayLink.frameTime(previous: nil, now: 10.25, duration: 0.5), 0.5)
    }

    func testTheLinkAsksForTheTickRate() {
        XCTAssertEqual(DisplayLink.frameRate, 60)
    }
}
