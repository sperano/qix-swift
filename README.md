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
on the title screen opens the settings, which start with a How to play page
(the rules and the controls, as the settings set them), then the share of the
board that clears a
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

## Releasing

A release is a tag. Pushing `v<MARKETING_VERSION>` (the version in
`project.yml`, three numbers, such as `v1.0.0`) on a commit of `main` whose CI
passed runs `.github/workflows/release.yml`: it archives the app in Release,
signs it with the App Store Connect API key and uploads it, and the build
appears in TestFlight. The build number is the workflow's run number, so it
grows with every upload; upload only through the workflow, or a build made in
Xcode can take a number the workflow will reach later.

```sh
# after bumping MARKETING_VERSION in project.yml (xcodegen generate) and merging it
git tag v1.0.0 origin/main && git push origin v1.0.0
```

The workflow needs four repository secrets:

| Secret | What it is |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY` | The `.p8` key file's contents (App Store Connect, Users and Access, Integrations; role Admin, which cloud-managed signing needs). |
| `APP_STORE_CONNECT_KEY_ID` | The key's ID. |
| `APP_STORE_CONNECT_ISSUER_ID` | The issuer ID shown above the keys. |
| `APPLE_TEAM_ID` | The team ID (Membership details in the developer account). |

Before the first upload, the app record must exist in App Store Connect, with
the bundle ID `quebec.spe.Qix`.

The store listing is under `AppStore/metadata/`: name, subtitle, description,
keywords, promotional text, privacy policy and support URLs (English only, as
the app is), and the copyright and category, in fastlane deliver's layout.
`Scripts/upload-listing.sh` uploads it with the age rating
(`AppStore/age_rating.json`), the review information and the screenshots
(`AppStore/Deliverfile`; see "Submitting to the App Store"). From the second
version on, each language gets a `release_notes.txt` for the version; the
first version takes none. `Scripts/app_store_test.py` (in `make test-scripts`)
checks the fields and their length limits, the privacy policy link, the age
rating, the export options and the version. The privacy policy is
`PRIVACY.md`.

The store name is *Stix: Claim the Field*, not *Qix*: QIX is a registered
trademark of Taito, and the App Review Guidelines (2.3.7, 5.2.1) refuse
another's trademark in an app's name or keywords, so the listing never uses
the word (the test checks it). The app itself still says Qix: its home-screen
name, the title screen and the How to play page.

Privacy: `Qix/Resources/PrivacyInfo.xcprivacy` declares no tracking and no
data collected, and the one API Apple asks a reason for, `UserDefaults` (the
settings and high scores the app keeps for itself). In App Store Connect the
App Privacy answer is "Data Not Collected". `PrivacyManifestTests` fails if
the code starts using another API that needs a reason before the manifest
declares it.

Screenshots: `Scripts/screenshots.sh` runs `ScreenshotUITests` on the 6.9-inch
iPhone simulator (iPhone 17 Pro Max, iOS 27.2), the size App Store Connect
requires, in every store language, and writes 2868 × 1320 landscape PNGs to
`AppStore/screenshots/<locale>/`: the attract demo, a line being drawn, the
settings and How to play. Run it before a release; the images are not
committed. The test skips in normal runs.

### Submitting to the App Store

The workflow stops at TestFlight. `Scripts/upload-listing.sh` uploads the
listing and can submit it for review; what the App Store Connect API cannot
set is done in App Store Connect. Once, before the first release:

1. In Certificates, Identifiers & Profiles, register the explicit App ID
   `quebec.spe.Qix` under the team the project signs with
   (`DEVELOPMENT_TEAM` in `project.yml`); no capabilities.
2. In App Store Connect, Apps, +, New App: iOS, the name in
   `AppStore/metadata/en-US/name.txt`, primary language English (U.S.), that
   bundle ID, any SKU (`qix`). Names are unique across the store: if it is
   taken, choose another and change `name.txt` and `PRIVACY.md`, which names
   the app. In Business, accept any pending agreement; a free app needs no
   paid-apps agreement.
3. Set the four secrets above in this repository, for example
   `gh secret set APP_STORE_CONNECT_API_KEY < AuthKey_<id>.p8`. An App Store
   Connect team key serves every app of the team, so solitaire's key will do;
   otherwise create one (role Admin). The `.p8` can be downloaded only once:
   keep it, the listing upload needs it too.
4. App Information: content rights, the app contains no third-party content
   (its sounds are synthesised in code, its sprites drawn from `Sprite.swift`).
5. App Privacy: the privacy policy URL (`privacy_url.txt`; the field is on this
   page), then "Data Not Collected", and Publish.
6. Pricing and Availability: free. The China mainland storefront needs a
   Chinese game approval number, which this app does not have: leave it out.
   In Business, the EU Digital Services Act trader status: an individual who
   sells nothing declares themselves a non-trader.

Each release:

1. Bump `MARKETING_VERSION`, run `xcodegen generate`, and from the second
   version add `release_notes.txt` in every language; merge, and wait for CI
   on `main`.
2. Tag and push (above). The build appears in TestFlight after processing.
   Export compliance is answered by `ITSAppUsesNonExemptEncryption` in
   `project.yml`, so no question is asked. Install it from TestFlight on a
   device and play a game.
3. Run `Scripts/screenshots.sh`, then upload the listing:

   ```sh
   Scripts/upload-listing.sh ~/path/to/AuthKey_<KEYID>.p8 <issuer id>
   ```

   It installs fastlane under `build/bundle` (Ruby and Bundler from Homebrew;
   fastlane's usage reporting is off), creates or edits the version
   `MARKETING_VERSION`, and uploads the name, subtitle, privacy policy URL,
   promotional text, description, keywords, support URL, What's New and the
   screenshots, plus category (Games, Arcade), copyright, age rating (4+:
   every answer None or No; the enemies are abstract lines and sparks) and
   the review notes. deliver shows a preview and asks before uploading. The
   review contact details stay out of the repository: set
   `REVIEW_FIRST_NAME`, `REVIEW_LAST_NAME`, `REVIEW_PHONE` (`+` and the
   country code first) and `REVIEW_EMAIL`. App Store Connect refuses a
   version's first upload without all four; later, an unset one is not sent,
   so the stored value stays. A new question in Apple's age-rating
   questionnaire also fails the upload until `AppStore/age_rating.json`
   answers it (the error names the attribute).
4. On the version page, choose the TestFlight build.
5. Run the upload again with `--submit` (or Add for Review, then Submit to App
   Review). The version is released by hand after approval. A rejection comes
   back in App Store Connect with the guideline it cites. A listing fix is
   resubmitted as it is; a fix to the app needs a new version (`1.0.1`), since
   its tag is what uploads a build and the rejected version's tag already
   exists.

## Licence

GPL-3.0; see `LICENSE`.
