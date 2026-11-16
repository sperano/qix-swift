import QixKit
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Qix

/// The settings sheet, as it fills the screen of the host window (the iPhone 17) and of the
/// smallest landscape iPhone.
final class SettingsSnapshotTests: SnapshotTestCase {
    /// The reference name of the small phone's images.
    private static let smallName = "small"

    func testTheSettingsSheetAtTheDefaults() throws {
        let view = SettingsView(settings: .constant(QixKit.Settings()))

        try assertScreen(view)
        try assertScreen(view, on: Self.smallPhone, named: Self.smallName)
    }

    /// Every setting off its default: the steppers at their ends, the toggles flipped.
    func testTheSettingsSheetEdited() throws {
        let settings = QixKit.Settings(
            threshold: ClaimThreshold(Tuning.claimThresholdRange.upperBound),
            startingLives: StartingLives(Tuning.startingLivesRange.lowerBound), leftHanded: true,
            stickSize: StickSize(StickSize.range.upperBound),
            controlsOpacity: ControlsOpacity(ControlsOpacity.range.lowerBound), haptics: false, sounds: true
        )

        try assertScreen(SettingsView(settings: .constant(settings)))
    }
}
