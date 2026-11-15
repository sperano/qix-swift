// The initials that name a high score, and their entry with the direction controls after a
// qualifying game.

/// The first letter initials may hold, and the one an entry starts at.
private let firstLetter = UInt8(ascii: "A")

/// The last letter initials may hold.
private let lastLetter = UInt8(ascii: "Z")

/// Letters initials may hold, from `firstLetter` to `lastLetter`.
private let letterCount = lastLetter - firstLetter + 1

/// `Tuning.initialsLen` capital letters from A to Z, stored as a string.
public struct Initials: Hashable, Sendable {
    /// The letters, as their ASCII codes: always `Tuning.initialsLen` of them, each from
    /// `firstLetter` to `lastLetter`.
    private var codes: [UInt8]

    /// Initials made of `firstLetter` only, where an entry starts.
    public static let first = Self(codes: Array(repeating: firstLetter, count: Tuning.initialsLen))

    private init(codes: [UInt8]) {
        self.codes = codes
    }

    /// The initials `text` spells, or `InvalidInitials` when it is not `Tuning.initialsLen`
    /// letters from A to Z: Rust's `TryFrom<String>`.
    public init(_ text: String) throws(InvalidInitials) {
        let codes = Array(text.utf8)
        guard codes.count == Tuning.initialsLen, codes.allSatisfy((firstLetter ... lastLetter).contains) else {
            throw InvalidInitials(text: text)
        }
        self.init(codes: codes)
    }

    /// The letters, first to last.
    public var letters: [Character] {
        codes.map { Character(Unicode.Scalar($0)) }
    }

    /// These initials with the letter at `index` stepped `forward` (or back) by one, wrapping from
    /// Z to A and from A to Z.
    fileprivate func stepLetter(_ index: Int, forward: Bool) -> Self {
        let offset = forward ? 1 : letterCount - 1
        var initials = self
        initials.codes[index] = firstLetter + (codes[index] - firstLetter + offset) % letterCount
        return initials
    }
}

extension Initials: CustomStringConvertible {
    /// The letters as a string: Rust's `Display`, and the string the initials are stored as.
    public var description: String {
        String(letters)
    }
}

extension Initials: Codable {
    /// The initials of a stored string; a string that is not valid initials fails to decode.
    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        do {
            try self.init(text)
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: error.description)
            )
        }
    }

    /// Stores the initials as their string.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// A string that is not `Tuning.initialsLen` letters from A to Z.
public struct InvalidInitials: Error, Hashable, CustomStringConvertible {
    /// The string refused.
    public let text: String

    /// The refusal of `text`.
    public init(text: String) {
        self.text = text
    }

    public var description: String {
        "\(text.debugDescription) is not \(Tuning.initialsLen) letters from A to Z"
    }
}

/// Initials being entered, one letter at a time: up and down change the letter under the cursor,
/// left and right move the cursor, and confirm moves it on, or ends the entry on the last letter.
///
/// A held direction repeats as `DirRepeat` reads it.
public struct InitialsEntry: Hashable, Sendable {
    /// The initials entered so far.
    public private(set) var initials: Initials
    /// The index of the letter the controls change.
    public private(set) var cursor: Int
    private var dirRepeat: DirRepeat

    /// An entry at `Initials.first`, the cursor on the first letter.
    public init() {
        initials = .first
        cursor = 0
        dirRepeat = DirRepeat()
    }

    /// Applies one tick of `input`: the held direction, then confirm. Returns the initials once
    /// confirm is pressed on the last letter.
    public mutating func tick(_ input: InputState) -> Initials? {
        if let dir = dirRepeat.tick(input.dir) {
            apply(dir)
        }
        if !input.confirm {
            return nil
        } else if cursor + 1 == Tuning.initialsLen {
            return initials
        } else {
            cursor += 1
            return nil
        }
    }

    /// Changes the letter or moves the cursor as `dir` asks.
    private mutating func apply(_ dir: Dir) {
        switch dir {
        case .up:
            initials = initials.stepLetter(cursor, forward: true)
        case .down:
            initials = initials.stepLetter(cursor, forward: false)
        case .left:
            cursor = max(cursor - 1, 0)
        case .right:
            cursor = min(cursor + 1, Tuning.initialsLen - 1)
        }
    }
}
