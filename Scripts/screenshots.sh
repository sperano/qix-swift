#!/bin/sh
# Takes the App Store screenshots: ScreenshotUITests on the size App Store Connect requires for an
# iPhone app (6.9-inch, which it scales down for the smaller ones), in every language. The app is
# landscape only and hides the status bar, so the shots are 2868 x 1320 and need no status bar
# override. Writes AppStore/screenshots/<locale>/<device>-<name>.png, the layout fastlane deliver
# reads. The PNGs are not committed: run this on a Mac with Xcode before a release.
set -eu

os=27.2
device="iPhone 17 Pro Max"
root=$(cd "$(dirname "$0")/.." && pwd)
# Every App Store locale with text: the folders of AppStore/metadata (its loose files are shared).
locales=$(find "$root/AppStore/metadata" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
output=$root/AppStore/screenshots
work=$(mktemp -d)
# The new shots go here, and replace the previous ones only once every locale has them.
staging=$work/screenshots
# A simulator this script boots is shut down on exit, failed or not, so the machine is left as it
# was found.
udid=
booted_here=false
cleanup() {
    if $booted_here; then xcrun simctl shutdown "$udid" || true; fi
    rm -rf "$work"
}
trap cleanup EXIT

udid_of() {
    xcrun simctl list devices available -j | python3 -c '
import json, sys
name, os = sys.argv[1], sys.argv[2]
devices = json.load(sys.stdin)["devices"]
runtime = "com.apple.CoreSimulator.SimRuntime.iOS-" + os.replace(".", "-")
print(next(d["udid"] for d in devices.get(runtime, []) if d["name"] == name))' "$1" "$os"
}

# Renames the exported attachments "<device>-<attachment name>.png" into the locale's folder, and
# fails on a portrait one: App Store Connect would show a landscape game on its side.
collect() {
    python3 - "$1" "$2" "$3" <<'PY'
import json, os, shutil, struct, sys
exported, destination, device = sys.argv[1:]
# A PNG's width and height are the first two fields of its IHDR chunk, after the 8-byte signature
# and the chunk's length and type.
size_offset = 16
with open(os.path.join(exported, "manifest.json")) as manifest:
    tests = json.load(manifest)
for test in tests:
    for attachment in test["attachments"]:
        source = os.path.join(exported, attachment["exportedFileName"])
        with open(source, "rb") as png:
            png.seek(size_offset)
            width, height = struct.unpack(">II", png.read(8))
        name = attachment["suggestedHumanReadableName"]
        stem = name.split("_")[0]  # Xcode appends "_<index>_<uuid>.png" to the name given
        if width <= height:
            sys.exit(f"{stem} is {width} x {height}, not landscape")
        shutil.copy(source, os.path.join(destination, f"{device}-{stem}.png"))
PY
}

cd "$root"
udid=$(udid_of "$device")
if xcrun simctl boot "$udid" 2>/dev/null; then booted_here=true; fi
xcrun simctl bootstatus "$udid" -b >/dev/null
slug=$(echo "$device" | tr -cd '[:alnum:]')
for locale in $locales; do
    result=$work/$slug-$locale.xcresult
    TEST_RUNNER_SCREENSHOT_LOCALE=$locale xcodebuild test -project Qix.xcodeproj \
        -scheme Qix -destination "id=$udid" -only-testing:QixUITests/ScreenshotUITests \
        -resultBundlePath "$result" CODE_SIGNING_ALLOWED=NO -quiet
    mkdir -p "$work/$slug-$locale" "$staging/$locale"
    xcrun xcresulttool export attachments --path "$result" --output-path "$work/$slug-$locale" >/dev/null
    collect "$work/$slug-$locale" "$staging/$locale" "$slug"
done
rm -rf "$output"
mv "$staging" "$output"
ls -R "$output"
