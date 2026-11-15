import CoreGraphics
import QixKit
import XCTest
@testable import Qix

final class BoardImageTests: XCTestCase {
    func testTheClaimedCellsAreAnImageOfOnePixelPerCell() throws {
        var board = Board(width: Tuning.boardW, height: Tuning.boardH)
        board.setCell(x: 3, y: 2, to: .claimed(.slow))

        let image = try XCTUnwrap(BoardImage(board).claimed)

        XCTAssertEqual(image.width, Int(Tuning.boardW))
        XCTAssertEqual(image.height, Int(Tuning.boardH))
        XCTAssertEqual(image.bitsPerComponent, UInt8.bitWidth)
        XCTAssertEqual(image.bitsPerPixel, BoardShapes.bytesPerPixel * UInt8.bitWidth)
        XCTAssertEqual(image.bytesPerRow, Int(Tuning.boardW) * BoardShapes.bytesPerPixel)
        XCTAssertEqual(image.colorSpace?.name, CGColorSpace.sRGB)
        XCTAssertEqual(image.alphaInfo, .premultipliedLast)
        let data = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertEqual(data, Data(BoardShapes.claimedPixels(board)))
    }

    func testTheBorderIsTheBoardsBorderSegments() {
        var board = Board(width: Tuning.boardW, height: Tuning.boardH)
        board.setCell(x: 0, y: 0, to: .claimed(.fast))

        let image = BoardImage(board)

        XCTAssertEqual(image.board, board)
        XCTAssertEqual(image.border, BoardShapes.borderSegments(board))
    }
}
