import SwiftUI

/// The empty playfield, until the game is drawn: the board's bordered rectangle, letterboxed in the
/// safe area on the backdrop.
struct PlaceholderView: View {
    /// What UI tests find the playfield by.
    static let playfieldIdentifier = "playfield"

    var body: some View {
        GeometryReader { proxy in
            let field = PlayfieldLayout.letterbox(in: CGRect(origin: .zero, size: proxy.size))
            Rectangle()
                .strokeBorder(Palette.border, lineWidth: PlayfieldLayout.borderWidth)
                .background(Palette.playfieldBackground)
                .frame(width: field.width, height: field.height)
                .position(x: field.midX, y: field.midY)
                .accessibilityElement()
                .accessibilityLabel("Playfield")
                .accessibilityIdentifier(Self.playfieldIdentifier)
        }
        .background(Palette.backdrop)
        .statusBarHidden()
    }
}
