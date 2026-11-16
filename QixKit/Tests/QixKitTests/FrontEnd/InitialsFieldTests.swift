import XCTest
@testable import QixKit

final class InitialsFieldTests: XCTestCase {
    func testLowercaseLettersAreUppercased() {
        XCTAssertEqual(InitialsField.filtered("qiX"), "QIX")
    }

    func testCharactersOtherThanLettersAreDropped() {
        XCTAssertEqual(InitialsField.filtered("a1 b-c"), "ABC")
        XCTAssertEqual(InitialsField.filtered("é9!"), "")
        XCTAssertEqual(InitialsField.filtered(""), "")
    }

    func testTheTextStopsAtTheInitialsLength() {
        XCTAssertEqual(InitialsField.filtered("abcdef"), "ABC")
        XCTAssertEqual(InitialsField.filtered("ab"), "AB")
    }

    func testTheInitialsAreThoseOfTheFilteredText() throws {
        XCTAssertEqual(InitialsField.initials("a.b.c.d"), try Initials("ABC"))
    }

    func testTooFewLettersMakeNoInitials() {
        XCTAssertNil(InitialsField.initials("ab"))
        XCTAssertNil(InitialsField.initials("a1b2"))
        XCTAssertNil(InitialsField.initials(""))
    }
}
