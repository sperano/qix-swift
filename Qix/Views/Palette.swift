import SwiftUI

/// The colours the game is painted with: qix-rs's palette.
enum Palette {
    /// Around the letterboxed playfield, out to the screen's edges. The launch screen shows the same
    /// asset, so nothing flashes when the app opens.
    static let backdrop = Color(.backdrop)

    /// The free area of the playfield: RGB 6, 6, 20.
    static let playfieldBackground = Color(red: 6 / 255, green: 6 / 255, blue: 20 / 255)

    /// The border the marker and the Sparx travel.
    static let border = Color.white
}
