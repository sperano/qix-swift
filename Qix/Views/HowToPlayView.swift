import QixKit
import SwiftUI

/// The rules of the game and its controls (`HowToPlay`), one list section to each of the sheet's
/// sections, pushed from the settings sheet.
struct HowToPlayView: View {
    /// What UI tests find the list by.
    static let identifier = "howToPlay"
    static let title = "How to play"

    let sheet: HowToPlay

    var body: some View {
        List {
            ForEach(sheet.sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.paragraphs, id: \.self) { Text($0) }
                }
            }
        }
        .accessibilityIdentifier(Self.identifier)
        .navigationTitle(Self.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
