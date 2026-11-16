import QixKit
import SwiftUI

/// Paints the touch controls at the size and the opacity of their layout: the stick's base and
/// knob where the thumb holds them, or faintly in the middle of its zone while not touched, and the
/// Slow button, faint until held. The knob takes the fast stix's colour and the Slow button the
/// slow one's: what each draws.
enum ControlsPainter {
    static func paint(
        _ context: inout GraphicsContext, stick: FloatingStick, slowHeld: Bool, _ layout: ControlsLayout
    ) {
        paintStick(&context, stick, layout)
        if !layout.slow.isEmpty {
            paintSlow(&context, held: slowHeld, layout)
        }
    }

    private static func paintStick(_ context: inout GraphicsContext, _ stick: FloatingStick, _ layout: ControlsLayout) {
        let centre: CGPoint
        let knob: CGPoint
        if let landed = stick.centre, let thumb = stick.thumb {
            centre = CGPoint(landed)
            knob = layout.knob(centre: centre, thumb: CGPoint(thumb))
        } else if !layout.stick.isEmpty {
            centre = layout.stickRest
            knob = centre
        } else {
            return
        }
        let opacity = stick.isTouched ? layout.touchedOpacity : layout.idleOpacity
        let base = circle(at: centre, radius: layout.baseRadius)
        let outline = Color(Palette.hudValue)
        context.fill(base, with: .color(outline.opacity(opacity * ControlsLayout.baseFillShare)))
        context.stroke(base, with: .color(outline.opacity(opacity)), lineWidth: ControlsLayout.lineWidth)
        let knobColour = Color(Palette.fastStix).opacity(opacity)
        context.fill(circle(at: knob, radius: layout.knobRadius), with: .color(knobColour))
    }

    private static func paintSlow(_ context: inout GraphicsContext, held: Bool, _ layout: ControlsLayout) {
        let centre = layout.slowCentre
        let opacity = held ? layout.touchedOpacity : layout.idleOpacity
        let button = circle(at: centre, radius: ControlsLayout.slowRadius)
        context.fill(button, with: .color(Color(Palette.slowStix).opacity(opacity)))
        let label = Color(Palette.hudValue).opacity(opacity)
        context.stroke(button, with: .color(label), lineWidth: ControlsLayout.lineWidth)
        let font = Font.system(size: ControlsLayout.slowRadius * ControlsLayout.slowLabelShare, weight: .bold)
        context.draw(Text("SLOW").font(font).foregroundStyle(label), at: centre)
    }

    /// The circle of `radius` around `centre`.
    private static func circle(at centre: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: 2 * radius, height: 2 * radius))
    }
}
