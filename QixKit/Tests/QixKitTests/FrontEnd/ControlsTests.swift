import XCTest
@testable import QixKit

/// Controls with the keys of `held` down.
private func keysDown(_ held: [Control]) -> Controls {
    var controls = Controls()
    held.forEach { controls.keyDown($0) }
    return controls
}

/// A stick deflection past the dead zone.
private let pushed: Float = 0.8

/// A stick deflection inside the dead zone.
private let resting: Float = 0.3

final class ControlsTests: XCTestCase {
    func testNoKeyIsNoInput() {
        var controls = Controls()

        XCTAssertEqual(controls.sample(), InputState())
    }

    func testHeldKeysSetTheDirectionAndTheDrawButtons() {
        var controls = keysDown([.left, .fast, .slow])

        XCTAssertEqual(controls.sample(), InputState(dir: .left, fast: true, slow: true))
        XCTAssertEqual(controls.sample(), InputState(dir: .left, fast: true, slow: true))
    }

    func testEachDirectionControlHoldsItsDirection() {
        for (control, dir) in Control.dirs {
            var controls = keysDown([control])

            XCTAssertEqual(controls.sample().dir, dir, "\(control)")
            XCTAssertEqual(Control(dir), control)
        }
    }

    func testTheFirstDirectionInPriorityOrderWins() {
        var controls = keysDown([.right, .down])

        XCTAssertEqual(controls.sample().dir, .down)
    }

    func testAReleasedKeyIsNoLongerHeld() {
        var controls = keysDown([.up, .fast])
        controls.keyUp(.up)

        XCTAssertEqual(controls.sample(), InputState(fast: true))
    }

    func testReleasingEveryKeyLeavesNothingHeld() {
        var controls = keysDown([.up, .fast, .slow])
        controls.releaseKeys()

        XCTAssertEqual(controls.held, [])
        XCTAssertEqual(controls.sample(), InputState())
    }

    func testAKeyPressConfirmsOrPausesOnceUntilSampled() {
        var controls = keysDown([.confirm, .pause])

        XCTAssertEqual(controls.sample(), InputState(confirm: true, pause: true))
        XCTAssertEqual(controls.sample(), InputState())
    }

    func testAKeyRepeatIsNoPress() {
        var controls = keysDown([.confirm])
        _ = controls.sample()

        controls.keyDown(.confirm)

        XCTAssertFalse(controls.sample().confirm)
    }

    func testAKeyPressedAgainAfterItsReleaseIsAPress() {
        var controls = keysDown([.pause])
        _ = controls.sample()
        controls.keyUp(.pause)
        controls.keyDown(.pause)

        XCTAssertTrue(controls.sample().pause)
    }

    func testAPressReleasedBeforeTheSampleStillCounts() {
        var controls = keysDown([.confirm])
        controls.keyUp(.confirm)

        XCTAssertTrue(controls.sample().confirm)
    }

    func testATapIsAPress() {
        var controls = Controls()
        controls.press(.confirm)

        XCTAssertEqual(controls.sample(), InputState(confirm: true))
        XCTAssertEqual(controls.held, [])
    }

    func testDroppedPressesAreNotSampled() {
        var controls = keysDown([.confirm, .up])
        controls.press(.pause)
        controls.dropPresses()

        XCTAssertEqual(controls.sample(), InputState(dir: .up))
    }

    func testThePadHoldsItsControlsAndPressesTheNewOnes() {
        var controls = Controls()
        controls.setPad([.left, .confirm])

        XCTAssertEqual(controls.sample(), InputState(dir: .left, confirm: true))
        controls.setPad([.left, .confirm])
        XCTAssertEqual(controls.sample(), InputState(dir: .left))
        controls.setPad([])
        XCTAssertEqual(controls.sample(), InputState())
    }

    func testAControlHeldOnBothDevicesIsPressedOnceAndHeldUntilBothRelease() {
        var controls = keysDown([.pause, .slow])
        controls.setPad([.pause, .slow])

        XCTAssertEqual(controls.sample(), InputState(slow: true, pause: true))
        controls.keyUp(.slow)
        XCTAssertTrue(controls.sample().slow)
        controls.setPad([])
        XCTAssertFalse(controls.sample().slow)
    }

