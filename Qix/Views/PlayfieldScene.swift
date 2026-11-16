import CoreGraphics
import Foundation
import QixKit

/// Everything one frame draws: the game shown (the attract demo's while one plays), what is drawn
/// of its board and of its claim being animated, the HUD, the screen over the board, the demo's
/// banner or the prompt of the initials field, the HUD's button and the touch controls, as the
/// settings place them, with the steering's target.
struct PlayfieldScene {
    let game: Game
    let board: BoardImage
    /// The cells of the claim being animated and how far the animation is (`ClaimFill.fresh`).
    let claim: (runs: [CellRun], progress: Float)?
    let hud: Hud
    /// The screen over the board, none in play, while the demo plays and while the initials field
    /// asks for initials.
    let screen: Screen?
    /// The banner over the attract demo, which plays on under it, undimmed.
    let banner: Screen?
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

    /// The scene of `loop`, whose game shown `board` was drawn from, with the touch controls as
    /// `touches` hold them and `settings` place them, and the target of its steering in play.
    init(
        loop: GameLoop, board: BoardImage, touches: TouchControls<ObjectIdentifier> = TouchControls(),
        settings: Settings = Settings()
    ) {
        let session = loop.session
        let game = loop.shownGame
        let demo = loop.attract.demo != nil
        let screen = demo ? nil : Screen(session: session)
        let entersInitials = if case .highScoreEntry = session.state { true } else { false }
        self.init(
            game: game, board: board, claim: loop.claimFill.fresh, hud: Hud(game: game, highScore: session.highScore),
            screen: entersInitials ? nil : screen, banner: demo ? .demo : nil,
            initialsPrompt: entersInitials ? screen : nil, hudButton: HudButtonRole(session.state),
            stick: touches.stick, slowHeld: touches.slowHeld,
            cursor: session.state == .playing ? loop.steering.target(on: game.board) : nil, settings: settings
        )
    }

    /// The scene of `session`, as `init(loop:)` draws a loop playing it whose steering is
    /// `steering`.
    init(
        session: Session, board: BoardImage, touches: TouchControls<ObjectIdentifier> = TouchControls(),
        steering: TouchSteering = TouchSteering(), settings: Settings = Settings()
    ) {
        var loop = GameLoop(session: session)
        loop.steering = steering
        self.init(loop: loop, board: board, touches: touches, settings: settings)
    }

    init(
        game: Game, board: BoardImage, claim: (runs: [CellRun], progress: Float)? = nil, hud: Hud, screen: Screen?,
        banner: Screen? = nil, initialsPrompt: Screen? = nil, hudButton: HudButtonRole?,
        stick: FloatingStick = FloatingStick(), slowHeld: Bool = false, cursor: Point? = nil,
        settings: Settings = Settings()
    ) {
        self.game = game
        self.board = board
        self.claim = claim
        self.hud = hud
        self.screen = screen
        self.banner = banner
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
