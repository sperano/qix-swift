// The player's settings: the rules of a new game, the touch controls and the feedback, kept in
// `UserDefaults` next to the high scores. qix-rs's `crates/qix/src/settings.rs`, without its key
// bindings and window scale, which an iPhone has no use for, and with the iPhone's controls.

/// How the touch screen steers the marker.
public enum ControlScheme: String, Hashable, Sendable, Codable, CaseIterable {
    /// The floating stick on one side of the board and the Slow button on the other.
    case stick
    /// A finger on the board aims the marker (`TouchSteering`), with the Slow button beside it.
    case followTheFinger

    /// The name the settings show.
    public var title: String {
        switch self {
        case .stick: "Stick"
        case .followTheFinger: "Follow the finger"
        }
    }
}

/// The size of the floating stick, as a multiple of its standard size, always in `range`; coded
/// as its factor, clamped on the way in.
public struct StickSize: Hashable, Sendable {
    /// The sizes the settings may choose from; others are clamped into it.
    public static let range: ClosedRange<Float> = 0.75 ... 1.5
    /// The size of a first run.
    public static let standard: Float = 1

    /// The factor.
    public let get: Float

    /// `factor`, clamped into `range`; a NaN gives `standard`.
    public init(_ factor: Float) {
        get = clamped(factor, into: Self.range, nan: Self.standard)
    }

    /// `standard`.
    public init() {
        self.init(Self.standard)
    }
}

/// The opacity of a touch control while touched, from 0 to 1, always in `range`; coded as the
/// opacity, clamped on the way in. A control not touched is drawn fainter, in proportion.
public struct ControlsOpacity: Hashable, Sendable {
    /// The opacities the settings may choose from; others are clamped into it.
    public static let range: ClosedRange<Float> = 0.2 ... 1
    /// The opacity of a first run.
    public static let standard: Float = 0.7

    /// The opacity.
    public let get: Float

    /// `opacity`, clamped into `range`; a NaN gives `standard`.
    public init(_ opacity: Float) {
        get = clamped(opacity, into: Self.range, nan: Self.standard)
    }

    /// `standard`.
    public init() {
        self.init(Self.standard)
    }
}

/// `value` clamped into `range`, `nan` for a NaN.
private func clamped(_ value: Float, into range: ClosedRange<Float>, nan: Float) -> Float {
    value.isNaN ? nan : min(max(value, range.lowerBound), range.upperBound)
}

/// Everything the settings sheet edits. A field missing from the storage loads as its default; the
/// rules, the stick size and the opacity are clamped into their ranges; a field that does not
/// decode fails the whole value, which then loads as the default settings (`Persist`).
public struct Settings: Hashable, Sendable {
    /// The claimed fraction of the board that completes a level.
    public var threshold: ClaimThreshold
    /// The lives a game starts with.
    public var startingLives: StartingLives
    /// How the touch screen steers.
    public var controlScheme: ControlScheme
    /// The stick is right of the board and the Slow button left of it.
    public var leftHanded: Bool
    /// The size of the stick.
    public var stickSize: StickSize
    /// The opacity of the touch controls.
    public var controlsOpacity: ControlsOpacity
    /// The Taptic Engine plays on the game's events.
    public var haptics: Bool
    /// The game's sounds play.
    public var sounds: Bool

    /// The settings given; those of a first run by default: the arcade's rules, the stick
    /// right-handed at its standard size, haptics on and sounds off.
    public init(
        threshold: ClaimThreshold = ClaimThreshold(), startingLives: StartingLives = StartingLives(),
        controlScheme: ControlScheme = .stick, leftHanded: Bool = false, stickSize: StickSize = StickSize(),
        controlsOpacity: ControlsOpacity = ControlsOpacity(), haptics: Bool = true, sounds: Bool = false
    ) {
        self.threshold = threshold
        self.startingLives = startingLives
        self.controlScheme = controlScheme
        self.leftHanded = leftHanded
        self.stickSize = stickSize
        self.controlsOpacity = controlsOpacity
        self.haptics = haptics
        self.sounds = sounds
    }

