import GameController
import QixKit

/// The game pad connected, polled once a frame: its left stick or D-pad, whichever is pushed
/// further, A, B and the menu button.
enum GamePad {
    /// The current pad's controls, `nil` without an extended game pad.
    @MainActor
    static func poll() -> PadState? {
        guard let pad = GCController.current?.extendedGamepad else { return nil }
        let stick = pad.leftThumbstick
        let dpad = pad.dpad
        return PadState(
            x: further(stick.xAxis.value, dpad.xAxis.value),
            y: further(stick.yAxis.value, dpad.yAxis.value),
            south: pad.buttonA.isPressed,
            east: pad.buttonB.isPressed,
            menu: pad.buttonMenu.isPressed
        )
    }

    /// The one of `first` and `second` further from zero.
    private static func further(_ first: Float, _ second: Float) -> Float {
        abs(first) >= abs(second) ? first : second
    }
}
