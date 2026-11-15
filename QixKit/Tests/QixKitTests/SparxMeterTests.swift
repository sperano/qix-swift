import XCTest
@testable import QixKit

/// Ticks of one countdown of the meters the tests run.
private let length: UInt32 = 5

/// A meter expiry and the tick, from one, it came at, which tuples cannot compare.
private struct Expiry: Equatable {
    let tick: UInt32
    let expiry: MeterExpiry

    init(_ tick: UInt32, _ expiry: MeterExpiry) {
        self.tick = tick
        self.expiry = expiry
    }
}

/// Ticks `meter` `ticks` times and returns the tick, from one, of each
/// expiry with the expiry.
@discardableResult
private func expiries(_ meter: inout SparxMeter, _ ticks: UInt32) -> [Expiry] {
    (1 ... ticks).compactMap { tick in
        meter.tick().map { Expiry(tick, $0) }
    }
}

final class SparxMeterTests: XCTestCase {
    func testANewMeterIsFullAndCountsToTheRelease() {
        let meter = SparxMeter(length: length)

        XCTAssertEqual(meter.length, length)
        XCTAssertEqual(meter.remaining, length)
        XCTAssertEqual(meter.nextExpiry, .release)
    }

    func testEachTickCountsOneDown() {
        var meter = SparxMeter(length: length)

        XCTAssertNil(meter.tick())
        XCTAssertNil(meter.tick())

        XCTAssertEqual(meter.remaining, length - 2)
    }

    func testTheMeterReleasesThenTurnsSuperOneLengthApart() {
        var meter = SparxMeter(length: length)

        let seen = expiries(&meter, 3 * length)

        XCTAssertEqual(seen, [Expiry(length, .release), Expiry(2 * length, .super)])
    }

    func testTheFirstExpiryStartsTheSecondCountdownFull() {
        var meter = SparxMeter(length: length)

        expiries(&meter, length)

        XCTAssertEqual(meter.remaining, length)
        XCTAssertEqual(meter.nextExpiry, .super)
    }

    func testASpentMeterStaysEmpty() {
        var meter = SparxMeter(length: length)
        expiries(&meter, 2 * length)

        XCTAssertNil(meter.tick())

        XCTAssertEqual(meter.remaining, 0)
        XCTAssertNil(meter.nextExpiry)
    }

    func testResetFillsARunningMeter() {
        var meter = SparxMeter(length: length)
        expiries(&meter, length + 1)

        meter.reset()

        XCTAssertEqual(meter, SparxMeter(length: length))
    }

    func testAResetSpentMeterExpiresBothTimesAgain() {
        var meter = SparxMeter(length: length)
        expiries(&meter, 2 * length)

        meter.reset()

        XCTAssertEqual(expiries(&meter, 2 * length), [Expiry(length, .release), Expiry(2 * length, .super)])
    }

    func testAZeroLengthMeterCountsOneTick() {
        var meter = SparxMeter(length: 0)

        XCTAssertEqual(meter.length, 1)
        XCTAssertEqual(meter.tick(), .release)
        XCTAssertEqual(meter.tick(), .super)
    }
}
