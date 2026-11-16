import Foundation
import XCTest
@testable import Qix

/// A key the UI-testing suite holds before a launch empties it.
private let leftoverKey = "leftover"

final class LaunchOptionsTests: XCTestCase {
    func testANormalLaunchKeepsItsValuesInTheStandardDefaults() {
        XCTAssertTrue(LaunchOptions.defaults(arguments: ["Qix"]) === UserDefaults.standard)
    }

    func testAUITestingLaunchStartsFromAnEmptySuiteOfItsOwn() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: LaunchOptions.uiTestingSuite))
        suite.set(true, forKey: leftoverKey)

        let defaults = LaunchOptions.defaults(arguments: ["Qix", LaunchOptions.uiTestingFlag])

        XCTAssertFalse(defaults === UserDefaults.standard)
        XCTAssertNil(defaults.object(forKey: leftoverKey))
        defaults.removePersistentDomain(forName: LaunchOptions.uiTestingSuite)
    }
}
