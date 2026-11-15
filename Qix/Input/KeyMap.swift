import QixKit
import UIKit

/// The hardware keyboard's keys and the controls they hold or press, as in qix-rs: the arrows
/// move, Z draws fast, X draws slow, Return confirms and Escape pauses.
enum KeyMap {
    static let controls: [UIKeyboardHIDUsage: Control] = [
        .keyboardUpArrow: .up,
        .keyboardDownArrow: .down,
        .keyboardLeftArrow: .left,
        .keyboardRightArrow: .right,
        .keyboardZ: .fast,
        .keyboardX: .slow,
        .keyboardReturnOrEnter: .confirm,
        .keypadEnter: .confirm,
        .keyboardEscape: .pause,
    ]

    /// The control of the key `usage`, `nil` for a key the game does not use.
    static func control(_ usage: UIKeyboardHIDUsage) -> Control? {
        controls[usage]
    }
}
