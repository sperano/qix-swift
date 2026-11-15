import QixKit
import SwiftUI

/// The whole screen: the board letterboxed on the backdrop with the HUD above it, the screen of the
/// session's state over the board and the HUD's pause button. A tap anywhere else confirms.
struct PlayfieldView: View {
    /// What UI tests find the board by.
    static let playfieldIdentifier = "playfield"

    let scene: PlayfieldScene
    var onTap: @MainActor () -> Void = {}
    var onPause: @MainActor () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            let layout = PlayfieldLayout(in: CGRect(origin: .zero, size: proxy.size))
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color(Palette.playfieldBackground))
                    .frame(width: layout.field.width, height: layout.field.height)
                    .position(x: layout.field.midX, y: layout.field.midY)
                    .accessibilityElement()
                    .accessibilityLabel("Playfield")
                    .accessibilityIdentifier(Self.playfieldIdentifier)
                Canvas { context, _ in
                    BoardPainter.paint(&context, scene, layout)
                    HudPainter.paint(&context, scene.hud, in: layout.hud)
                }
                .accessibilityHidden(true)
                if let screen = scene.screen {
                    ScreenView(screen: screen, field: layout.field)
                }
                if let role = scene.pauseButton {
                    PauseButton(role: role, column: HudLayout.rect(of: .pause, in: layout.hud), action: onPause)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
        .background(Palette.backdrop)
    }
}
