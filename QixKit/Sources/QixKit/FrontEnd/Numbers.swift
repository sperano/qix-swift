// Numbers as the player reads them: qix-rs's `crates/qix/src/numbers.rs`.

public enum Numbers {
    /// Digits between two thousands separators.
    static let group = 3

    /// Between two groups of digits.
    static let separator: Character = ","

    /// `n` in decimal with its digits grouped by thousands: `1234567` reads `1,234,567`.
    public static func thousands(_ n: UInt32) -> String {
        let digits = String(n)
        var grouped = ""
        for (i, digit) in digits.enumerated() {
            if i > 0, (digits.count - i).isMultiple(of: group) {
                grouped.append(separator)
            }
            grouped.append(digit)
        }
        return grouped
    }
}
