import Foundation
import XCTest
@testable import QixKit

/// Points between two entries of `tableOf`.
private let scoreStep: UInt32 = 1_000

/// The score of the `n`th entry of `tableOf`, best first.
private func fullScore(_ n: Int) -> UInt32 {
    UInt32(Tuning.highScoreCount - n) * scoreStep
}

private func entry(_ name: String, _ score: UInt32) throws -> HighScore {
    try HighScore(name: Initials(name), score: score)
}

/// A table of the first `count` entries of `fullTable`.
private func tableOf(_ count: Int) throws -> HighScores {
    var table = HighScores()
    for n in 0 ..< count {
        try table.insert(entry("AAA", fullScore(n)))
    }
    XCTAssertEqual(table.entries.count, count)
    return table
}

/// A table of `Tuning.highScoreCount` entries, `scoreStep` apart, the last scoring `scoreStep`.
private func fullTable() throws -> HighScores {
    try tableOf(Tuning.highScoreCount)
}

private func names(_ table: HighScores) -> [String] {
    table.entries.map(\.name.description)
}

private func scores(_ table: HighScores) -> [UInt32] {
    table.entries.map(\.score)
}

final class HighScoreTests: XCTestCase {
    func testAnEmptyTableHasABestOfZero() {
        let table = HighScores()

        XCTAssertTrue(table.entries.isEmpty)
        XCTAssertEqual(table.best, 0)
    }

    func testEntriesGoInBestFirst() throws {
        var table = HighScores()

        XCTAssertEqual(try table.insert(entry("BOB", 500)), 0)
        XCTAssertEqual(try table.insert(entry("AMY", 900)), 0)
        XCTAssertEqual(try table.insert(entry("CAT", 700)), 1)
        XCTAssertEqual(try table.insert(entry("DAN", 100)), 3)

        XCTAssertEqual(names(table), ["AMY", "CAT", "BOB", "DAN"])
        XCTAssertEqual(scores(table), [900, 700, 500, 100])
        XCTAssertEqual(table.best, 900)
    }

    func testAnEqualScoreRanksBelowTheEarlierOne() throws {
        var table = HighScores()
        try table.insert(entry("OLD", 500))

        XCTAssertEqual(try table.insert(entry("NEW", 500)), 1)
        XCTAssertEqual(table.entries[0].name.description, "OLD")
    }

    func testAScoreOfZeroNeverQualifies() throws {
        var table = HighScores()

        XCTAssertFalse(table.qualifies(0))
        XCTAssertNil(try table.insert(entry("AAA", 0)))
        XCTAssertTrue(table.entries.isEmpty)
    }

    func testAnyScoreQualifiesWhileTheTableIsNotFull() throws {
        let table = try tableOf(Tuning.highScoreCount - 1)

        XCTAssertEqual(table.rank(1), Tuning.highScoreCount - 1)
    }

    func testAFullTableKeepsOnlyTheBest() throws {
        var table = try fullTable()
        let last = fullScore(Tuning.highScoreCount - 1)

        XCTAssertEqual(try table.insert(entry("NEW", last + 1)), Tuning.highScoreCount - 1)

        XCTAssertEqual(table.entries.count, Tuning.highScoreCount)
        XCTAssertEqual(table.entries[Tuning.highScoreCount - 1], try entry("NEW", last + 1))
        XCTAssertFalse(scores(table).contains(last))
    }

    func testAFullTableTurnsAwayAScoreNoBetterThanItsLast() throws {
        var table = try fullTable()
        let before = table
        let last = fullScore(Tuning.highScoreCount - 1)

        XCTAssertFalse(table.qualifies(last))
        XCTAssertNil(try table.insert(entry("NEW", last)))
        XCTAssertNil(try table.insert(entry("NEW", last - 1)))
        XCTAssertEqual(table, before)
    }

    func testANewBestPushesEveryEntryDown() throws {
        var table = try fullTable()
        let best = fullScore(0) + 1

        XCTAssertEqual(try table.insert(entry("TOP", best)), 0)

        XCTAssertEqual(scores(table), [best] + (0 ..< Tuning.highScoreCount - 1).map(fullScore))
    }

    func testATableFromAListIsSortedBestFirstKeepingTiesInOrder() throws {
        let table = try HighScores([entry("ONE", 300), entry("TWO", 300), entry("BIG", 900)])

        XCTAssertEqual(names(table), ["BIG", "ONE", "TWO"])
    }

