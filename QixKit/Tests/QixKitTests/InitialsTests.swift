import Foundation
import XCTest
@testable import QixKit

/// Letters from A to Z: stepping a letter this many times comes back to it.
private let letterCount = 26

/// Repeats `countSteps` watches a held direction for.
private let repeats: UInt32 = 3

private func held(_ dir: Dir) -> InputState {
    InputState(dir: dir)
}

private let confirm = InputState(confirm: true)

/// Ticks `entry` with `dir` held for one tick, then released.
private func tap(_ entry: inout InitialsEntry, _ dir: Dir, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertNil(entry.tick(held(dir)), file: file, line: line)
    XCTAssertNil(entry.tick(InputState()), file: file, line: line)
}

private func initials(_ text: String) throws -> Initials {
    try Initials(text)
}

/// The ticks, counted from the first, on which holding up steps the letter, over the first
/// `repeats` repeats.
private func countSteps() -> [UInt32] {
    var entry = InitialsEntry()
    let ticks = Tuning.repeatDelayTicks + repeats * Tuning.repeatTicks
    var steps: [UInt32] = []
    for tick in 0 ... ticks {
        let before = entry.initials
        _ = entry.tick(held(.up))
        if entry.initials != before {
            steps.append(tick)
        }
    }
    return steps
}

final class InitialsTests: XCTestCase {
    func testInitialsHoldThreeCapitalLetters() throws {
        XCTAssertEqual(try initials("QIX").letters, ["Q", "I", "X"])
        XCTAssertEqual(try initials("QIX").description, "QIX")
        XCTAssertEqual(try String(describing: initials("ABZ")), "ABZ")
    }

    func testInitialsRejectAnythingButThreeCapitalLetters() {
        for text in ["", "AB", "ABCD", "abc", "A1C", "A C", "ÀBC", "AÉ"] {
            XCTAssertThrowsError(try Initials(text), text) { error in
                XCTAssertEqual(error as? InvalidInitials, InvalidInitials(text: text), text)
            }
        }
    }

    func testTheRefusalNamesTheStringAndTheRule() {
        XCTAssertEqual(InvalidInitials(text: "abc").description, "\"abc\" is not 3 letters from A to Z")
    }

    func testAnEntryStartsOnTheFirstLetterOfAaa() throws {
        // Rust also checks `InitialsEntry::default()`, which is `InitialsEntry()` in Swift.
        let entry = InitialsEntry()

        XCTAssertEqual(entry.initials, try initials("AAA"))
        XCTAssertEqual(entry.cursor, 0)
        XCTAssertEqual(Initials.first, try initials("AAA"))
    }

    func testUpAndDownStepTheLetterUnderTheCursor() throws {
        var entry = InitialsEntry()
        tap(&entry, .up)
        tap(&entry, .up)
        XCTAssertEqual(entry.initials, try initials("CAA"))

        tap(&entry, .down)
        XCTAssertEqual(entry.initials, try initials("BAA"))
    }

    func testLettersWrapAroundTheAlphabet() throws {
        var entry = InitialsEntry()
        tap(&entry, .down)
        XCTAssertEqual(entry.initials, try initials("ZAA"))

        tap(&entry, .up)
        XCTAssertEqual(entry.initials, try initials("AAA"))
        for _ in 0 ..< letterCount {
            tap(&entry, .up)
        }
        XCTAssertEqual(entry.initials, try initials("AAA"))
    }

    func testLeftAndRightMoveTheCursorWithinTheInitials() throws {
        var entry = InitialsEntry()
        tap(&entry, .left)
        XCTAssertEqual(entry.cursor, 0)

        for _ in 0 ..< Tuning.initialsLen + 1 {
            tap(&entry, .right)
        }
        XCTAssertEqual(entry.cursor, Tuning.initialsLen - 1)
        tap(&entry, .up)
        XCTAssertEqual(entry.initials, try initials("AAB"))

        tap(&entry, .left)
        XCTAssertEqual(entry.cursor, Tuning.initialsLen - 2)
    }

    func testConfirmMovesOnAndEndsOnTheLastLetter() throws {
        var entry = InitialsEntry()
        tap(&entry, .up)
        XCTAssertNil(entry.tick(confirm))
        XCTAssertEqual(entry.cursor, 1)
        tap(&entry, .down)
        XCTAssertNil(entry.tick(confirm))
        tap(&entry, .up)
        tap(&entry, .up)

        XCTAssertEqual(entry.tick(confirm), try initials("BZC"))
    }

    func testADirectionWithConfirmActsBeforeIt() throws {
        var entry = InitialsEntry()
        for _ in 1 ..< Tuning.initialsLen {
            _ = entry.tick(confirm)
        }
        let input = InputState(dir: .up, confirm: true)

        XCTAssertEqual(entry.tick(input), try initials("AAB"))
    }

    func testAHeldDirectionRepeatsAfterADelay() {
        let repeated = (0 ... repeats).map { Tuning.repeatDelayTicks + $0 * Tuning.repeatTicks }

        XCTAssertEqual(countSteps(), [0] + repeated)
    }

    func testChangingTheHeldDirectionActsAtOnce() throws {
        var entry = InitialsEntry()
        _ = entry.tick(held(.up))
        _ = entry.tick(held(.right))
        _ = entry.tick(held(.up))

        XCTAssertEqual(entry.cursor, 1)
        XCTAssertEqual(entry.initials, try initials("BBA"))
    }

    // Rust's serde derives, tested in qix-rs through the settings and high score storage: the
    // initials code as their string, and a string that is not valid initials fails to decode.

    func testInitialsEncodeAsTheirString() throws {
        let data = try JSONEncoder().encode([initials("QIX")])

        XCTAssertEqual(String(bytes: data, encoding: .utf8), #"["QIX"]"#)
    }

    func testInitialsDecodeFromTheirString() throws {
        let decoded = try JSONDecoder().decode([Initials].self, from: Data(#"["ABZ"]"#.utf8))

        XCTAssertEqual(decoded, [try initials("ABZ")])
    }

    func testAStringThatIsNotInitialsFailsToDecode() {
        for text in ["abc", "ABCD", "A1C"] {
            let json = Data("[\"\(text)\"]".utf8)
            XCTAssertThrowsError(try JSONDecoder().decode([Initials].self, from: json), text) { error in
                guard case let DecodingError.dataCorrupted(context) = error else {
                    return XCTFail("\(text): \(error)")
                }
                XCTAssertEqual(context.debugDescription, InvalidInitials(text: text).description)
            }
        }
    }

    func testANumberFailsToDecodeAsInitials() {
        XCTAssertThrowsError(try JSONDecoder().decode([Initials].self, from: Data("[7]".utf8))) { error in
            guard case DecodingError.typeMismatch = error else {
                return XCTFail("\(error)")
            }
        }
    }
}
