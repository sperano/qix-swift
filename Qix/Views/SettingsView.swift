import QixKit
import SwiftUI

/// The settings sheet, opened from the title screen: the rules of the next game, the touch
/// controls and the feedback. Each edit goes to `settings` at once. qix-rs's settings screen
/// (`settings_menu.rs`), without its key bindings and window scale.
///
/// `Settings` is written `QixKit.Settings` next to SwiftUI, whose macOS `Settings` scene has the
/// same name.
struct SettingsView: View {
    /// What UI tests find the controls by.
    static let doneIdentifier = "settingsDone"
    static let leftHandedIdentifier = "leftHanded"

    @Binding var settings: QixKit.Settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                rules
                controls
                feedback
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier(Self.doneIdentifier)
                }
            }
        }
    }

    private var rules: some View {
        Section {
            Stepper(
                value: $settings.thresholdPercent,
                in: QixKit.Settings.thresholdPercents,
                step: QixKit.Settings.thresholdStep
            ) {
                LabeledContent("Claim to clear a level", value: "\(settings.thresholdPercent)%")
            }
            .accessibilityIdentifier("threshold")
            Stepper(value: $settings.startingLivesCount, in: QixKit.Settings.startingLivesCounts) {
                LabeledContent("Starting lives", value: "\(settings.startingLivesCount)")
            }
            .accessibilityIdentifier("startingLives")
        } header: {
            Text("Rules")
        } footer: {
            Text("Changes apply to the next game.")
        }
    }

    private var controls: some View {
        Section {
            Picker("Control scheme", selection: $settings.controlScheme) {
                ForEach(ControlScheme.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("controlScheme")
            Toggle("Left-handed", isOn: $settings.leftHanded)
                .accessibilityIdentifier(Self.leftHandedIdentifier)
            Stepper(
                value: $settings.stickSizePercent,
                in: QixKit.Settings.stickSizePercents,
                step: QixKit.Settings.stickSizeStep
            ) {
                LabeledContent("Stick size", value: "\(settings.stickSizePercent)%")
            }
            .disabled(settings.controlScheme != .stick)
            .accessibilityIdentifier("stickSize")
            Stepper(
                value: $settings.opacityPercent,
                in: QixKit.Settings.opacityPercents,
                step: QixKit.Settings.opacityStep
            ) {
                LabeledContent("Opacity", value: "\(settings.opacityPercent)%")
            }
            .accessibilityIdentifier("opacity")
        } header: {
            Text("Touch controls")
        } footer: {
            Text(
                "Left-handed puts the stick right of the board and the Slow button left of it. "
                    + "Following the finger, the marker heads for a point just above the finger on the board."
            )
        }
    }

    private var feedback: some View {
        Section("Feedback") {
            Toggle("Haptics", isOn: $settings.haptics)
                .accessibilityIdentifier("haptics")
            Toggle("Sounds", isOn: $settings.sounds)
                .accessibilityIdentifier("sounds")
        }
    }
}