    /// The rules a new game is set up with.
    public var rules: Rules {
        Rules(threshold: threshold, startingLives: startingLives)
    }
}

extension StickSize: Codable {
    /// The stored factor, clamped as `init(_:)` clamps it, one past `Float` but within `Double`
    /// included.
    public init(from decoder: any Decoder) throws {
        try self.init(decodedFloat(decoder))
    }

    /// Stores the factor.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(get)
    }
}

extension ControlsOpacity: Codable {
    /// The stored opacity, clamped as `init(_:)` clamps it, one past `Float` but within `Double`
    /// included.
    public init(from decoder: any Decoder) throws {
        try self.init(decodedFloat(decoder))
    }

    /// Stores the opacity.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(get)
    }
}

extension Settings: Codable {
    private enum CodingKeys: String, CodingKey {
        case threshold, startingLives, controlScheme, leftHanded, stickSize, controlsOpacity, haptics, sounds
    }

    /// The stored settings, each missing field (or `null`) at its default: Rust's
    /// `#[serde(default)]`. A field of the wrong type, or a control scheme this version does not
    /// have, fails to decode.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        func field<Value: Decodable>(_ key: CodingKeys, _ fallback: Value) throws -> Value {
            try container.decodeIfPresent(Value.self, forKey: key) ?? fallback
        }
        self.init(
            threshold: try field(.threshold, defaults.threshold),
            startingLives: try field(.startingLives, defaults.startingLives),
            controlScheme: try field(.controlScheme, defaults.controlScheme),
            leftHanded: try field(.leftHanded, defaults.leftHanded),
            stickSize: try field(.stickSize, defaults.stickSize),
            controlsOpacity: try field(.controlsOpacity, defaults.controlsOpacity),
            haptics: try field(.haptics, defaults.haptics),
            sounds: try field(.sounds, defaults.sounds)
        )
    }
}

/// The settings as the sheet's steppers show and set them: whole numbers, the fractions as percent
/// points, which the ranges and steps below are in.
public extension Settings {
    /// Converts a fraction to percent points.
    private static let pointsPerUnit: Float = 100

    /// The threshold's step: qix-rs's settings screen steps it by 5 points too.
    static let thresholdStep = 5
    static let thresholdPercents = percents(Tuning.claimThresholdRange)

    /// The stick size's step.
    static let stickSizeStep = 25
    static let stickSizePercents = percents(StickSize.range)

    /// The opacity's step.
    static let opacityStep = 10
    static let opacityPercents = percents(ControlsOpacity.range)

    /// The lives a game may start with.
    static let startingLivesCounts = Int(Tuning.startingLivesRange.lowerBound) ...
        Int(Tuning.startingLivesRange.upperBound)

    /// The threshold, in percent points of the board, set clamped.
    var thresholdPercent: Int {
        get { Self.percent(of: threshold.fraction) }
        set { threshold = ClaimThreshold(Self.fraction(of: newValue)) }
    }

    /// The stick size, in percent points of its standard size, set clamped.
    var stickSizePercent: Int {
        get { Self.percent(of: stickSize.get) }
        set { stickSize = StickSize(Self.fraction(of: newValue)) }
    }

    /// The opacity, in percent points, set clamped.
    var opacityPercent: Int {
        get { Self.percent(of: controlsOpacity.get) }
        set { controlsOpacity = ControlsOpacity(Self.fraction(of: newValue)) }
    }

    /// The lives a game starts with, set clamped.
    var startingLivesCount: Int {
        get { Int(startingLives.get) }
        set { startingLives = StartingLives(clamping: Int64(newValue)) }
    }

    /// `fraction` in whole percent points, rounded.
    private static func percent(of fraction: Float) -> Int {
        Int((fraction * pointsPerUnit).rounded())
    }

    /// The fraction of `percent` points.
    private static func fraction(of points: Int) -> Float {
        Float(points) / pointsPerUnit
    }

    /// `range` in whole percent points.
    private static func percents(_ range: ClosedRange<Float>) -> ClosedRange<Int> {
        percent(of: range.lowerBound) ... percent(of: range.upperBound)
    }
}
