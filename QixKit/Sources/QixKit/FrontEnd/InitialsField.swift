// The text field the initials of a high score are typed in on the iPhone, in place of qix-rs's
// letters stepped with Up and Down. qix-rs has none: this is the iPhone front end's own.

/// What the initials field keeps of the text typed, and the initials it makes.
public enum InitialsField {
    /// The text the field shows for `typed`: its letters from A to Z, uppercased, at most
    /// `Tuning.initialsLen` of them; every other character is dropped.
    public static func filtered(_ typed: String) -> String {
        let letters = typed.uppercased().unicodeScalars.filter { ("A" ... "Z").contains($0) }
        return String(String.UnicodeScalarView(letters.prefix(Tuning.initialsLen)))
    }

    /// The initials `text` spells once filtered, nil until it has `Tuning.initialsLen` letters.
    public static func initials(_ text: String) -> Initials? {
        try? Initials(filtered(text))
    }
}
