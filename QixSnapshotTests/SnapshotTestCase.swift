import SnapshotTesting
import SwiftUI
import XCTest
@testable import Qix

/// Renders a view as the snapshot simulator shows it and compares the image with the one recorded
/// in `__Snapshots__` next to the test file. Re-record after a deliberate change to a view
/// (`make record-snapshots`). The references are recorded on `deviceName`; on any other device the
/// tests skip, since the screen size would not match. The iOS version is not checked.
@MainActor
class SnapshotTestCase: XCTestCase {
    /// The simulator the references are recorded on, and the one CI runs these tests on.
    static let deviceName = "iPhone 17"
    /// The share of pixels that must match byte for byte: antialiasing can shift a few pixels
    /// between machines. The images are compared pixel by pixel, never perceptually: the perceptual
    /// comparison goes through CoreImage, which fails on GitHub's runners even for identical images.
    static let pixelPrecision: Float = 0.995

    override func setUp() async throws {
        try await super.setUp()
        let device = UIDevice.current.name
        try XCTSkipUnless(device == Self.deviceName, "snapshots are recorded on \(Self.deviceName), not on \(device)")
    }

    /// The smallest landscape iPhone the app runs on: the iPhone SE's 667 × 375 points, with no
    /// safe area insets. It fits inside the host window, which draws it.
    static let smallPhone = ViewImageConfig.iPhone8(.landscape)

    /// Asserts a whole screen, laid out in the host app's window with its safe area. The app runs in
    /// landscape only, so the window is a landscape one; a portrait window fails the test.
    func assertScreen(
        _ view: some View, fileID: StaticString = #fileID, file: StaticString = #filePath,
        testName: String = #function, line: UInt = #line
    ) throws {
        let window = try XCTUnwrap(Self.hostWindow, "the test host has no window")
        let size = window.bounds.size
        XCTAssertGreaterThan(size.width, size.height, "the host window is not in landscape", file: file, line: line)
        let config = ViewImageConfig(safeArea: window.safeAreaInsets, size: size, traits: Self.traits(of: window))
        assertSnapshot(
            of: view, as: Self.strategy(config), fileID: fileID, file: file, testName: testName, line: line
        )
    }

    /// Asserts a whole screen of `phone`'s size and safe area, at the host window's scale, as the
    /// reference named `name`.
    func assertScreen(
        _ view: some View, on phone: ViewImageConfig, named name: String, fileID: StaticString = #fileID,
        file: StaticString = #filePath, testName: String = #function, line: UInt = #line
    ) throws {
        let window = try XCTUnwrap(Self.hostWindow, "the test host has no window")
        let config = ViewImageConfig(safeArea: phone.safeArea, size: phone.size, traits: Self.traits(of: window))
        assertSnapshot(
            of: view, as: Self.strategy(config), named: name, fileID: fileID, file: file, testName: testName,
            line: line
        )
    }

    /// The image of a view laid out on the device of `config`, drawn in the key window.
    private static func strategy<V: View>(_ config: ViewImageConfig) -> Snapshotting<V, UIImage> {
        .image(drawHierarchyInKeyWindow: true, precision: pixelPrecision, layout: .device(config: config))
    }

    /// The traits the images are drawn with: the host window's display scale.
    private static func traits(of window: UIWindow) -> UITraitCollection {
        UITraitCollection { $0.displayScale = window.traitCollection.displayScale }
    }

    private static var hostWindow: UIWindow? {
        UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first?.keyWindow
    }
}
