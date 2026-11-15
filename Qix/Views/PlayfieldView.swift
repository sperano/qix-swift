import QixKit
import SwiftUI

/// The whole screen: the board letterboxed on the backdrop with the HUD above it, the screen of the
/// session's state over the board, the HUD's pause button, and the touch controls on each side of
/// the board. A tap anywhere but on a control confirms.
struct PlayfieldView: View {
    /// What UI tests find the board by.
    static let playfieldIdentifier = "playfield"

    let scene: PlayfieldScene
    var onTap: @MainActor () -> Void = {}
    var onPause: @MainActor () -> Void = {}
    var onTouch: @MainActor (TouchEvent) -> Void = { _ in }

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            let layout = PlayfieldLayout(in: bounds)
            let controls = ControlsLayout(in: bounds, beside: layout.field)
            // The zones are the board's siblings, not its children: a touch on a zone is the zone's
            // alone and never a tap.
            ZStack(alignment: .topLeading) {
                board(layout, controls)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }
                zone(.stick, controls.stick)
                zone(.slow, controls.slow)
            }
        }
        .background(Palette.backdrop)
    }

    /// The board, the HUD, the screen over the board, the pause button and the controls drawn.
    private func board(_ layout: PlayfieldLayout, _ controls: ControlsLayout) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(Palette.playfieldBackground))
                .frame(width: layout.field.width, height: layout.field.height)
                .position(x: layout.field.midX, y: layout.field.midY)
                .accessibilityElement()
                .accessibilityLabel("Playfield")
                .accessibilityValue(scene.markerValue)
                .accessibilityIdentifier(Self.playfieldIdentifier)
            Canvas { context, _ in
                BoardPainter.paint(&context, scene, layout)
                HudPainter.paint(&context, scene.hud, in: layout.hud)
                ControlsPainter.paint(&context, stick: scene.stick, slowHeld: scene.slowHeld, controls)
            }
            .accessibilityHidden(true)
            if let screen = scene.screen {
                ScreenView(screen: screen, field: layout.field)
            }
            if let role = scene.pauseButton {
                PauseButton(role: role, column: HudLayout.rect(of: .pause, in: layout.hud), action: onPause)
            }
        }
    }

    /// The zone of `control` over `rect`, none when the board leaves it no room.
    @ViewBuilder
    private func zone(_ control: TouchControl, _ rect: CGRect) -> some View {
        if !rect.isEmpty {
            TouchZone(control: control, zone: rect, onTouch: onTouch)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }
}
