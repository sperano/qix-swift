import XCTest
@testable import Qix

final class PlaceholderViewSnapshotTests: SnapshotTestCase {
    func testTheEmptyPlayfieldInLandscape() throws {
        try assertScreen(PlaceholderView())
    }
}
