# Qix

Qix for iPhone, in Swift. Claim the playfield by drawing lines through open
space while avoiding the Qix, which roams the open area, and the Sparx, which
travel the border. Close a line back onto the border and the side without the
Qix is yours; drawing slowly earns more points but leaves you exposed longer.
Claim enough of the playfield to clear the level.

It is a port of [qix-rs](https://github.com/sperano/qix-rs), a Rust clone of
the 1981 arcade game, brought to a touch screen. iPhone only, landscape only.

Status: repository skeleton; the app shows an empty playfield.

## Planned touch controls

The 4:3 playfield fills the height of the screen and leaves a strip on each
side for a thumb, so the controls never cover the board.

- **Steering: a floating stick** under the left thumb (the right one with the
  left-handed setting). Where the thumb lands is the stick's centre; dragging
  picks one of four directions. Lifting the thumb stops the marker.
- **Drawing** starts by steering off the border: holding a direction draws
  fast. Hold the **Slow** button under the other thumb to draw slowly, for
  more points.
- **Stopping** while drawing is lifting the thumb; after half a second the
  fuse lights and burns along the line toward the marker.
- **Follow the finger**, as a setting: touch the playfield and the marker
  heads for the point under the finger.

A hardware keyboard and game controllers will work too.

## Building

The game logic is the `QixKit` Swift package, which builds and tests anywhere
Swift runs:

```sh
make coverage   # the package tests, failing below 90 % line coverage
make lint       # SwiftFormat and SwiftLint (brew install swiftformat swiftlint)
```

The app needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen):
`xcodegen generate` writes `Qix.xcodeproj` from `project.yml`, and `make
build`, `make unit`, `make snapshot` and `make ui` build and test it on the
iPhone 17 simulator. `CLAUDE.md` has the layout and the conventions.

## Licence

GPL-3.0; see `LICENSE`.
