import Foundation

/// What a launch's arguments choose: where the settings and the high scores are kept.
enum LaunchOptions {
    /// The argument UI tests launch the app with.
    static let uiTestingFlag = "--ui-testing"
    /// The suite of `UserDefaults` a UI-testing launch keeps its values in.
    static let uiTestingSuite = "quebec.spe.Qix.ui-testing"

    /// The standard `UserDefaults`; under `uiTestingFlag`, the `uiTestingSuite`, emptied, so each
    /// UI test starts from the default settings and an empty high score table.
    static func defaults(arguments: [String]) -> UserDefaults {
        guard arguments.contains(uiTestingFlag), let suite = UserDefaults(suiteName: uiTestingSuite) else {
            return .standard
        }
        suite.removePersistentDomain(forName: uiTestingSuite)
        return suite
    }
}
