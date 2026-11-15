import Foundation
import Testing

// XCTest cannot catch a trap, so a Rust `#[should_panic(expected = ...)]` test becomes a Swift
// Testing exit test: the call runs in a child process, `#expect(processExitsWith: .failure,
// observing: [\.standardErrorContent])` checks it failed, and `expectMessage` that the failure is
// the expected one.

/// The child process of `result` printed `message` on its standard error: the failed
/// precondition's message.
func expectMessage(
    _ result: ExitTest.Result?,
    _ message: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let standardError = String(bytes: result?.standardErrorContent ?? [], encoding: .utf8) ?? ""
    #expect(standardError.contains(message), "\(standardError)", sourceLocation: sourceLocation)
}
