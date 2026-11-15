import XCTest
@testable import QixKit

/// Frame times to check, in seconds: refresh rates above, at and below the tick rate, and times
/// that do not divide a tick evenly.
private let frameTimes: [Double] = [1.0 / 144, 1.0 / 120, 1.0 / 75, 1.0 / 60, 1.0 / 30, 1.0 / 64, 0.01]

/// Frames run for each frame time.
private let frames: UInt32 = 10_000

private func ticks(_ timestep: inout FixedTimestep, _ dt: Float, _ frames: UInt32) -> UInt32 {
    (0 ..< frames).reduce(0) { sum, _ in sum + timestep.advance(dt) }
}

private let tickPeriod = 1 / Float(Tuning.tickHz)

final class TimestepTests: XCTestCase {
    func testNFramesOfDtRunNTimesDtTimesTickHzTicks() {
        for dt in frameTimes {
            let expected = UInt32((Double(frames) * dt * Double(Tuning.tickHz)).rounded(.down))
            var timestep = FixedTimestep()

            XCTAssertEqual(ticks(&timestep, Float(dt), frames), expected, "dt = \(dt)")
        }
    }

    func testAFrameOfOneTickPeriodRunsExactlyOneTick() {
        var timestep = FixedTimestep()
        for frame in 0 ..< frames {
            XCTAssertEqual(timestep.advance(tickPeriod), 1, "frame \(frame)")
        }
    }

    func testAFrameShorterThanATickCarriesItsTimeOver() {
        var timestep = FixedTimestep()
        let half = tickPeriod / 2

        XCTAssertEqual(timestep.advance(half), 0)
        XCTAssertEqual(timestep.advance(half), 1)
    }

    func testAStallIsCappedAndItsBacklogDropped() {
        var timestep = FixedTimestep()

        XCTAssertEqual(timestep.advance(1), FixedTimestep.maxTicksPerFrame)
        XCTAssertEqual(timestep.advance(tickPeriod), 1)
    }

    func testInvalidFrameTimesRunNoTickAndLeaveTheClockIntact() {
        var timestep = FixedTimestep()

        XCTAssertEqual(timestep.advance(.nan), 0)
        XCTAssertEqual(timestep.advance(-1), 0)
        XCTAssertEqual(timestep.advance(tickPeriod), 1)
    }
}
