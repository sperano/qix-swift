import QixKit
import SwiftUI

/// A screen over the board, which it dims, still visible: its heading, its table in a monospace
/// font and its lines, centred on a panel. qix-rs's `render/screen.rs`.
struct ScreenView: View {
    /// What UI tests find the panel by.
    static let identifier = "screen"

    let screen: Screen
    let field: CGRect

    var body: some View {
        let line = ScreenLayout.lineSize(screen, fieldHeight: field.height)
        ZStack {
            Rectangle().fill(Color(Palette.screenDim))
            ScreenPanel(screen: screen, line: line)
                .padding(line * ScreenLayout.padding)
                .background(
                    RoundedRectangle(cornerRadius: line * ScreenLayout.cornerRadius)
                        .fill(Color(Palette.screenBackground))
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(Self.identifier)
        }
        .frame(width: field.width, height: field.height)
        .position(x: field.midX, y: field.midY)
        .allowsHitTesting(false)
    }
}

/// The text of a screen, lines `line` points high.
private struct ScreenPanel: View {
    let screen: Screen
    let line: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Text(screen.heading)
                .font(.system(size: line * ScreenLayout.headingScale, weight: .bold))
                .foregroundStyle(Color(Palette.screenHeading))
                .padding(.bottom, line * ScreenLayout.gap)
            ForEach(Array(screen.table.enumerated()), id: \.offset) { _, text in
                row(text, design: .monospaced)
            }
            if !screen.table.isEmpty {
                Spacer().frame(height: line * ScreenLayout.gap)
            }
            ForEach(Array(screen.lines.enumerated()), id: \.offset) { _, text in
                row(text, design: .default)
            }
        }
    }

    /// One row of text; an empty one keeps its height.
    private func row(_ text: String, design: Font.Design) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: line, design: design))
            .foregroundStyle(Color(Palette.screenText))
            .lineLimit(1)
            .frame(height: line * ScreenLayout.rowHeight)
    }
}
