import XCTest
@testable import QixKit

/// A claim of twelve cells drawn fast.
private let claim = Event.claim(cells: 12, kind: .fast)

private let levelComplete = Event.levelComplete(fraction: 0.75, bonus: 0, split: false)

/// One event of each kind, with the sound it plays.
private let cases: [(Event, Sound?)] = [
    (.draw(.fast), .draw(.fast)),
    (.draw(.slow), .draw(.slow)),
    (claim, .claim),
    (.death(.sparx), .death),
    (.extraLife, .extraLife),
    (levelComplete, .levelComplete),
    (.gameOver, nil),
]

final class SoundTests: XCTestCase {
    func testEachEventPlaysItsSound() {
        for (event, sound) in cases {
            XCTAssertEqual(soundFor(event), sound, "\(event)")
        }
    }

    func testATickWithoutEventsPlaysNothing() {
        XCTAssertEqual(Sound.sounds([]), [])
    }

    func testAStepOfTheStixAlonePlaysItsBlip() {
        XCTAssertEqual(Sound.sounds([.draw(.slow)]), [.draw(.slow)])
    }

    func testAnyOtherSoundReplacesTheBlipOfTheStep() {
        let events: [Event] = [.draw(.fast), claim, levelComplete]

        XCTAssertEqual(Sound.sounds(events), [.claim, .levelComplete])
    }

    func testASoundPlaysOnceHoweverManyEventsRaiseIt() {
        let events: [Event] = [claim, .extraLife, .extraLife]

        XCTAssertEqual(Sound.sounds(events), [.claim, .extraLife])
    }

    func testTheLastDeathPlaysTheDeathAlone() {
        let events: [Event] = [.death(.qix), .gameOver]

        XCTAssertEqual(Sound.sounds(events), [.death])
    }

    func testAllListsEverySoundAnEventPlays() {
        for sound in cases.compactMap({ soundFor($0.0) }) {
            XCTAssertTrue(Sound.all.contains(sound), "\(sound) is not in all")
        }
        for sound in Sound.all {
            let played = cases.contains { soundFor($0.0) == sound }
            XCTAssertTrue(played, "no event plays \(sound)")
        }
    }

    func testAllListsNoSoundTwice() {
        for (index, sound) in Sound.all.enumerated() {
            XCTAssertFalse(Sound.all[..<index].contains(sound), "\(sound) twice")
        }
    }
}
