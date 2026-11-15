import XCTest
@testable import QixKit

/// Dimensions of the board the tests cut.
private let width: UInt16 = 6
private let height: UInt16 = 5

/// The column of the vertical cuts: cells left of it are `x < cutX`.
private let cutX: UInt16 = 3

/// The row of the horizontal cut: cells below it are `y >= cutY`.
private let cutY: UInt16 = 2

/// A cell of the board, as `(x, y)` in the claim functions.
private struct Spot: Equatable {
    let x: UInt16
    let y: UInt16

    init(_ cell: (UInt16, UInt16)) {
        (x, y) = cell
    }
}

/// A stix from `start` along `path`, every step drawn with `kind`.
private func drawnWith(_ start: Point, _ path: [Dir], _ kind: DrawKind) -> Stix {
    var stix = Stix(start: start)
    for dir in path {
        stix.push(dir.step(stix.head)!, kind)
    }
    return stix
}

/// Claims every free cell outside the area of `seed`, as `stix` draws.
@discardableResult
private func claimFrom(_ board: inout Board, _ stix: Stix, _ seed: (UInt16, UInt16)) -> Int {
    let kept = Claim.regions(board, stix, [seed])
    return Claim.claim(&board, kept, stix.claimKind())
}

/// `steps` steps towards `dir` (`run` in qix-rs, which XCTestCase.run would hide).
private func straightRun(_ dir: Dir, _ steps: UInt16) -> [Dir] {
    Array(repeating: dir, count: Int(steps))
}

/// A fast stix from the bottom edge at `cutX` straight up to the top.
private func straightCut() -> Stix {
    drawnWith(Point(x: cutX, y: height), straightRun(.up, height), .fast)
}

private func cellAt(_ board: Board, _ spot: Spot) -> Cell {
    board.cell(x: Int32(spot.x), y: Int32(spot.y))
}

/// Every cell of `board` in reading order.
private func cells(_ board: Board) -> [Spot] {
    (0 ..< board.height).flatMap { y in (0 ..< board.width).map { x in Spot((x, y)) } }
}

/// The free cells of `board` in reading order.
private func freeCells(_ board: Board) -> [Spot] {
    cells(board).filter { cellAt(board, $0) == .free }
}

/// The cells `set` holds, as `Claim.floodFree` lays them out on `board`.
private func reached(_ board: Board, _ set: BitSet) -> [Spot] {
    let width = Int(board.width)
    return cells(board).filter { set.contains(Int($0.y) * width + Int($0.x)) }
}

/// The cells with `x < cutX` or not, depending on `left`.
private func sideOfCut(_ board: Board, _ left: Bool) -> [Spot] {
    cells(board).filter { ($0.x < cutX) == left }
}

/// The L-shaped cut: up from the bottom edge at x = 2 to y = 2, then right to the right edge. It
/// closes off the bottom right cells `x >= 2, y >= 2`.
private func lCut() -> Stix {
    drawnWith(Point(x: 2, y: height), straightRun(.up, 3) + straightRun(.right, width - 2), .fast)
}

/// The columns of the U-shaped cut's two sides: it splits the board into the cells left of the
/// first, between the two, and right of the second.
private let uLeftX: UInt16 = 2
private let uRightX: UInt16 = 4

/// The U-shaped cut: up from the bottom edge at `uLeftX`, right along the top edge to `uRightX`,
/// then down to the bottom edge, which cuts the board into three areas.
private func uCut() -> Stix {
    let path = straightRun(.up, height) + straightRun(.right, uRightX - uLeftX) + straightRun(.down, height)
    return drawnWith(Point(x: uLeftX, y: height), path, .fast)
}

/// The cells the L-shaped cut closes off.
private func insideL(_ board: Board) -> [Spot] {
    cells(board).filter { $0.x >= 2 && $0.y >= 2 }
}

/// A fast stix from the top edge at `cutX` straight down to the bottom: `straightCut` drawn the
/// other way.
private func straightCutFromTop() -> Stix {
    drawnWith(Point(x: cutX, y: 0), straightRun(.down, height), .fast)
}

final class ClaimTests: XCTestCase {
    func testAStraightCutStopsTheFill() {
        let board = Board(width: width, height: height)

        let set = Claim.floodFree(board, straightCut(), (0, 2))

        XCTAssertEqual(reached(board, set), sideOfCut(board, true))
    }

    func testAStraightCutClaimsTheHalfWithoutTheSeed() {
        var board = Board(width: width, height: height)

        let count = claimFrom(&board, straightCut(), (0, 2))

        XCTAssertEqual(count, Int((width - cutX) * height))
        XCTAssertEqual(freeCells(board), sideOfCut(board, true))
        for spot in sideOfCut(board, false) {
            XCTAssertEqual(cellAt(board, spot), .claimed(.fast))
        }
    }

    func testTheSeedSideOfACutStaysFreeWhicheverSideItIs() {
        var board = Board(width: width, height: height)

        claimFrom(&board, straightCut(), (width - 1, 0))

        XCTAssertEqual(freeCells(board), sideOfCut(board, false))
    }

