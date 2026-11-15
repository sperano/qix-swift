import CoreGraphics
import Foundation
import QixKit

/// Everything one frame draws: the game, what is drawn of its board, the HUD, the screen over the
/// board and the pause button.
struct PlayfieldScene {
    let game: Game
    let board: BoardImage
    let hud: Hud
    let screen: Screen?
    let pauseButton: PauseButtonRole?

    /// The scene of `session`, whose board `board` was drawn from.
    init(session: Session, board: BoardImage) {
        self.init(
            game: session.game, board: board, hud: Hud(game: session.game, highScore: session.highScore),
            screen: Screen(session: session), pauseButton: PauseButtonRole(session.state)
        )
    }

    init(game: Game, board: BoardImage, hud: Hud, screen: Screen?, pauseButton: PauseButtonRole?) {
        self.game = game
        self.board = board
        self.hud = hud
        self.screen = screen
        self.pauseButton = pauseButton
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
