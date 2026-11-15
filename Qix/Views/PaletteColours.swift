import QixKit
import SwiftUI

extension Palette {
    /// Around the letterboxed playfield, out to the screen's edges. The launch screen shows the same
    /// asset, so nothing flashes when the app opens.
    static let backdrop = Color(.backdrop)
}

extension Color {
    /// `colour` from QixKit's palette, in sRGB.
    init(_ colour: RGBA) {
        let channel = { (value: UInt8) in Double(value) / Double(UInt8.max) }
        self.init(
            .sRGB, red: channel(colour.red), green: channel(colour.green), blue: channel(colour.blue),
            opacity: channel(colour.alpha)
        )
    }
}
