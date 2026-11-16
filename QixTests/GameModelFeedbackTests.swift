import QixKit
import XCTest
@testable import Qix

/// One frame at the tick rate: one tick.
private let frame: TimeInterval = 1.0 / Double(Tuning.tickHz)

/// Seed of every game the tests play.
private let modelSeed: UInt64 = 1

/// Records the haptics a model plays.
@MainActor
private final class HapticsSpy: HapticPlayer {
    private(set) var played: [Haptic] = []

    func play(_ haptic: Haptic) {
        played.append(haptic)
    }
}

/// Records the sounds a model plays.
@MainActor
private final class SoundsSpy: SoundPlayer {
    private(set) var played: [Sound] = []

    func play(_ sound: Sound) {
        played.append(sound)
    }
}

/// The tests of the haptics and the sounds the model plays from the loop's queues, as the settings
/// allow.
@MainActor
final class GameModelFeedbackTests: XCTestCase {
    private var haptics: HapticsSpy!
    private var sounds: SoundsSpy!
    private var model: GameModel!

    override func setUp() async throws {
        try await super.setUp()
        haptics = HapticsSpy()
        sounds = SoundsSpy()
    }

    /// A model with `settings` on the title screen of a new game, playing on the spies.
    private func makeModel(_ settings: Settings = Settings()) {
        let session = Session(game: Game(rng: Rng(seed: modelSeed)))
        model = GameModel(session: session, settings: settings, haptics: haptics, sounds: sounds)
    }

    /// Runs `count` frames of one tick each.
    private func frames(_ count: UInt32) {
        for _ in 0 ..< count {
            model.advance(by: frame, pad: nil)
        }
    }

    /// Taps, runs the frame that starts the game, then draws the stix's first step up from the
    /// border: a tick for the press, a tick for leaving the border and the blip of the step.
    private func drawOneStep(file: StaticString = #filePath, line: UInt = #line) {
        model.tap()
        frames(1)
        XCTAssertEqual(model.session.state, .playing, file: file, line: line)
        model.keyDown(.fast)
        model.keyDown(.up)
        frames(Tuning.markerStepTicks)
        XCTAssertEqual(model.session.game.stix?.kinds, [DrawKind.fast], file: file, line: line)
    }

    func testByDefaultTheHapticsPlayAndTheSoundsDoNot() {
        makeModel()

        drawOneStep()

        XCTAssertEqual(haptics.played, [.tick, .tick])
        XCTAssertEqual(sounds.played, [])
    }

    func testTheSoundsPlayWhenOn() {
        makeModel(Settings(sounds: true))

        drawOneStep()

        XCTAssertEqual(sounds.played, [.draw(.fast)])
    }

    func testTheHapticsDoNotPlayWhenOff() {
        makeModel(Settings(haptics: false, sounds: true))

        drawOneStep()

        XCTAssertEqual(haptics.played, [])
        XCTAssertEqual(sounds.played, [.draw(.fast)])
    }

    /// The marker stands on its stix once the keys are up: the frames after the step queue nothing,
    /// and nothing already played plays again.
    func testEachHapticAndSoundPlaysOnce() {
        makeModel(Settings(sounds: true))
        drawOneStep()
        model.releaseKeys()

        frames(Tuning.markerStepTicks)

        XCTAssertEqual(haptics.played, [.tick, .tick])
        XCTAssertEqual(sounds.played, [.draw(.fast)])
    }

    /// What the frames queued while the settings were off is dropped, not played once they are on.
    func testWhatWasQueuedWhileOffIsNotPlayedOnceOn() {
        makeModel(Settings(haptics: false))
        drawOneStep()
        model.releaseKeys()

        model.settings.haptics = true
        model.settings.sounds = true
        frames(Tuning.markerStepTicks)

        XCTAssertEqual(haptics.played, [])
        XCTAssertEqual(sounds.played, [])
    }
}
