import XCTest
@testable import QixKit

/// Repeats `ticksActing` holds a direction for.
private let repeats: UInt32 = 3

private func buttons(_ fast: Bool, _ slow: Bool) -> InputState {
    InputState(fast: fast, slow: slow)
}

/// The ticks, counted from zero, on which holding `dir` for `ticks` ticks acts.
private func ticksActing(_ dir: Dir?, _ ticks: UInt32) -> [UInt32] {
    var dirRepeat = DirRepeat()
    return (0 ..< ticks).filter { _ in dirRepeat.tick(dir) != nil }
}

final class InputTests: XCTestCase {
    func testNoDrawButtonDrawsNothing() {
        XCTAssertNil(buttons(false, false).drawKind)
    }

    func testEachDrawButtonDrawsItsKind() {
        XCTAssertEqual(buttons(true, false).drawKind, .fast)
        XCTAssertEqual(buttons(false, true).drawKind, .slow)
    }

    func testFastWinsWhenBothDrawButtonsAreHeld() {
        XCTAssertEqual(buttons(true, true).drawKind, .fast)
    }

    func testAHeldDirectionActsAtOnceThenRepeatsAfterTheDelay() {
        let ticks = Tuning.repeatDelayTicks + repeats * Tuning.repeatTicks + 1

        let acting = ticksActing(.up, ticks)

        let repeated = (0 ... repeats).map { Tuning.repeatDelayTicks + $0 * Tuning.repeatTicks }
        XCTAssertEqual(acting, [0] + repeated)
    }

    func testNoDirectionNeverActs() {
        XCTAssertEqual(ticksActing(nil, Tuning.repeatDelayTicks * 2), [])
    }

    func testANewDirectionActsAtOnce() {
        var dirRepeat = DirRepeat()
        dirRepeat.tick(.up)

        XCTAssertEqual(dirRepeat.tick(.left), .left)
        XCTAssertNil(dirRepeat.tick(.left))
    }

    func testAReleasedDirectionActsAtOnceWhenHeldAgain() {
        var dirRepeat = DirRepeat()
        dirRepeat.tick(.up)
        dirRepeat.tick(nil)

        XCTAssertEqual(dirRepeat.tick(.up), .up)
    }

    /// Rust's `saturating_add`: the tick count stops at its maximum where Swift's `+` would trap.
    /// `UInt32.max - repeatDelayTicks` is not a multiple of `repeatTicks`, so neither tick acts.
    func testTheHeldTicksSaturateAtTheirMaximum() {
        var dirRepeat = DirRepeat(held: .up, heldTicks: .max - 1)

        let acting = (0 ..< 2).map { _ in dirRepeat.tick(.up) }

        XCTAssertEqual(acting, [nil, nil])
        XCTAssertEqual(dirRepeat, DirRepeat(held: .up, heldTicks: .max))
    }
}
