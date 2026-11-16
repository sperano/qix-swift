import QixKit
import SwiftUI

/// What the HUD's button does: pause a game in play, resume a paused one, or open the settings
/// from the title screen.
enum HudButtonRole: Equatable {
    case pause, resume, settings

    /// The button's role in `state`; none on the other screens.
    init?(_ state: GameState) {
        switch state {
        case .playing: self = .pause
        case .paused: self = .resume
        case .title: self = .settings
        case .levelComplete, .gameOver, .highScoreEntry: return nil
        }
    }

    /// The SF Symbol the button shows.
    var symbol: String {
        switch self {
        case .pause: "pause.fill"
        case .resume: "play.fill"
        case .settings: "gearshape.fill"
        }
    }

    /// What VoiceOver reads.
    var label: String {
        switch self {
        case .pause: "Pause"
        case .resume: "Resume"
        case .settings: "Settings"
        }
    }

    /// What UI tests find the button by: one for pausing and resuming, whose label tells which.
    var identifier: String {
        switch self {
        case .pause, .resume: "pause"
        case .settings: "settings"
        }
    }
}

/// The button in the HUD's last column: it presses pause, as the Escape key does, or opens the
/// settings.
struct HudButton: View {
    /// The smallest side of the area that takes the tap, in points: Apple's minimum touch target.
    static let minimumTarget: CGFloat = 44

    /// The symbol's size, as a fraction of the column's height.
    static let symbolShare: CGFloat = 0.5

    /// The area that takes the tap in a HUD column of `column`: the column, grown to
    /// `minimumTarget` on each side that is shorter.
    static func targetSize(_ column: CGSize) -> CGSize {
        CGSize(width: max(column.width, minimumTarget), height: max(column.height, minimumTarget))
    }

    let role: HudButtonRole
    /// The HUD column the button sits in.
    let column: CGRect
    let action: @MainActor () -> Void

    /// The area that takes the tap.
    private var target: CGSize {
        Self.targetSize(column.size)
    }

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: role.symbol)
                .font(.system(size: column.height * Self.symbolShare))
                .foregroundStyle(Color(Palette.hudValue))
                .frame(width: target.width, height: target.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(role.label)
        .accessibilityIdentifier(role.identifier)
        .position(x: column.midX, y: column.midY)
    }
}
