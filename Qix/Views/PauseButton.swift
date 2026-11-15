import QixKit
import SwiftUI

/// What the HUD's pause button does: pause a game in play, or resume a paused one.
enum PauseButtonRole: Equatable {
    case pause, resume

    /// The button's role in `state`; none outside play and the pause.
    init?(_ state: GameState) {
        switch state {
        case .playing: self = .pause
        case .paused: self = .resume
        case .title, .levelComplete, .gameOver, .highScoreEntry: return nil
        }
    }

    /// The SF Symbol the button shows.
    var symbol: String {
        switch self {
        case .pause: "pause.fill"
        case .resume: "play.fill"
        }
    }

    /// What VoiceOver reads.
    var label: String {
        switch self {
        case .pause: "Pause"
        case .resume: "Resume"
        }
    }
}

/// The pause button, in the HUD's last column: it presses pause, as the Escape key does.
struct PauseButton: View {
    /// What UI tests find the button by.
    static let identifier = "pause"

    /// The smallest side of the area that takes the tap, in points: Apple's minimum touch target.
    static let minimumTarget: CGFloat = 44

    /// The symbol's size, as a fraction of the column's height.
    static let symbolShare: CGFloat = 0.5

    let role: PauseButtonRole
    /// The HUD column the button sits in.
    let column: CGRect
    let action: @MainActor () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: role.symbol)
                .font(.system(size: column.height * Self.symbolShare))
                .foregroundStyle(Color(Palette.hudValue))
                .frame(width: max(column.width, Self.minimumTarget), height: max(column.height, Self.minimumTarget))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(role.label)
        .accessibilityIdentifier(Self.identifier)
        .position(x: column.midX, y: column.midY)
    }
}
