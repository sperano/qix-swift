import XCTest
@testable import QixKit

/// The section of `sheet` titled `title`.
private func section(_ title: String, of sheet: HowToPlay, file: StaticString = #filePath, line: UInt = #line)
    throws -> HowToPlay.Section
{
    try XCTUnwrap(sheet.sections.first { $0.title == title }, "no \(title) section", file: file, line: line)
}

final class HowToPlayTests: XCTestCase {
    func testTheSectionsComeInReadingOrder() {
        let titles = HowToPlay(settings: Settings()).sections.map(\.title)

        XCTAssertEqual(titles, ["Goal", "Touch controls", "Keyboard and controller", "Dangers", "Scoring", "Levels"])
    }

    func testTheGoalAtTheDefaultSettings() throws {
        let goal = try section("Goal", of: HowToPlay(settings: Settings()))

        XCTAssertEqual(goal.paragraphs, [
            "Claim 75% of the board to clear the level.",
            "Leave the border into the open to draw a stix, then bring it back to the border: "
                + "the area it cuts off from the Qix is claimed. A stix cannot cross itself.",
            "You start with 3 lives.",
        ])
    }

    func testTheGoalTellsTheThresholdAndTheLivesTheSettingsChoose() throws {
        var settings = Settings()
        settings.thresholdPercent = 60
        settings.startingLivesCount = 5

        let goal = try section("Goal", of: HowToPlay(settings: settings))

        XCTAssertEqual(goal.paragraphs.first, "Claim 60% of the board to clear the level.")
        XCTAssertEqual(goal.paragraphs.last, "You start with 5 lives.")
    }

    func testOneStartingLifeIsSingular() throws {
        var settings = Settings()
        settings.startingLivesCount = 1

        let goal = try section("Goal", of: HowToPlay(settings: settings))

        XCTAssertEqual(goal.paragraphs.last, "You start with 1 life.")
    }

    func testTheStickIsLeftOfTheBoardAndSlowRightOfIt() throws {
        let touch = try section("Touch controls", of: HowToPlay(settings: Settings()))

        XCTAssertEqual(touch.paragraphs, [
            "Drag the stick left of the board to move along the border; push into the open to draw a fast stix.",
            "Hold Slow, right of the board, while moving to draw a slow stix: it is slower, but scores x2 points.",
            "Tap the board to start or continue. The button above the board pauses.",
        ])
    }

    func testLeftHandedSwapsTheSidesOfTheStickAndSlow() throws {
        var settings = Settings()
        settings.leftHanded = true

        let touch = try section("Touch controls", of: HowToPlay(settings: settings))

        XCTAssertEqual(
            touch.paragraphs[0],
            "Drag the stick right of the board to move along the border; push into the open to draw a fast stix."
        )
        XCTAssertEqual(
            touch.paragraphs[1],
            "Hold Slow, left of the board, while moving to draw a slow stix: it is slower, but scores x2 points."
        )
    }

    func testFollowingTheFingerTellsTheBoardInsteadOfTheStick() throws {
        var settings = Settings()
        settings.controlScheme = .followTheFinger
        settings.leftHanded = true

        let touch = try section("Touch controls", of: HowToPlay(settings: settings))

        XCTAssertEqual(touch.paragraphs, [
            "Touch the board: the marker heads for the point just above your finger, "
                + "along the border or drawing a fast stix through the open.",
            "Hold Slow, left of the board, while moving to draw a slow stix: it is slower, but scores x2 points.",
            "Tap the board to start or continue. The button above the board pauses.",
        ])
    }

    func testTheKeyboardAndTheController() throws {
        let keys = try section("Keyboard and controller", of: HowToPlay(settings: Settings()))

        XCTAssertEqual(keys.paragraphs, [
            "Keyboard: the arrows move, hold Z to draw fast or X to draw slow, Return confirms, Escape pauses.",
            "Controller: the left stick or the D-pad moves, hold A to draw fast or B to draw slow, "
                + "A confirms, Menu pauses.",
        ])
    }

    func testTheDangers() throws {
        let dangers = try section("Dangers", of: HowToPlay(settings: Settings()))

        XCTAssertEqual(dangers.paragraphs, [
            "The Qix takes a life when it touches your stix or the marker drawing it.",
            "Sparx run along the border and take a life when they reach the marker.",
            "Stop while drawing and a fuse lights at the start of the stix and burns towards the marker; "
                + "move on to put it out.",
            "The Sparx meter above the board counts down. When it runs out, 2 more Sparx come in at the top; "
                + "when it runs out again, every Sparx turns Super and chases the marker along the stix.",
            "After a life is lost, the Sparx cannot hurt you and you cannot draw for 2 seconds.",
        ])
    }

    func testTheScoringAtTheDefaultThreshold() throws {
        let scoring = try section("Scoring", of: HowToPlay(settings: Settings()))

        XCTAssertEqual(scoring.paragraphs, [
            "Each claimed cell scores 10 points times the multiplier, x2 when the whole stix was drawn slow.",
            "Clearing a level adds 1,000 points for each whole percent claimed past 75%.",
            "An extra life every 30,000 points, up to 9 lives.",
        ])
    }

    func testTheBonusCountsFromTheThresholdTheSettingsChoose() throws {
        var settings = Settings()
        settings.thresholdPercent = 90

        let scoring = try section("Scoring", of: HowToPlay(settings: settings))

        XCTAssertEqual(
            scoring.paragraphs[1],
            "Clearing a level adds 1,000 points for each whole percent claimed past 90%."
        )
    }

    func testTheLevels() throws {
        let levels = try section("Levels", of: HowToPlay(settings: Settings()))

        XCTAssertEqual(levels.paragraphs, [
            "From level 3, two Qix fly. Cut them apart with a stix and the level ends at once, without a bonus, "
                + "but the multiplier rises by one, up to x9.",
            "Up to level 11, each level speeds the Qix up and shortens the Sparx meter, "
                + "and every 2 levels add a Sparx.",
        ])
    }
}
