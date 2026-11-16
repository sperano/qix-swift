// The waveforms of the sound effects, synthesised from tones so that the game ships no audio files:
// qix-rs's `crates/qix/src/synth.rs`.

/// The shape of one cycle of a tone.
public enum Wave: Hashable, Sendable {
    /// Full amplitude for the first half of the cycle, its opposite for the second.
    case square
    /// A linear rise and fall over the cycle.
    case triangle

    /// The value of the wave `phase` of the way through its cycle, from 0 to 1, between -1 and 1.
    func at(_ phase: Float) -> Float {
        switch self {
        case .square where phase < 0.5: 1
        case .square: -1
        case .triangle: 4 * abs(phase - 0.5) - 1
        }
    }
}

/// A tone gliding linearly from one frequency to another.
public struct Tone: Hashable, Sendable {
    public var wave: Wave
    /// Frequency at the start, in hertz.
    public var fromHz: Float
    /// Frequency at the end, in hertz.
    public var toHz: Float
    /// Length in seconds.
    public var secs: Float

    public init(wave: Wave, fromHz: Float, toHz: Float, secs: Float) {
        self.wave = wave
        self.fromHz = fromHz
        self.toHz = toHz
        self.secs = secs
    }
}

/// The constants and the tones of the synthesiser.
public enum Synth {
    /// Samples per second of every waveform; the audio output resamples them to its own rate.
    public static let sampleRate: UInt32 = 44_100

    /// Peak amplitude of every tone, from 0 to 1, leaving headroom for several sounds at once.
    public static let amplitude: Float = 0.25

    /// Seconds the amplitude takes to rise at the start of a tone and to fall at its end, so that it
    /// starts and stops without a click.
    public static let rampSecs: Float = 0.004

    /// Frequencies of the notes of the jingles, in hertz.
    private static let c5: Float = 523.25
    private static let e5: Float = 659.25
    private static let g5: Float = 783.99
    private static let c6: Float = 1_046.5
    private static let e6: Float = 1_318.5
    private static let g6: Float = 1_568.0

    /// A tone gliding from `fromHz` to `toHz` over `secs` seconds.
    private static func glide(_ wave: Wave, _ fromHz: Float, _ toHz: Float, _ secs: Float) -> Tone {
        Tone(wave: wave, fromHz: fromHz, toHz: toHz, secs: secs)
    }

    /// A tone holding `hz` for `secs` seconds.
    private static func note(_ wave: Wave, _ hz: Float, _ secs: Float) -> Tone {
        glide(wave, hz, hz, secs)
    }

    /// Pitch and length of the fast step's blip.
    private static let drawFastHz: Float = 1_000
    private static let drawFastSecs: Float = 0.02

    /// Pitch and length of the slow step's blip.
    private static let drawSlowHz: Float = 500
    private static let drawSlowSecs: Float = 0.04

    /// Start and end pitches of the claim's sweep, and its length.
    private static let claimFromHz: Float = 300
    private static let claimToHz: Float = 1_200
    private static let claimSecs: Float = 0.18

    /// Start and end pitches of the death's sweep, and its length.
    private static let deathFromHz: Float = 900
    private static let deathToHz: Float = 60
    private static let deathSecs: Float = 0.8

    /// Length of each note of the level's arpeggio but the last, and of the last, held.
    private static let arpeggioNoteSecs: Float = 0.12
    private static let arpeggioHeldSecs: Float = 0.3

    /// Length of each note of the extra life's trill.
    private static let trillNoteSecs: Float = 0.06

    /// A high blip for each fast step, shorter than the `Tuning.markerStepTicks` between two of
    /// them.
    private static let drawFast = [note(.square, drawFastHz, drawFastSecs)]

    /// A lower blip for each slow step, shorter than the `Tuning.slowStepTicks` between two of them.
    private static let drawSlow = [note(.square, drawSlowHz, drawSlowSecs)]

    /// A rising sweep.
    private static let claim = [glide(.triangle, claimFromHz, claimToHz, claimSecs)]

    /// A long falling sweep.
    private static let death = [glide(.square, deathFromHz, deathToHz, deathSecs)]

    /// A rising arpeggio, its last note held.
    private static let levelComplete = [
        note(.triangle, c5, arpeggioNoteSecs),
        note(.triangle, e5, arpeggioNoteSecs),
        note(.triangle, g5, arpeggioNoteSecs),
        note(.triangle, c6, arpeggioHeldSecs),
    ]

    /// A quick high trill.
    private static let extraLife = [
        note(.square, e6, trillNoteSecs),
        note(.square, g6, trillNoteSecs),
        note(.square, e6, trillNoteSecs),
        note(.square, g6, trillNoteSecs),
    ]

    /// The tones `sound` plays, one after the other.
    public static func tones(_ sound: Sound) -> [Tone] {
        switch sound {
        case .draw(.fast): drawFast
        case .draw(.slow): drawSlow
        case .claim: claim
        case .death: death
        case .levelComplete: levelComplete
        case .extraLife: extraLife
        }
    }

    /// The mono samples of `sound` at `sampleRate`: those of its `tones` one after the other.
    public static func samples(_ sound: Sound) -> [Float] {
        tones(sound).flatMap(toneSamples)
    }

    /// The number of samples `tone` lasts at `sampleRate`.
    private static func toneLen(_ tone: Tone) -> Int {
        Int((tone.secs * Float(sampleRate)).rounded())
    }

    /// The samples of `tone`, at `amplitude` between its ramps.
    public static func toneSamples(_ tone: Tone) -> [Float] {
        let len = toneLen(tone)
        var phase: Float = 0
        return (0 ..< len).map { i in
            let progress = Float(i) / Float(len)
            let hz = tone.fromHz + (tone.toHz - tone.fromHz) * progress
            let value = tone.wave.at(phase) * amplitude * envelope(i, len)
            phase = fract(phase + hz / Float(sampleRate))
            return value
        }
    }

    /// The gain of sample `i` of `len`: rising from 0 over `rampSecs` at the start, 1 in the middle,
    /// falling towards 0 over the last `rampSecs`.
    private static func envelope(_ i: Int, _ len: Int) -> Float {
        let ramp = rampSecs * Float(sampleRate)
        let fromStart = Float(i) / ramp
        let toEnd = Float(len - i) / ramp
        return min(fromStart, toEnd, 1)
    }

    /// The fractional part of `value`, as Rust's `f32::fract`: `value` less its integer part.
    private static func fract(_ value: Float) -> Float {
        value - value.rounded(.towardZero)
    }
}
