import QixKit
import SwiftUI
import UIKit

/// Reads the hardware keyboard's keys of `KeyMap` as they go down and up, through a view that
/// keeps the first responder while active; the other keys go on up the responder chain. Inactive,
/// it gives the first responder up, so the keys reach a text field or a sheet instead.
struct HardwareKeyboard: UIViewRepresentable {
    var isActive = true
    let onDown: @MainActor (Control) -> Void
    let onUp: @MainActor (Control) -> Void
    /// The keyboard's presses were cancelled: every key is up.
    let onCancel: @MainActor () -> Void

    func makeUIView(context _: Context) -> KeyboardView {
        KeyboardView()
    }

    func updateUIView(_ view: KeyboardView, context _: Context) {
        view.onDown = onDown
        view.onUp = onUp
        view.onCancel = onCancel
        view.setActive(isActive)
    }
}

/// The view that takes the keyboard's presses.
final class KeyboardView: UIView {
    var onDown: @MainActor (Control) -> Void = { _ in }
    var onUp: @MainActor (Control) -> Void = { _ in }
    var onCancel: @MainActor () -> Void = {}
    /// The view is to keep the first responder.
    private(set) var isActive = true

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setActive(isActive)
    }

    /// Takes the first responder back when `active` and in a window (a text field or a sheet may
    /// have taken it), or gives it up when not.
    func setActive(_ active: Bool) {
        isActive = active
        if active, window != nil, !isFirstResponder {
            becomeFirstResponder()
        } else if !active, isFirstResponder {
            resignFirstResponder()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let others = handle(presses, onDown)
        if !others.isEmpty {
            super.pressesBegan(others, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let others = handle(presses, onUp)
        if !others.isEmpty {
            super.pressesEnded(others, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        onCancel()
        super.pressesCancelled(presses, with: event)
    }

    /// Hands the control of each press of `presses` to `action`; returns the presses of no control.
    private func handle(_ presses: Set<UIPress>, _ action: @MainActor (Control) -> Void) -> Set<UIPress> {
        presses.filter { press in
            guard let usage = press.key?.keyCode, let control = KeyMap.control(usage) else { return true }
            action(control)
            return false
        }
    }
}
