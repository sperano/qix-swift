import QixKit
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Qix

/// The How to play page as the settings sheet pushes it, on the screen of the host window (the
/// iPhone 17) and of the smallest landscape iPhone.
final class HowToPlaySnapshotTests: SnapshotTestCase {
    /// The reference name of the small phone's images.
    private static let smallName = "small"

    private func page(_ settings: QixKit.Settings) -> some View {
        NavigationStack { HowToPlayView(sheet: HowToPlay(settings: settings)) }
    }

    func testThePageAtTheDefaults() throws {
        let view = page(QixKit.Settings())

        try assertScreen(view)
        try assertScreen(view, on: Self.smallPhone, named: Self.smallName)
    }

    /// Following the finger, left-handed: the touch controls' section without the stick.
    func testThePageFollowingTheFingerLeftHanded() throws {
        var settings = QixKit.Settings()
        settings.controlScheme = .followTheFinger
        settings.leftHanded = true

        try assertScreen(page(settings))
    }
}
