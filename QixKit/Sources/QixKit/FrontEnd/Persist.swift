// What the app keeps between runs, in `UserDefaults`: qix-rs's `crates/qix/src/persist.rs`, with
// JSON in place of RON and `UserDefaults` in place of eframe's `Storage`.

import Foundation

/// The high score table and the settings, each stored as the JSON of its `Codable` value under its
/// key. A value that is missing, not data or not decodable loads as an empty table or the default
/// settings, and the next save overwrites it.
public enum Persist {
    /// The key of the high score table.
    public static let highScoresKey = "highScores"

    /// The key of the settings.
    public static let settingsKey = "settings"

    /// The high score table kept in `defaults`; an empty one when there is none or it does not
    /// decode.
    public static func loadHighScores(_ defaults: UserDefaults) -> HighScores {
        load(HighScores.self, highScoresKey, defaults) ?? HighScores()
    }

    /// Writes `highScores` to `defaults`, in place of the table kept there.
    public static func saveHighScores(_ highScores: HighScores, to defaults: UserDefaults) {
        save(highScores, highScoresKey, defaults)
    }

    /// The settings kept in `defaults`; the default ones when there are none or they do not decode
    /// (see `Settings` for the fields that load on their own).
    public static func loadSettings(_ defaults: UserDefaults) -> Settings {
        load(Settings.self, settingsKey, defaults) ?? Settings()
    }

    /// Writes `settings` to `defaults`, in place of the ones kept there.
    public static func saveSettings(_ settings: Settings, to defaults: UserDefaults) {
        save(settings, settingsKey, defaults)
    }

    /// The value of `type` decoded from the data under `key`, nil when there is none or it does
    /// not decode.
    private static func load<Value: Decodable>(_ type: Value.Type, _ key: String, _ defaults: UserDefaults) -> Value? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    /// Stores the JSON of `value` under `key`. The types stored here always encode.
    private static func save(_ value: some Encodable, _ key: String, _ defaults: UserDefaults) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(value) else {
            preconditionFailure("\(key) does not encode")
        }
        defaults.set(data, forKey: key)
    }
}
