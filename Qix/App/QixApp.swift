import Foundation
import SwiftUI

@main
struct QixApp: App {
    @State private var model = GameModel(
        defaults: LaunchOptions.defaults(arguments: ProcessInfo.processInfo.arguments),
        haptics: SystemHaptics(), sounds: SystemSounds()
    )

    var body: some Scene {
        WindowGroup {
            GameView(model: model)
        }
    }
}
