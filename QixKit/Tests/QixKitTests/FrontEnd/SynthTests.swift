import XCTest
@testable import QixKit

/// Allowed error on the amplitude of a sample.
private let epsilon: Float = 1e-6

/// The most that rounding the length of a tone to whole samples adds to or takes from its seconds.
private let halfSampleSecs: Float = 0.5 / Float(Synth.sampleRate)

/// The number of times `samples` goes from below zero to zero or above.
private func risingCrossings(_ samples: [Float]) -> Int {
    zip(samples, samples.dropFirst()).count { $0 < 0 && $1 >= 0 }
}

/// The seconds `sound` lasts.
private func secs(_ sound: Sound) -> Float {
    Float(Synth.samples(sound).count) / Float(Synth.sampleRate)
}

/// Phases a quarter of a cycle apart, from the start of the cycle.
private let quarterPhases: [Float] = [0, 0.25, 0.5, 0.75]

final class SynthTests: XCTestCase {
    func testEveryToneLastsItsSeconds() {
        for sound in Sound.all {
            for tone in Synth.tones(sound) {
                let secs = Float(Synth.toneSamples(tone).count) / Float(Synth.sampleRate)
                XCTAssertGreaterThan(tone.secs, 0, "\(tone) is empty")
                XCTAssertLessThanOrEqual(abs(secs - tone.secs), halfSampleSecs, "\(tone): \(secs) s")
            }
        }
    }

    func testAToneOfTwentyMillisecondsHas882Samples() {
        let tone = Tone(wave: .square, fromHz: 1_000.0, toHz: 1_000.0, secs: 0.02)

        XCTAssertEqual(Synth.toneSamples(tone).count, 882)
    }

    func testEverySoundLastsTheSecondsOfItsTones() {
        for sound in Sound.all {
            let tones = Synth.tones(sound)
            let declared = tones.map(\.secs).reduce(0, +)
            let rounding = Float(tones.count) * halfSampleSecs
            let secs = secs(sound)
            XCTAssertLessThanOrEqual(abs(secs - declared), rounding, "\(sound): \(secs) s")
        }
    }

    func testEverySampleStaysWithinTheAmplitude() {
        for sound in Sound.all {
            let peak = Synth.samples(sound).reduce(Float(0)) { max($0, abs($1)) }
            XCTAssertLessThanOrEqual(peak, Synth.amplitude + epsilon, "\(sound) peaks at \(peak)")
            XCTAssertGreaterThan(peak, Synth.amplitude / 2, "\(sound) is too quiet: \(peak)")
        }
    }

    func testEveryToneStartsSilentAndEndsNearSilence() {
        let ramp = Synth.rampSecs * Float(Synth.sampleRate)
        for sound in Sound.all {
            for tone in Synth.tones(sound) {
                let samples = Synth.toneSamples(tone)
                XCTAssertEqual(samples.first, 0, "\(tone)")
                let last = samples.last ?? 0
                XCTAssertLessThanOrEqual(abs(last), Synth.amplitude / ramp + epsilon, "\(tone): \(last)")
            }
        }
    }

    func testAHeldNoteCyclesAtItsFrequency() {
        let hz: Float = 441.0
        let tone = Tone(wave: .square, fromHz: hz, toHz: hz, secs: 1.0)

        let crossings = risingCrossings(Synth.toneSamples(tone))

        XCTAssertLessThanOrEqual(abs(Float(crossings) - hz), 1.0, "\(crossings) cycles")
    }

    func testAGlideCyclesAtItsMeanFrequency() {
        let tone = Tone(wave: .triangle, fromHz: 200.0, toHz: 600.0, secs: 1.0)

        let crossings = risingCrossings(Synth.toneSamples(tone))

        XCTAssertLessThanOrEqual(abs(Float(crossings) - 400.0), 1.0, "\(crossings) cycles")
    }

    func testADrawBlipEndsBeforeTheNextStep() {
        for (kind, ticks) in [(DrawKind.fast, Tuning.markerStepTicks), (.slow, Tuning.slowStepTicks)] {
            let stepSecs = Float(ticks) / Float(Tuning.tickHz)
            let blip = secs(.draw(kind))
            XCTAssertLessThan(blip, stepSecs, "\(kind): \(blip) s per \(stepSecs) s step")
        }
    }

    func testTheFastBlipIsHigherThanTheSlowOne() {
        let pitch = { (kind: DrawKind) in Synth.tones(.draw(kind))[0].fromHz }

        XCTAssertGreaterThan(pitch(.fast), pitch(.slow))
    }

    func testASquareWaveHoldsFullAmplitudeForHalfACycleThenItsOpposite() {
        XCTAssertEqual(quarterPhases.map(Wave.square.at), [1, 1, -1, -1])
    }

    func testATriangleWaveFallsToItsTroughAtHalfACycleAndRisesBack() {
        XCTAssertEqual(quarterPhases.map(Wave.triangle.at), [1, 0, -1, 0])
    }
}
