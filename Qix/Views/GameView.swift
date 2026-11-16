import QixKit
import SwiftUI
import UIKit

/// The game on the whole screen: the playfield of `model`, ticked by the display link and steered
/// by the touch controls, the keyboard, the game pad and the taps. The game pauses when the app leaves the foreground,
/// and the screen stays awake while a game is in play.
struct GameView: View {
    let model: GameModel
    @State private var displayLink = DisplayLink()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        PlayfieldView(
            scene: model.scene, onTap: { model.tap() }, onPause: { model.pressPause() }, onTouch: { model.touch($0) }
        )
        .background(
            HardwareKeyboard(
                onDown: { model.keyDown($0) }, onUp: { model.keyUp($0) }, onCancel: { model.releaseKeys() }
            )
        )
        .onAppear {
            displayLink.start { [model] dt in model.advance(by: dt, pad: GamePad.poll()) }
        }
        .onDisappear { displayLink.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.suspend()
            }
        }
        .onChange(of: model.keepsScreenAwake, initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        .defersSystemGestures(on: .all)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
    }
}
