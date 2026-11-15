import XCTest
@testable import QixKit

/// Idle ticks `testARunningDemoTicksWithEachIdleTick` runs the demo for.
private let demoTicks: UInt32 = 3

/// Ticks `attract` `ticks` times with nothing held.
private func idle(_ attract: inout Attract, _ ticks: UInt32) {
    for _ in 0 ..< ticks {
        attract.tick(InputState())
    }
}

private func scriptTicks() -> UInt32 {
    Demo.demoScript.reduce(0) { $0 + $1.ticks }
}

private func pressed() -> InputState {
    InputState(dir: .left)
}

final class AttractTests: XCTestCase {
    func testANewAttractModeShowsNoDemo() {
        XCTAssertNil(Attract().demo)
    }

    func testTheDemoStartsAfterTheDelayOfIdleTicks() throws {
        var attract = Attract()

        idle(&attract, Tuning.attractDelayTicks - 1)
        XCTAssertNil(attract.demo)
        idle(&attract, 1)

        let demo = try XCTUnwrap(attract.demo, "a demo")
        XCTAssertEqual(demo.game.ticks, 0)
    }

    func testARunningDemoTicksWithEachIdleTick() throws {
        var attract = Attract()
        idle(&attract, Tuning.attractDelayTicks)

        idle(&attract, demoTicks)

        XCTAssertEqual(try XCTUnwrap(attract.demo, "a demo").game.ticks, UInt64(demoTicks))
    }

    func testInputBeforeTheDelayRestartsTheCount() {
        var attract = Attract()
        idle(&attract, Tuning.attractDelayTicks - 1)

        attract.tick(pressed())
        idle(&attract, Tuning.attractDelayTicks - 1)

        XCTAssertNil(attract.demo)
        idle(&attract, 1)
        XCTAssertNotNil(attract.demo)
    }

    func testInputStopsTheDemoAndRestartsTheCount() {
        var attract = Attract()
        idle(&attract, Tuning.attractDelayTicks + 1)
        XCTAssertNotNil(attract.demo)

        attract.tick(pressed())

        XCTAssertNil(attract.demo)
        idle(&attract, Tuning.attractDelayTicks - 1)
        XCTAssertNil(attract.demo)
        idle(&attract, 1)
        XCTAssertNotNil(attract.demo)
    }

    func testAPressOfConfirmCountsAsInput() {
        var attract = Attract()
        idle(&attract, Tuning.attractDelayTicks)

        attract.tick(InputState(confirm: true))

        XCTAssertNil(attract.demo)
    }

    func testAFinishedDemoGoesBackToIdleAndStartsAgainAfterTheDelay() throws {
        var attract = Attract()
        idle(&attract, Tuning.attractDelayTicks)

        idle(&attract, scriptTicks() - 1)
        XCTAssertNotNil(attract.demo)
        idle(&attract, 1)
        XCTAssertNil(attract.demo)

        idle(&attract, Tuning.attractDelayTicks - 1)
        XCTAssertNil(attract.demo)
        idle(&attract, 1)
        let demo = try XCTUnwrap(attract.demo, "a second demo")
        XCTAssertEqual(demo.game.ticks, 0)
    }

    func testResetDropsTheDemoAndRestartsTheCount() {
        var attract = Attract()
        idle(&attract, Tuning.attractDelayTicks)

        attract.reset()

        XCTAssertNil(attract.demo)
        idle(&attract, Tuning.attractDelayTicks - 1)
        XCTAssertNil(attract.demo)
        idle(&attract, 1)
        XCTAssertNotNil(attract.demo)
    }

    func testResetBeforeTheDelayRestartsTheCount() {
        var attract = Attract()
        idle(&attract, Tuning.attractDelayTicks - 1)

        attract.reset()
        idle(&attract, 1)

        XCTAssertNil(attract.demo)
    }
}
