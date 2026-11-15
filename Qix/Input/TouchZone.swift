import QixKit
import SwiftUI
import UIKit

/// A touch on a control's zone, by the identity of its `UITouch`, at a point in the playfield's
/// coordinates.
enum TouchEvent: Equatable {
    case began(touch: ObjectIdentifier, on: TouchControl, at: CGPoint)
    case moved(touch: ObjectIdentifier, to: CGPoint)
    /// The touch lifted or was cancelled.
    case ended(touch: ObjectIdentifier)
}

/// The zone of a touch control: a clear view over `zone` that hands each of its touches to
/// `onTouch`, wherever the touch moves until it lifts, as UIKit keeps sending a touch to the view
/// it began on.
struct TouchZone: UIViewRepresentable {
    let control: TouchControl
    /// The zone, in the playfield's coordinates.
    let zone: CGRect
    let onTouch: @MainActor (TouchEvent) -> Void

    /// What UI tests find the zone of `control` by.
    static func identifier(_ control: TouchControl) -> String {
        switch control {
        case .stick: "stick"
        case .slow: "slow"
        }
    }

    /// What VoiceOver reads.
    static func label(_ control: TouchControl) -> String {
        switch control {
        case .stick: "Stick"
        case .slow: "Slow"
        }
    }

    func makeUIView(context _: Context) -> TouchZoneView {
        let view = TouchZoneView(control: control)
        view.accessibilityIdentifier = Self.identifier(control)
        view.accessibilityLabel = Self.label(control)
        return view
    }

    func updateUIView(_ view: TouchZoneView, context _: Context) {
        view.origin = zone.origin
        view.onTouch = onTouch
    }
}

/// The view that takes a zone's touches, several at once.
final class TouchZoneView: UIView {
    let control: TouchControl
    /// Where the view's top-left corner is in the playfield's coordinates.
    var origin: CGPoint = .zero
    var onTouch: @MainActor (TouchEvent) -> Void = { _ in }

    init(control: TouchControl) {
        self.control = control
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .allowsDirectInteraction
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        for touch in touches {
            onTouch(.began(touch: ObjectIdentifier(touch), on: control, at: position(touch)))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        for touch in touches {
            onTouch(.moved(touch: ObjectIdentifier(touch), to: position(touch)))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        end(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with _: UIEvent?) {
        end(touches)
    }

    private func end(_ touches: Set<UITouch>) {
        for touch in touches {
            onTouch(.ended(touch: ObjectIdentifier(touch)))
        }
    }

    /// Where `touch` is, in the playfield's coordinates.
    private func position(_ touch: UITouch) -> CGPoint {
        let point = touch.location(in: self)
        return CGPoint(x: origin.x + point.x, y: origin.y + point.y)
    }
}
