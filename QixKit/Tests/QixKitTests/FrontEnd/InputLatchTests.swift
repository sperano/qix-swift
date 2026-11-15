import XCTest
@testable import QixKit

final class InputLatchTests: XCTestCase {
    func testAPressInAFrameWithoutTicksReachesTheNextTick() {
        var latch = InputLatch()
        latch.record(InputState(confirm: true))
        latch.record(InputState())

        XCTAssertTrue(latch.nextTick().confirm)
    }

    func testAPressReachesOnlyTheFirstTickOfAFrame() {
        var latch = InputLatch()
        latch.record(InputState(confirm: true, pause: true))

        XCTAssertEqual(latch.nextTick(), InputState(confirm: true, pause: true))
        XCTAssertEqual(latch.nextTick(), InputState())
    }

    func testHeldControlsFollowTheLatestFrameOnEveryTick() {
        var latch = InputLatch()
        let held = InputState(dir: .up, fast: true)
        latch.record(held)

        XCTAssertEqual(latch.nextTick(), held)
        XCTAssertEqual(latch.nextTick(), held)

        latch.record(InputState())
        XCTAssertEqual(latch.nextTick(), InputState())
    }

    func testAPauseInAFrameWithoutTicksReachesTheNextTickWithTheLatestHeldControls() {
        var latch = InputLatch()
        latch.record(InputState(dir: .left, pause: true))
        latch.record(InputState(slow: true))

        XCTAssertEqual(latch.nextTick(), InputState(slow: true, pause: true))
    }
}
