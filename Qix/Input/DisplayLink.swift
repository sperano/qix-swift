import QixKit
import QuartzCore

/// Calls back once a frame of the display with the time since the frame before, from a
/// `CADisplayLink` at the core's tick rate: the game state changes once a tick, so a faster display
/// would draw each state twice.
@MainActor
final class DisplayLink: NSObject {
    /// The frame rate asked for: `Tuning.tickHz`.
    nonisolated static let frameRate = Float(Tuning.tickHz)

    private var link: CADisplayLink?
    private var previous: CFTimeInterval?
    private var onFrame: @MainActor (CFTimeInterval) -> Void = { _ in }

    /// Starts calling `onFrame` every frame; does nothing while running.
    func start(_ onFrame: @escaping @MainActor (CFTimeInterval) -> Void) {
        guard link == nil else { return }
        self.onFrame = onFrame
        let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: Self.frameRate, maximum: Self.frameRate, preferred: Self.frameRate
        )
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// Stops the callbacks; the next `start` begins with a frame of the display's own duration.
    func stop() {
        link?.invalidate()
        link = nil
        previous = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
        let dt = Self.frameTime(previous: previous, now: link.timestamp, duration: link.duration)
        previous = link.timestamp
        onFrame(dt)
    }

    /// The time a frame shown at `now` stands for: since the frame shown at `previous`, or the
    /// display's frame `duration` for the first one.
    nonisolated static func frameTime(previous: CFTimeInterval?, now: CFTimeInterval, duration: CFTimeInterval)
        -> CFTimeInterval
    {
        previous.map { now - $0 } ?? duration
    }
}
