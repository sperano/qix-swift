import AVFoundation
import QixKit

/// Plays what the player hears.
@MainActor
protocol SoundPlayer {
    func play(_ sound: Sound)
}

/// Plays the synthesised sound effects (`Synth`, no audio files) through an `AVAudioEngine`, one
/// player node a sound: a sound cuts its own previous play and mixes with the others, as in
/// qix-rs. The audio session is `.ambient`: the silent switch mutes the game, which mixes with
/// other apps' audio instead of stopping it. The session and the engine are set up on the first
/// sound, so with sounds off the app never touches them; when they cannot be, the game is silent.
@MainActor
final class SystemSounds: SoundPlayer {
    /// The format of the synthesised samples: mono `Float` at `Synth.sampleRate`.
    static let format = AVAudioFormat(standardFormatWithSampleRate: Double(Synth.sampleRate), channels: 1)

    /// The output, set up on the first sound; nil when it could not be.
    private lazy var output = AudioOutput()

    func play(_ sound: Sound) {
        output?.play(sound)
    }

    /// The samples of `sound` (`Synth.samples`) in a buffer of `format`; nil when none can hold
    /// them.
    static func buffer(of sound: Sound, in format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let samples = Synth.samples(sound)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }
        buffer.frameLength = buffer.frameCapacity
        return buffer
    }
}

/// The ambient audio session's engine, with a player node and the buffer it plays for each sound.
@MainActor
private final class AudioOutput {
    private let engine = AVAudioEngine()
    private var voices: [Sound: (player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer)] = [:]

    /// The output in the ambient session; nil without the samples' format or when the session
    /// refuses the category.
    init?() {
        guard let format = SystemSounds.format else { return nil }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient)
        } catch {
            return nil
        }
        try? session.setActive(true)
        for sound in Sound.all {
            guard let buffer = SystemSounds.buffer(of: sound, in: format) else { continue }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            voices[sound] = (player, buffer)
        }
    }

    /// Starts `sound` over its own previous play; a sound the engine cannot play is dropped: a
    /// missed blip is better than an error.
    func play(_ sound: Sound) {
        guard let voice = voices[sound], isRunning() else { return }
        voice.player.scheduleBuffer(voice.buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.player.isPlaying {
            voice.player.play()
        }
    }

    /// Starts the engine if it is stopped (before the first sound, or after an interruption or a
    /// change of route stopped it) and returns whether it runs.
    private func isRunning() -> Bool {
        if !engine.isRunning {
            try? engine.start()
        }
        return engine.isRunning
    }
}

/// Plays nothing; for previews and tests that do not check sounds.
@MainActor
final class SilentSounds: SoundPlayer {
    func play(_ sound: Sound) {}
}
