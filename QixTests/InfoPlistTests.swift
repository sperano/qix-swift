import XCTest

/// The app's Info.plist as built: the device, orientation and screen choices `project.yml` makes.
final class InfoPlistTests: XCTestCase {
    /// `UIDeviceFamily`'s value for iPhone, which `TARGETED_DEVICE_FAMILY: 1` writes.
    private static let iPhoneFamily = 1

    private func value(_ key: String) -> Any? {
        Bundle.main.object(forInfoDictionaryKey: key)
    }

    func testTheAppIsForIPhoneOnly() {
        XCTAssertEqual(value("UIDeviceFamily") as? [Int], [Self.iPhoneFamily])
    }

    func testTheAppRunsInBothLandscapesOnly() {
        XCTAssertEqual(
            value("UISupportedInterfaceOrientations") as? [String],
            ["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]
        )
    }

    func testTheAppRequiresTheFullScreen() {
        XCTAssertEqual(value("UIRequiresFullScreen") as? Bool, true)
    }

    func testTheStatusBarIsHidden() {
        XCTAssertEqual(value("UIStatusBarHidden") as? Bool, true)
    }

    func testTheLaunchScreenIsTheBackdrop() {
        let launchScreen = value("UILaunchScreen") as? [String: Any]
        XCTAssertEqual(launchScreen?["UIColorName"] as? String, "Backdrop")
    }
}
