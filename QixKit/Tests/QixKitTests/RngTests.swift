import Testing
import XCTest
@testable import QixKit

/// Values drawn by the sequence tests.
private let draws = 1_000

final class RngTests: XCTestCase {
    func testMatchesTheSplitmix64ReferenceOutput() {
        // First outputs of the reference SplitMix64 seeded with 0.
        var rng = Rng(seed: 0)

        XCTAssertEqual(rng.nextU64(), 0xE220_A839_7B1D_CDAF)
        XCTAssertEqual(rng.nextU64(), 0x6E78_9E6A_A1B9_65F4)
    }

    func testASeedFixesTheSequence() {
        var (first, second) = (Rng(seed: 42), Rng(seed: 42))

        for _ in 0 ..< draws {
            XCTAssertEqual(first.nextU64(), second.nextU64())
        }
    }

    func testDifferentSeedsGiveDifferentSequences() {
        var (first, second) = (Rng(seed: 1), Rng(seed: 2))

        let same = (0 ..< draws).allSatisfy { _ in first.nextU64() == second.nextU64() }

        XCTAssertFalse(same)
    }

    func testFractionsLieInTheUnitInterval() {
        var rng = Rng(seed: 7)

        for _ in 0 ..< draws {
            let value = rng.nextF32()
            XCTAssert((0 ..< 1).contains(value), "\(value)")
        }
    }

    func testRangesStayWithinTheirBounds() {
        var rng = Rng(seed: 7)

        for _ in 0 ..< draws {
            let value = rng.rangeF32(-0.5, 2.0)
            XCTAssert((-0.5 ..< 2.0).contains(value), "\(value)")
        }
    }

    func testAnEmptyRangeGivesItsBound() {
        var rng = Rng(seed: 7)

        XCTAssertEqual(rng.rangeF32(3.0, 3.0), 3.0)
    }

    func testIndicesStayBelowTheirBound() {
        var rng = Rng(seed: 7)

        for _ in 0 ..< draws {
            let index = rng.below(3)
            XCTAssert(index < 3, "\(index)")
        }
    }

    func testIndicesCoverEveryValueBelowTheirBound() {
        var rng = Rng(seed: 7)
        var seen = [false, false, false]

        for _ in 0 ..< draws {
            seen[rng.below(seen.count)] = true
        }

        XCTAssertEqual(seen, [true, true, true])
    }

    func testABoundOfOneAlwaysGivesZero() {
        var rng = Rng(seed: 7)

        XCTAssert((0 ..< draws).allSatisfy { _ in rng.below(1) == 0 })
    }
}

/// The values qix-rs's `Rng` draws for the same seeds, printed by the Rust code (qix-rs d256925):
/// a seed must play the same game in both.
final class RngRustReferenceTests: XCTestCase {
    func testEverySeedDrawsTheRustSequence() {
        let sequences: [(seed: UInt64, values: [UInt64])] = [
            (0, [0xE220_A839_7B1D_CDAF, 0x6E78_9E6A_A1B9_65F4, 0x06C4_5D18_8009_454F]),
            (1, [0x910A_2DEC_8902_5CC1, 0xBEEB_8DA1_658E_EC67, 0xF893_A2EE_FB32_555E]),
            (42, [0xBDD7_3226_2FEB_6E95, 0x28EF_E333_B266_F103, 0x4752_6757_130F_9F52]),
            (.max, [0xE4D9_7177_1B65_2C20, 0xE99F_F867_DBF6_82C9, 0x382F_F84C_B272_81E9]),
        ]

        for (seed, expected) in sequences {
            var rng = Rng(seed: seed)
            XCTAssertEqual(expected.map { _ in rng.nextU64() }, expected, "seed \(seed)")
        }
    }

    func testFractionsAreTheRustFractionsBitForBit() {
        var rng = Rng(seed: 7)

        let bits = (0 ..< 3).map { _ in rng.nextF32().bitPattern }

        XCTAssertEqual(bits, [0x3EC7_97C2, 0x3C89_8780, 0x3F66_9840])
    }

    func testRangesAreTheRustRangesBitForBit() {
        var rng = Rng(seed: 7)

        let bits = (0 ..< 3).map { _ in rng.rangeF32(-0.5, 2.0).bitPattern }

        XCTAssertEqual(bits, [0x3EF2_FB64, 0xBEEA_82D4, 0x3FE0_3E50])
    }

    func testIndicesAreTheRustIndices() {
        var small = Rng(seed: 7)
        var large = Rng(seed: 7)

        XCTAssertEqual((0 ..< 6).map { _ in small.below(1_000) }, [389, 16, 900, 582, 452, 249])
        XCTAssertEqual(
            (0 ..< 3).map { _ in large.below(.max) },
            [3_595_544_800_446_187_243, 154_844_686_297_477_901, 8_308_050_873_407_804_672]
        )
    }
}

/// Rust's `assert!` in `below`, as an exit test (TrapExpectation.swift).
struct RngTrapTests {
    @Test func aBoundOfZeroTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            var rng = Rng(seed: 7)
            _ = rng.below(0)
        }
        expectMessage(result, "no index below 0")
    }
}
