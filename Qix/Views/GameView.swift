import QixKit
import SwiftUI
import UIKit

/// The game on the whole screen: the playfield of `model`, ticked by the display link and steered
/// by the touch controls, the keyboard, the game pad and the taps, the initials field over it
/// after a game that makes the high scores, and the settings sheet. The game pauses when the app
/// leaves the foreground, and the screen stays awake while a game is in play. The keyboard's keys
/// reach the game only while neither the field nor the sheet is open.
struct GameView: View {
    @Bindable var model: GameModel
    @State private var displayLink = DisplayLink()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let scene = model.scene
        ZStack {
            PlayfieldView(
                scene: scene, onTap: { model.tap() }, onPause: { model.pressPause() },
                onSettings: { model.openSettings() }, onTouch: { model.touch($0) }
            )
            .background(
                HardwareKeyboard(
                    isActive: !model.isOnHold, onDown: { model.keyDown($0) }, onUp: { model.keyUp($0) },
                    onCancel: { model.releaseKeys() }
                )
            )
            // The board keeps its layout while the system keyboard is up; the initials field
            // moves above it.
            .ignoresSafeArea(.keyboard)
            if let prompt = scene.initialsPrompt {
                InitialsEntryView(prompt: prompt) { model.enterInitials($0) }
            }
        }
        .sheet(isPresented: $model.isShowingSettings) {
            SettingsView(settings: $model.settings)
        }
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