    func testASlowStixClaimsSlow() {
        var board = Board(width: width, height: height)
        let stix = drawnWith(Point(x: cutX, y: height), straightRun(.up, height), .slow)

        claimFrom(&board, stix, (0, 0))

        XCTAssertEqual(board.cell(x: Int32(width - 1), y: 0), .claimed(.slow))
    }

    func testAnLShapedCutClaimsItsCornerFromASeedOutside() {
        var board = Board(width: width, height: height)

        let count = claimFrom(&board, lCut(), (0, 0))

        let corner = insideL(board)
        XCTAssertEqual(count, corner.count)
        XCTAssertEqual(freeCells(board), cells(board).filter { !corner.contains($0) })
    }

    func testAnLShapedCutKeepsItsCornerFromASeedInside() {
        var board = Board(width: width, height: height)

        claimFrom(&board, lCut(), (width - 1, height - 1))

        XCTAssertEqual(freeCells(board), insideL(board))
    }

    func testAStixTouchingTheBorderWithoutEnclosingClaimsNothing() {
        var board = Board(width: width, height: height)
        let stix = drawnWith(Point(x: cutX, y: height), straightRun(.up, height - 1), .fast)

        let count = claimFrom(&board, stix, (0, height - 1))

        XCTAssertEqual(count, 0)
        XCTAssertEqual(board, Board(width: width, height: height))
    }

    func testACutEndingOnAClaimedAreaClaimsOnlyFreeCells() {
        var board = Board(width: width, height: height)
        let claimedX = width - 1
        for y in 0 ..< height {
            board.setCell(x: claimedX, y: y, to: .claimed(.fast))
        }
        let stix = drawnWith(Point(x: 0, y: cutY), straightRun(.right, claimedX), .slow)

        let count = claimFrom(&board, stix, (0, 0))

        let below = cells(board).filter { $0.x < claimedX && $0.y >= cutY }
        XCTAssertEqual(count, below.count)
        for spot in below {
            XCTAssertEqual(cellAt(board, spot), .claimed(.slow))
        }
        for y in 0 ..< height {
            XCTAssertEqual(board.cell(x: Int32(claimedX), y: Int32(y)), .claimed(.fast))
        }
        let above = cells(board).filter { $0.x < claimedX && $0.y < cutY }
        XCTAssertEqual(freeCells(board), above)
    }

    func testAClaimedSeedReachesNothing() {
        var board = Board(width: width, height: height)
        board.setCell(x: 0, y: 0, to: .claimed(.fast))

        let set = Claim.floodFree(board, straightCut(), (0, 0))

        XCTAssertEqual(set.count(), 0)
    }

    func testASeedOffTheBoardReachesNothing() {
        let board = Board(width: width, height: height)

        let set = Claim.floodFree(board, straightCut(), (width, 0))

        XCTAssertEqual(set.count(), 0)
    }

    func testTheFillDoesNotEnterClaimedCells() {
        var board = Board(width: width, height: height)
        board.setCell(x: 1, y: 1, to: .claimed(.fast))

        let set = Claim.floodFree(board, Stix(start: Point(x: 0, y: height)), (0, 0))

        XCTAssertEqual(set.count(), Int(width * height) - 1)
        XCTAssertFalse(reached(board, set).contains(Spot((1, 1))))
    }

    func testAFullSizeBoardFloodsWithoutRecursion() {
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)

        let set = Claim.floodFree(board, Stix(start: Point(x: 0, y: Tuning.boardH)), (0, 0))

