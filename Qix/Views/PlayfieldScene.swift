import CoreGraphics
import Foundation
import QixKit

/// Everything one frame draws: the game, what is drawn of its board, the HUD, the screen over the
/// board or the prompt of the initials field, the HUD's button and the touch controls, as the
/// settings place them, with the steering's target.
struct PlayfieldScene {
    let game: Game
    let board: BoardImage
    let hud: Hud
    /// The screen over the board, none in play and while the initials field asks for initials.
    let screen: Screen?
    /// What the initials field asks, shown with it instead of a screen while the session waits
    /// for initials.
    let initialsPrompt: Screen?
    /// The button in the HUD's last column: pause or resume in play, the settings on the title.
    let hudButton: HudButtonRole?
    let stick: FloatingStick
    let slowHeld: Bool
    /// The lattice point the finger steers the marker to, in play only.
    let cursor: Point?
    /// The settings, which place the touch controls and set their size and opacity.
    let settings: Settings

    /// The scene of `session`, whose board `board` was drawn from, with the touch controls as
    /// `touches` hold them and `settings` place them, and the target of `steering` in play.
    init(
        session: Session, board: BoardImage, touches: TouchControls<ObjectIdentifier> = TouchControls(),
        steering: TouchSteering = TouchSteering(), settings: Settings = Settings()
    ) {
        let screen = Screen(session: session)
        let entersInitials = if case .highScoreEntry = session.state { true } else { false }
        self.init(
            game: session.game, board: board, hud: Hud(game: session.game, highScore: session.highScore),
            screen: entersInitials ? nil : screen, initialsPrompt: entersInitials ? screen : nil,
            hudButton: HudButtonRole(session.state), stick: touches.stick, slowHeld: touches.slowHeld,
            cursor: session.state == .playing ? steering.target(on: session.game.board) : nil, settings: settings
        )
    }

    init(
        game: Game, board: BoardImage, hud: Hud, screen: Screen?, initialsPrompt: Screen? = nil,
        hudButton: HudButtonRole?, stick: FloatingStick = FloatingStick(), slowHeld: Bool = false,
        cursor: Point? = nil, settings: Settings = Settings()
    ) {
        self.game = game
        self.board = board
        self.hud = hud
        self.screen = screen
        self.initialsPrompt = initialsPrompt
        self.hudButton = hudButton
        self.stick = stick
        self.slowHeld = slowHeld
        self.cursor = cursor
        self.settings = settings
    }

    /// Where the marker is, as VoiceOver reads it and UI tests find it.
    var markerValue: String {
        let pos = game.marker.pos
        return "Marker at \(pos.x), \(pos.y)"
    }
}

/// What a board draws that changes only when its cells do: the claimed cells as an image of one
/// pixel per cell, and the border.
struct BoardImage {
    /// The board drawn.
    let board: Board
    /// The claimed cells, `nil` if the image could not be made.
    let claimed: CGImage?
    let border: [LatticeSegment]

    init(_ board: Board) {
        self.board = board
        claimed = Self.image(board)
        border = BoardShapes.borderSegments(board)
    }

    /// `board`'s `BoardShapes.claimedPixels` as an sRGB image.
    static func image(_ board: Board) -> CGImage? {
        let pixels = BoardShapes.claimedPixels(board)
        let width = Int(board.width)
        let bytesPerPixel = BoardShapes.bytesPerPixel
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(pixels) as CFData)
        else { return nil }
        return CGImage(
            width: width, height: Int(board.height), bitsPerComponent: UInt8.bitWidth,
            bitsPerPixel: bytesPerPixel * UInt8.bitWidth, bytesPerRow: width * bytesPerPixel, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
