import QixKit
import UIKit

/// Plays what the player feels.
@MainActor
protocol HapticPlayer {
    func play(_ haptic: Haptic)
}

/// The device's Taptic Engine: a light impact for a tick, a medium one for a bump, and the success
/// and error notifications. Each impact generator is prepared again after it plays, so the next
/// tick of a run of turns comes without the engine's start-up delay.
@MainActor
final class SystemHaptics: HapticPlayer {
    private let tick = UIImpactFeedbackGenerator(style: .light)
    private let bump = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    func play(_ haptic: Haptic) {
        switch haptic {
        case .tick: impact(tick)
        case .bump: impact(bump)
        case .success: notification.notificationOccurred(.success)
        case .error: notification.notificationOccurred(.error)
        }
    }

    private func impact(_ generator: UIImpactFeedbackGenerator) {
        generator.impactOccurred()
        generator.prepare()
    }
}

/// Plays nothing; for previews and tests that do not check haptics.
@MainActor
final class SilentHaptics: HapticPlayer {
    func play(_ haptic: Haptic) {}
}
