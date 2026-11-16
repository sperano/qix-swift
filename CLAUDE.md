# Qix

Qix for iPhone: the arcade game of claiming the playfield by drawing lines
through open space while the Qix and the Sparx hunt the player. It is
[qix-rs](https://github.com/sperano/qix-rs) brought to a touch screen; the iOS
patterns (tooling, snapshot tests, Makefile targets) come from
[solitaire](https://github.com/sperano/solitaire).

## Layout

- `QixKit/`: Swift package, the whole game. Swift 6 language mode, iOS 17 and
  macOS 14, Foundation only (no UIKit, SwiftUI or other Apple-only framework),
  so `swift test` runs on Linux and macOS. Public types are `Sendable` value
  types. Its tests are in `QixKit/Tests/QixKitTests`. `FrontEnd/` holds what
  the app takes from qix-rs's front end (`crates/qix`) that needs no Apple
  framework, so it is tested on Linux too: the fixed timestep, the input latch,
  the keyboard and game pad controls, the game loop, the palette, the HUD's
  and the screens' text, what the board draws (border, stix runs, trail
  colours, the claimed cells' pixels), the settings and their storage in
  `UserDefaults` (`Settings`, `Persist`). It also holds the touch controls (the
  floating stick's maths, the follow-the-finger steering, `TouchSteering`, and
  each touch's control) and the initials field's filter, which are the iPhone
  front end's own: qix-rs has none.
- `Qix/`: the SwiftUI app, iOS 17+, iPhone only (`TARGETED_DEVICE_FAMILY: 1`),
  landscape left and right only, full screen, status bar hidden. `App/` holds
  the entry point and the launch options (`--ui-testing`: an emptied
  `UserDefaults` suite), `Model/` the `@MainActor @Observable` `GameModel` (the
  only thing views read; it loads and saves the settings and the high
  scores), `Input/` the display link, the hardware keyboard, the game pad and
  the touch controls' zones, `Views/` the views (the playfield, the initials
  field, the settings sheet), their painters (SwiftUI `Canvas`) and their
  layout maths, `Resources/` the asset catalog and the Info.plist xcodegen
  writes.
- `QixTests/`: the app's unit tests (the model, layout maths, key map,
  Info.plist choices).
- `QixSnapshotTests/`: image comparisons with swift-snapshot-testing (pinned
  in `project.yml`); the references are in `__Snapshots__/<TestFile>/`, which
  `project.yml` excludes from the target's sources. `PlayfieldFixtures.swift`
  plays the sessions they draw from fixed seeds and scripts, with QixKit only.
- `QixUITests/`: XCUITests of the launched app, launched with `--ui-testing`
  so a run starts from the default settings and an empty table.
- `project.yml`: the XcodeGen definition. The generated `Qix.xcodeproj` and
  `Qix/Resources/Info.plist` are committed and CI fails when either differs
  from what `xcodegen generate` writes. Edit `project.yml`, regenerate, commit
  them; never hand-edit the project or the Info.plist.
- `Scripts/`: `coverage.sh` (the package's coverage gate, tested by
  `coverage_test.sh`), `select-xcode.sh` and `ci-simulators.sh` (CI's Xcode
  and simulator).

## Commands

| Command | What it does | Runs on |
| --- | --- | --- |
| `make lint` | SwiftFormat in check mode, then SwiftLint `--strict` | Linux, macOS |
| `make format` | SwiftFormat rewrites, then SwiftLint reports | Linux, macOS |
| `make coverage` | `swift test` in `QixKit` with coverage; fails below 90 % of `QixKit/Sources` | Linux, macOS |
| `make test-scripts` | `Scripts/coverage_test.sh`: the coverage gate on fixture exports | Linux, macOS |
| `make check-project` | `xcodegen generate`, fails when `Qix.xcodeproj` or `Qix/Resources/Info.plist` changed | Linux, macOS |
| `make build` | builds the app and every test bundle | macOS (Xcode) |
| `make unit` | `QixTests` on `SIMULATOR` | macOS (Xcode) |
| `make snapshot` | `QixSnapshotTests` on `SNAPSHOT_SIMULATOR` | macOS (Xcode) |
| `make record-snapshots` | rewrites the reference PNGs, then runs `make snapshot` | macOS (Xcode) |
| `make ui` | `QixUITests` on `SIMULATOR` | macOS (Xcode) |

CI (`.github/workflows/ci.yml`) runs the same targets: a lint job, a Linux
job for the package, and a macOS job for the project check, the package on
macOS and the app's build, unit, snapshot and UI tests. Before a pull request,
run `make lint`, `make coverage`, `make test-scripts` and `make check-project`;
the app targets need Xcode.

Snapshots are recorded on the iPhone 17 simulator, iOS 27.2 (Xcode 27.2), and
skip on any other device. The app is landscape only, so the host window is a
landscape one; the playfield tests also draw the iPhone SE's 667 × 375
landscape screen inside it (`SnapshotTestCase.smallPhone`, references named
`small`). When a CI run finds no reference, swift-snapshot-testing
records one and fails; the run's `snapshot-failures` artifact holds it. Never
re-record a snapshot to make it pass unless the change meant to alter that
view.

## Conventions

- **QixKit is a 1:1 port of `crates/qix-core`** of qix-rs:
  - One Swift file per Rust module, named after it in UpperCamelCase
    (`sparx_meter.rs` → `SparxMeter.swift`); a module directory
    (`game/`) becomes a directory of the same name in UpperCamelCase.
  - Tests in a sibling `*Tests.swift` named after the module
    (`sparx_meter_test.rs` → `SparxMeterTests.swift`, `tests/playthrough.rs`
    → `PlaythroughTests.swift`), never inline. A test module directory keeps its
    parent's name as a prefix (`game_test/claims.rs` →
    `GameTests/GameClaimsTests.swift`): one target cannot hold two files of the same
    name. Port each Rust test as one
    XCTest method, except a `#[should_panic]` test (or one of a
    `debug_assert!`): XCTest cannot catch a trap, so it becomes a Swift Testing
    exit test in the same file (`#expect(processExitsWith: .failure)`, then
    `expectMessage` from `TrapExpectation.swift` for the message).
  - Same names where Swift allows: types keep theirs (`Game`, `Session`,
    `InputState`); functions, fields and enum cases go from snake_case to
    lowerCamelCase (`claimed_fraction` → `claimedFraction`); a module's
    constants become static members of a caseless enum named after the module
    (`tuning::BOARD_W` → `Tuning.boardW`), or of the module's type of that
    name (`board::OUTSIDE` → `Board.outside`). A module's free functions stay
    free functions (`segments_intersect`, `legal_step`) unless the name alone
    is too generic, then they join that enum (`claim::regions` →
    `Claim.regions`, `segment::cells` → `Segment.cells`). A Rust method
    without arguments becomes a property when it reads a field or runs in
    constant time (`width()` → `width`, `head()` → `head`) and stays a method
    when it walks a collection (`claimed_fraction()`, `count()`).
  - Same doc comments, adapted only where the Swift differs (a Rust link
    becomes the Swift name).
  - Same types: Rust `f32` is `Float`, integer widths are kept (`u16` is
    `UInt16`), `usize` is `Int`. Rust's wrapping or saturating arithmetic,
    and its saturating `as` casts from `f32`, need the explicit Swift operator
    (`&+`) or a clamp, since Swift traps on overflow. The trigonometry calls
    libm by name (`sinf`, `cosf`, `hypotf`), the functions Rust's `f32` uses.
  - Same tuning values and the same SplitMix64 `Rng`, so a seed plays the same
    game as in qix-rs.
  - `FrontEnd/` follows the same rules for the `crates/qix` modules it ports
    (`timestep.rs` → `Timestep.swift`); a file whose name a core module
    already has takes its type's name (`InputLatch.swift`), since one target
    cannot hold two files of the same name.
- Engine first: a rule change goes in `QixKit` with its test, then the UI.
- Named constants for every size, ratio, count, colour and duration
  (`PlayfieldLayout`, `Palette`); no magic numbers in views or tests either.
- Files ≤ ~500 lines, functions ≤ ~50 lines; split views into small structs.
  `make lint` enforces these limits, a 120-column width and the rules in
  `.swiftlint.yml` (copied from solitaire, like `.swiftformat`).
  `no_magic_numbers` is off: the named-constant rule is a review rule.
- Every new behaviour has a test: package logic in `QixKit` (it runs
  everywhere), view maths in `QixTests`, what a view draws in
  `QixSnapshotTests`.
- Swift 6 strict concurrency everywhere: view models are `@MainActor
  @Observable`, test classes touching the UI are `@MainActor`.