    func testAKeyDownWhileThePadHoldsItIsNoPress() {
        var controls = Controls()
        controls.setPad([.confirm])
        _ = controls.sample()

        controls.keyDown(.confirm)

        XCTAssertFalse(controls.sample().confirm)
    }

    func testTheTouchControlsHoldTheirControlsUntilSetAgain() {
        var controls = Controls()
        controls.setTouch([.left, .fast])

        XCTAssertEqual(controls.sample(), InputState(dir: .left, fast: true))
        XCTAssertEqual(controls.sample(), InputState(dir: .left, fast: true))
        controls.setTouch([.slow])
        XCTAssertEqual(controls.sample(), InputState(slow: true))
        controls.setTouch([])
        XCTAssertEqual(controls.sample(), InputState())
    }

    func testAControlHeldByTouchAndKeyIsHeldUntilBothRelease() {
        var controls = keysDown([.up])
        controls.setTouch([.up, .fast])

        controls.keyUp(.up)
        XCTAssertEqual(controls.held, [.up, .fast])
        controls.setTouch([])
        XCTAssertEqual(controls.held, [])
    }

    func testATouchControlNoDeviceHeldIsPressed() {
        var controls = keysDown([.up])
        _ = controls.sample()
        // Touch holds no press control: hold one only to see the presses `setTouch` records.
        controls.setTouch([.up, .confirm])

        XCTAssertEqual(controls.sample(), InputState(dir: .up, confirm: true))
        controls.setTouch([.up, .confirm])
        XCTAssertFalse(controls.sample().confirm)
    }

    func testATouchOnAControlThePadHoldsIsNoPress() {
        var controls = Controls()
        controls.setPad([.confirm])
        _ = controls.sample()

        controls.setTouch([.confirm])

        XCTAssertFalse(controls.sample().confirm)
        controls.setTouch([])
        XCTAssertEqual(controls.held, [.confirm])
    }

    func testThePadOnAControlATouchHoldsIsNoPress() {
        var controls = Controls()
        controls.setTouch([.confirm])
        _ = controls.sample()

        controls.setPad([.confirm])

        XCTAssertFalse(controls.sample().confirm)
        controls.setPad([])
        XCTAssertEqual(controls.held, [.confirm])
    }

    func testReleasingTheKeysLeavesTheTouchControlsHeld() {
        var controls = keysDown([.up])
        controls.setTouch([.slow])
        controls.releaseKeys()

        XCTAssertEqual(controls.held, [.slow])
    }

    func testReleasingTheKeysLeavesThePadHeld() {
        var controls = keysDown([.up])
        controls.setPad([.fast])
        controls.releaseKeys()

        XCTAssertEqual(controls.held, [.fast])
    }
}

final class PadStateTests: XCTestCase {
    func testARestingPadHoldsNothing() {
        XCTAssertNil(PadState().dir)
        XCTAssertEqual(PadState().controls, [])
    }

    func testTheStickHoldsTheDirectionOfItsDominantAxis() {
        XCTAssertEqual(PadState(x: pushed, y: resting).dir, .right)
        XCTAssertEqual(PadState(x: -pushed, y: -resting).dir, .left)
        XCTAssertEqual(PadState(x: resting, y: pushed).dir, .up)
        XCTAssertEqual(PadState(x: -resting, y: -pushed).dir, .down)
    }

    func testTheDeadZoneHoldsNoDirection() {
        XCTAssertNil(PadState(x: resting).dir)
        XCTAssertNil(PadState(y: -resting).dir)
    }

    func testTheDeadZoneEdgeHoldsTheDirection() {
        XCTAssertEqual(PadState(x: PadState.deadZone).dir, .right)
    }

    func testADiagonalOfEqualAxesHoldsNoDirection() {
        XCTAssertNil(PadState(x: pushed, y: pushed).dir)
    }

    func testEachButtonHoldsItsControls() {
        XCTAssertEqual(PadState(south: true).controls, [.fast, .confirm])
        XCTAssertEqual(PadState(east: true).controls, [.slow])
        XCTAssertEqual(PadState(menu: true).controls, [.pause])
    }

    func testTheDirectionJoinsTheButtons() {
        XCTAssertEqual(PadState(y: pushed, east: true).controls, [.up, .slow])
    }
}
