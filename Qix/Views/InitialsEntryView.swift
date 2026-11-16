import QixKit
import SwiftUI

/// The initials field, over the whole screen, which it dims: what the prompt asks (the score and
/// its rank) and a text field on the system keyboard keeping three letters from A to Z, uppercased
/// as they are typed (`InitialsField`), with a Done button. Done, or Return, with three letters
/// enters them. The panel is centred in the safe area, which leaves out the keyboard.
struct InitialsEntryView: View {
    /// What UI tests find the field and the button by.
    static let fieldIdentifier = "initials"
    static let doneIdentifier = "initialsDone"

    /// The heading's size, the prompt lines' and the field's, in points.
    static let headingSize: CGFloat = 28
    static let lineSize: CGFloat = 15
    static let fieldSize: CGFloat = 28
    /// The field's width, in sizes of its font: three letters and the field's margins.
    static let fieldWidthShare: CGFloat = 3.5
    /// Space between the rows of the panel, and between the field and its button, in points.
    static let spacing: CGFloat = 8
    /// Space between the panel's content and its edge, and its corner radius, in points.
    static let padding: CGFloat = 16
    static let cornerRadius: CGFloat = 8
    /// How far the text may shrink to fit above the keyboard, as a fraction of its size.
    static let minimumScale: CGFloat = 0.5

    let prompt: Screen
    /// Enters the text typed; returns whether it was taken.
    let onDone: @MainActor (String) -> Bool
    private let focusesOnAppear: Bool
    @State private var text: String
    @FocusState private var isFocused: Bool

    /// The field for `prompt` holding `text`, focused on appearing (bringing up the keyboard) unless
    /// `focusesOnAppear` is false.
    init(
        prompt: Screen, text: String = "", focusesOnAppear: Bool = true, onDone: @escaping @MainActor (String) -> Bool
    ) {
        self.prompt = prompt
        self.onDone = onDone
        self.focusesOnAppear = focusesOnAppear
        _text = State(initialValue: text)
    }

    var body: some View {
        ZStack {
            Color(Palette.screenDim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
                .accessibilityHidden(true)
            panel
        }
        .onAppear {
            if focusesOnAppear {
                isFocused = true
            }
        }
    }

    private var panel: some View {
        VStack(spacing: Self.spacing) {
            Text(prompt.heading)
                .font(.system(size: Self.headingSize, weight: .bold))
                .foregroundStyle(Color(Palette.screenHeading))
            ForEach(Array(prompt.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: Self.lineSize))
                    .foregroundStyle(Color(Palette.screenText))
            }
            HStack(spacing: Self.spacing) {
                field
                Button("Done", action: submit)
                    .buttonStyle(.borderedProminent)
                    .disabled(InitialsField.initials(text) == nil)
                    .accessibilityIdentifier(Self.doneIdentifier)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(Self.minimumScale)
        .padding(Self.padding)
        .background(RoundedRectangle(cornerRadius: Self.cornerRadius).fill(Color(Palette.screenBackground)))
    }

    private var field: some View {
        TextField("AAA", text: $text)
            .font(.system(size: Self.fieldSize, weight: .bold, design: .monospaced))
            .multilineTextAlignment(.center)
            .frame(width: Self.fieldSize * Self.fieldWidthShare)
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .submitLabel(.done)
            .focused($isFocused)
            .onSubmit(submit)
            .onChange(of: text) { _, typed in
                let filtered = InitialsField.filtered(typed)
                if filtered != typed {
                    text = filtered
                }
            }
            .accessibilityLabel("Initials")
            .accessibilityIdentifier(Self.fieldIdentifier)
    }

    /// Enters the text; the field keeps the keyboard when it is not three letters yet.
    private func submit() {
        if !onDone(text) {
            isFocused = true
        }
    }
}
