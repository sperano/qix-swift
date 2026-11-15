import Testing
import XCTest
@testable import QixKit

/// A capacity spanning more than one word, ending inside the last one.
private let capacity = 130

final class BitSetTests: XCTestCase {
    func testANewSetIsEmpty() {
        let set = BitSet(capacity: capacity)

        XCTAssertEqual(set.capacity, capacity)
        XCTAssertEqual(set.count(), 0)
        XCTAssert((0 ..< capacity).allSatisfy { !set.contains($0) })
    }

    func testInsertedIndicesAreContained() {
        var set = BitSet(capacity: capacity)

        for index in [0, 63, 64, capacity - 1] {
            XCTAssert(set.insert(index))
        }

        XCTAssertEqual(set.count(), 4)
        XCTAssert(set.contains(0) && set.contains(63))
        XCTAssert(set.contains(64) && set.contains(capacity - 1))
        XCTAssert(!set.contains(1) && !set.contains(65))
    }

    func testInsertingTwiceReportsTheIndexWasThere() {
        var set = BitSet(capacity: capacity)

        XCTAssert(set.insert(7))
        XCTAssertFalse(set.insert(7))
        XCTAssertEqual(set.count(), 1)
    }

    func testAnIndexPastTheCapacityIsNeverContained() {
        let set = BitSet(capacity: capacity)

        XCTAssertFalse(set.contains(capacity))
        XCTAssertFalse(set.contains(.max))
    }

    /// Swift's `Int` index can be negative, unlike Rust's `usize`.
    func testANegativeIndexIsNeverContained() {
        var set = BitSet(capacity: capacity)
        set.insert(0)

        XCTAssertFalse(set.contains(-1))
        XCTAssertFalse(set.contains(.min))
    }

    func testACapacityOfWholeWordsHoldsItsLastIndex() {
        let wholeWords = 2 * UInt64.bitWidth
        var set = BitSet(capacity: wholeWords)

        XCTAssert(set.insert(wholeWords - 1))
        XCTAssertEqual(set.count(), 1)
    }
}

/// Rust's `#[should_panic]` tests, as exit tests (TrapExpectation.swift).
struct BitSetTrapTests {
    @Test func insertingPastTheCapacityTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            var set = BitSet(capacity: 130)
            set.insert(130)
        }
        expectMessage(result, "past the capacity")
    }

    @Test func insertingANegativeIndexTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            var set = BitSet(capacity: 130)
            set.insert(-1)
        }
        expectMessage(result, "index -1 is negative")
    }
}