    func testATableFromALongListKeepsOnlyTheBest() throws {
        var list = try [entry("LOW", 1)]
        list += try (0 ..< Tuning.highScoreCount).reversed().map { try entry("AAA", fullScore($0)) }

        let table = HighScores(list)

        XCTAssertEqual(table, try fullTable())
    }

    func testATableFromAListDropsScoresOfZero() throws {
        let table = try HighScores([entry("ZER", 0), entry("ONE", 1)])

        XCTAssertEqual(names(table), ["ONE"])
    }

    func testATableTurnsBackIntoItsList() throws {
        // Rust's `From<HighScores> for Vec<HighScore>` is `entries` in Swift.
        let table = try HighScores([entry("BIG", 900), entry("SML", 100)])

        XCTAssertEqual(table.entries, try [entry("BIG", 900), entry("SML", 100)])
    }
}

// Rust's serde derives, tested in qix-rs through its high score storage (`crates/qix/src/
// persist_test.rs`): the table codes as the list of its entries, skips the invalid ones and makes
// a valid table of the rest; only a value that is not a list fails.

/// Points between two entries of `distinctTable`.
private let distinctStep: UInt32 = 1_500

/// The capital letters, from which `distinctTable` names its entries.
private let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

/// A table of `Tuning.highScoreCount` entries with distinct names and scores.
private func distinctTable() throws -> HighScores {
    var table = HighScores()
    for (n, letter) in alphabet.prefix(Tuning.highScoreCount).enumerated() {
        try table.insert(entry(String(repeating: letter, count: Tuning.initialsLen), distinctStep * UInt32(n + 1)))
    }
    return table
}

private func encoded(_ table: HighScores) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return try String(bytes: encoder.encode(table), encoding: .utf8) ?? ""
}

private func decoded(_ json: String) throws -> HighScores {
    try JSONDecoder().decode(HighScores.self, from: Data(json.utf8))
}

extension HighScoreTests {
    func testAnEncodedTableDecodesBackTheSame() throws {
        let table = try distinctTable()

        XCTAssertEqual(try decoded(encoded(table)), table)
    }

    func testAnEmptyTableRoundTrips() throws {
        XCTAssertEqual(try encoded(HighScores()), "[]")
        XCTAssertEqual(try decoded("[]"), HighScores())
    }

    func testTheTableEncodesAsAReadableList() throws {
        let table = try HighScores([entry("QIX", 12_345), entry("ABC", 10)])

        XCTAssertEqual(try encoded(table), #"[{"name":"QIX","score":12345},{"name":"ABC","score":10}]"#)
    }

    func testAValueThatIsNotAListFailsToDecode() {
        for json in ["", "not json", #"{"name":"ABC","score":1}"#, #"[{"name":"ABC""#] {
            XCTAssertThrowsError(try decoded(json), json)
        }
    }

    func testAnInvalidEntryIsDroppedAndTheOthersKept() throws {
        let expected = try HighScores([entry("TOP", 900), entry("LOW", 100)])
        for bad in [
            #"{"name":"toolong","score":1}"#,
            #"{"name":"abc","score":1}"#,
            #"{"name":"A1C","score":1}"#,
            #"{"name":"ABC","score":-1}"#,
            #"{"name":"ABC","score":4294967296}"#,
            #"{"name":"ABC"}"#,
            #""ABC""#,
            "7",
            "null",
            "[1,2]",
        ] {
            let json = #"[{"name":"TOP","score":900},"# + bad + #",{"name":"LOW","score":100}]"#
            XCTAssertEqual(try decoded(json), expected, bad)
        }
    }

    func testATableEditedOutOfOrderDecodesSortedAndCut() throws {
        let list = try distinctTable().entries.reversed() + [entry("LOW", 1)]
        let json = "[" + list.map { #"{"name":"\#($0.name)","score":\#($0.score)}"# }.joined(separator: ",") + "]"

        XCTAssertEqual(try decoded(json), try distinctTable())
    }

    func testAnEntryDropsScoresOfZeroOnDecode() throws {
        XCTAssertEqual(try decoded(#"[{"name":"ZER","score":0}]"#), HighScores())
    }

    func testAnEntryWithABadNameFailsToDecode() {
        let json = Data(#"{"name":"abc","score":1}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(HighScore.self, from: json)) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("\(error)")
            }
        }
    }
}
