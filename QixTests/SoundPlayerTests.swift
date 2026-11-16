import AVFoundation
import QixKit
import XCTest
@testable import Qix

@MainActor
final class SoundPlayerTests: XCTestCase {
    func testTheFormatIsMonoAtTheSynthsRate() throws {
        let format = try XCTUnwrap(SystemSounds.format)

        XCTAssertEqual(format.channelCount, 1)
        XCTAssertEqual(format.sampleRate, Double(Synth.sampleRate))
        XCTAssertEqual(format.commonFormat, .pcmFormatFloat32)
    }

    func testEachSoundsBufferHoldsItsSamples() throws {
        let format = try XCTUnwrap(SystemSounds.format)
        for sound in Sound.all {
            let samples = Synth.samples(sound)

            let buffer = try XCTUnwrap(SystemSounds.buffer(of: sound, in: format), "\(sound)")

            XCTAssertEqual(Int(buffer.frameLength), samples.count, "\(sound)")
            let channel = try XCTUnwrap(buffer.floatChannelData?[0], "\(sound)")
            let held = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            XCTAssertEqual(held, samples, "\(sound)")
        }
    }
}
