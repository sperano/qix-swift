# Qix

Qix for iPhone, in Swift. Claim the playfield by drawing lines through open
space while avoiding the Qix, which roams the open area, and the Sparx, which
travel the border. Close a line back onto the border and the side without the
Qix is yours; drawing slowly earns more points but leaves you exposed longer.
Claim enough of the playfield to clear the level.

It is a port of [qix-rs](https://github.com/sperano/qix-rs), a Rust clone of
the 1981 arcade game, brought to a touch screen. iPhone only, landscape only.

Status: the whole game plays with the touch controls below, a hardware
keyboard or a game controller. Tap the board to start or continue, and pause
with the button in the HUD. The title screen lists the ten best scores; a game
that makes the table asks for three initials, typed on the keyboard. The gear
on the title screen opens the settings: the share of the board that clears a
level (50 to 90 %), the starting lives, the control scheme, a left-handed swap
of the touch controls, the stick's size and the controls' opacity, haptics (on
by default: a tick on a turn and on leaving the border, a bump on a refused
step, a success on a claim, an error on a death) and sounds (off by default:
qix-rs's synthesised tones, muted by the silent switch). Rule changes apply to
the next game. The settings and the high scores are kept between launches. Left
idle for ten seconds, the title screen plays a demo game; any touch stops it,
and a tap on the board starts a game.

| Key | Game controller | |
| --- | --- | --- |
| Arrows | Left stick or D-pad | move |
| Z (held) | A (held) | draw fast |
| X (held) | B (held) | draw slow, double points |
| Return | A | start, continue |
| Escape | Menu | pause, resume |

## Touch controls

The 4:3 playfield fills the height of the screen and leaves a strip on each
side for a thumb, so the controls never cover the board.

- **Steering: a floating stick** under the left thumb. Where the thumb lands
  is the stick's centre; dragging picks one of four directions. Lifting the
  thumb stops the marker. The left-handed setting puts the stick on the
  right and the Slow button on the left.
- **Drawing** starts by steering off the border: holding a direction draws
  fast. Hold the **Slow** button under the other thumb to draw slowly, for
  more points.
- **Stopping** while drawing is lifting the thumb; after half a second the
  fuse lights and burns along the line toward the marker.
- **Follow the finger**, the other control scheme in the settings: touch the
  playfield and the marker heads for the point just above the finger (a ring
  shows it), along the longer axis first, and round the border when the point
  is on it. Dragging moves the point and shapes the line; lifting the finger
  stops the marker. The Slow button stays beside the board.

A hardware keyboard and game controllers work too.

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