        XCTAssertEqual(set.count(), Int(Tuning.boardW) * Int(Tuning.boardH))
    }

    func testClosingACutReportsItsCellsTheClaimedFractionAndKind() {
        var board = Board(width: width, height: height)
        let stix = drawnWith(Point(x: cutX, y: height), straightRun(.up, height), .slow)

        let result = board.closeStix(stix, [qixAt((0, 0))]).claim

        let cells = Int((width - cutX) * height)
        let expected = ClaimResult(cells: cells, fraction: board.claimedFraction(), kind: .slow)
        XCTAssertEqual(result, expected)
        XCTAssertEqual(expected.fraction, Float(cells) / Float(width * height))
    }

    func testClosingAStixThatEnclosesNothingReportsNone() {
        var board = Board(width: width, height: height)
        let stix = drawnWith(Point(x: cutX, y: height), straightRun(.up, height - 1), .fast)

        let result = board.closeStix(stix, [qixAt((0, height - 1))])

        XCTAssertNil(result.claim)
        XCTAssertEqual(board, Board(width: width, height: height))
    }

    func testTheSideHoldingTheQixStaysFreeWhicheverEndTheStixStarts() {
        for cut in [straightCut(), straightCutFromTop()] {
            for (qix, left) in [((UInt16(0), UInt16(2)), true), ((width - 1, 2), false)] {
                var board = Board(width: width, height: height)

                board.closeStix(cut, [qixAt(qix)])

                XCTAssertEqual(freeCells(board), sideOfCut(board, left), "\(qix)")
            }
        }
    }

    func testSeedsInOneAreaGetEqualRegions() {
        let board = Board(width: width, height: height)

        let sets = Claim.regions(board, straightCut(), [(0, 0), (cutX - 1, height - 1)])

        XCTAssertEqual(sets[0], sets[1])
        XCTAssertEqual(reached(board, sets[0]), sideOfCut(board, true))
    }

    func testSeedsEitherSideOfACutGetTheirOwnSide() {
        let board = Board(width: width, height: height)

        let sets = Claim.regions(board, straightCut(), [(width - 1, 0), (0, 0)])

        XCTAssertEqual(reached(board, sets[0]), sideOfCut(board, false))
        XCTAssertEqual(reached(board, sets[1]), sideOfCut(board, true))
    }

    func testAClaimedSeedAfterAFreeOneGetsAnEmptyRegion() {
        var board = Board(width: width, height: height)
        board.setCell(x: width - 1, y: 0, to: .claimed(.fast))

        let sets = Claim.regions(board, straightCut(), [(0, 0), (width - 1, 0)])

        XCTAssertEqual(sets[1].count(), 0)
    }

    func testTwoQixOnOneSideKeepOnlyThatSide() {
        var board = Board(width: width, height: height)
        let qix = [qixAt((0, 0)), qixAt((1, height - 1))]

        let result = board.closeStix(straightCut(), qix)

        XCTAssertEqual(freeCells(board), sideOfCut(board, true))
        XCTAssertEqual(result.regions[0], result.regions[1])
        XCTAssertEqual(result.claim?.cells, Int((width - cutX) * height))
    }

    func testAQixEitherSideOfACutKeepsBothSidesInSeparateRegions() {
        var board = Board(width: width, height: height)
        let qix = [qixAt((0, 0)), qixAt((width - 1, 0))]

        let result = board.closeStix(straightCut(), qix)

        XCTAssertNil(result.claim)
        XCTAssertEqual(board, Board(width: width, height: height))
        XCTAssertEqual(reached(board, result.regions[0]), sideOfCut(board, true))
        XCTAssertEqual(reached(board, result.regions[1]), sideOfCut(board, false))
    }

    func testClosingWithoutAQixClaimsEveryFreeCell() {
        var board = Board(width: width, height: height)

        let result = board.closeStix(straightCut(), [])

        XCTAssertEqual(result.regions, [])
        XCTAssertEqual(freeCells(board), [])
        XCTAssertEqual(result.claim?.fraction, 1.0)
    }

    func testEveryKeptRegionStaysFree() {
        var board = Board(width: width, height: height)
        let stix = uCut()
        let kept = Claim.regions(board, stix, [(0, 0), (width - 1, 0)])

        let count = Claim.claim(&board, kept, .fast)

        let between = cells(board).filter { $0.x >= uLeftX && $0.x < uRightX }
        XCTAssertEqual(count, between.count)
        XCTAssertEqual(freeCells(board), cells(board).filter { !between.contains($0) })
    }

    func testWithNothingKeptEveryFreeCellIsClaimed() {
        var board = Board(width: width, height: height)
        board.setCell(x: 0, y: 0, to: .claimed(.fast))

        let count = Claim.claim(&board, [], .slow)

        XCTAssertEqual(count, Int(width * height) - 1)
        XCTAssertEqual(board.cell(x: 0, y: 0), .claimed(.fast))
        XCTAssertEqual(cells(board).dropFirst().filter { cellAt(board, $0) != .claimed(.slow) }, [])
    }

    func testADownwardCutStopsTheFillLikeAnUpwardOne() {
        var board = Board(width: width, height: height)
        let stix = drawnWith(Point(x: cutX, y: 0), straightRun(.down, height), .fast)

        claimFrom(&board, stix, (0, 2))

        XCTAssertEqual(freeCells(board), sideOfCut(board, true))
    }

    func testALeftwardCutClaimsTheRowsBelowIt() {
        var board = Board(width: width, height: height)
        let stix = drawnWith(Point(x: width, y: cutY), straightRun(.left, width), .fast)

        let count = claimFrom(&board, stix, (0, 0))

        let below = cells(board).filter { $0.y >= cutY }
        XCTAssertEqual(count, below.count)
        XCTAssertEqual(freeCells(board), cells(board).filter { $0.y < cutY })
    }

    /// The walls of a stix off the board's lattice, which qix-rs skips rather than indexes.
    func testAStixOffTheLatticeWallsNothing() {
        let board = Board(width: width, height: height)
        let far = Point(x: width + 2, y: height + 2)
        let stix = drawnWith(far, [.right, .down], .fast)

        let set = Claim.floodFree(board, stix, (0, 0))

        XCTAssertEqual(set.count(), Int(width * height))
    }
}
