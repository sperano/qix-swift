import SwiftUI

@main
struct QixApp: App {
    @State private var model = GameModel()

    var body: some Scene {
        WindowGroup {
            GameView(model: model)
        }
    }
}
