#!/bin/sh
# Tests of Scripts/screenshots.sh with xcrun and xcodebuild stubbed, in a copy of the repository's
# layout so the real AppStore/screenshots is never touched: the shots are named after the device and
# replace the previous ones, a portrait shot or a failed test run keeps the previous ones, and the
# simulator the script booted is shut down, failed or not, while one already booted is left running.
#
#   Scripts/screenshots_test.sh
set -u

script=$(cd "$(dirname "$0")" && pwd)/screenshots.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

udid=FAKE-UDID
locale=en-US
# The device's name without spaces, as the script prefixes the shots with it.
slug=iPhone17ProMax
landscape_width=2868
landscape_height=1320
# What `simctl boot` returns for a simulator already booted.
already_booted=149

root=$work/root
mkdir -p "$root/Scripts" "$root/AppStore/metadata/$locale" "$work/bin"
cp "$script" "$root/Scripts/screenshots.sh"
output=$root/AppStore/screenshots

# The stubs log their calls to $work/log; FAKE_* set what they answer.
cat > "$work/bin/xcrun" <<'SH'
#!/bin/sh
echo "xcrun $*" >> "$FAKE_LOG"
case "$1 $2" in
"simctl list")
    echo "{\"devices\": {\"com.apple.CoreSimulator.SimRuntime.iOS-27-2\": [{\"name\": \"iPhone 17 Pro Max\", \"udid\": \"$FAKE_UDID\"}]}}" ;;
"simctl boot") exit "$FAKE_BOOT_STATUS" ;;
"xcresulttool export")
    # export attachments --path <result> --output-path <directory>
    python3 - "$7" "$FAKE_WIDTH" "$FAKE_HEIGHT" <<'PY'
import json, os, struct, sys
directory, width, height = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
attachments = []
for index, name in enumerate(["01-demo", "02-game"]):
    exported = f"{index}.png"
    with open(os.path.join(directory, exported), "wb") as png:
        png.write(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", width, height))
    attachments.append({"exportedFileName": exported, "suggestedHumanReadableName": f"{name}_0_UUID.png"})
json.dump([{"attachments": attachments}], open(os.path.join(directory, "manifest.json"), "w"))
PY
    ;;
esac
SH
cat > "$work/bin/xcodebuild" <<'SH'
#!/bin/sh
echo "xcodebuild" >> "$FAKE_LOG"
exit "$FAKE_XCODEBUILD_STATUS"
SH
chmod +x "$work/bin/xcrun" "$work/bin/xcodebuild"

fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

# run <boot status> <xcodebuild status> <width> <height>: runs the script over a previous shot,
# leaving its status in $status, its output in $work/out and the stubs' calls in $work/log.
run() {
    rm -rf "$output" "$work/log"
    mkdir -p "$output/$locale"
    echo previous > "$output/$locale/previous.png"
    status=0
    PATH="$work/bin:$PATH" FAKE_LOG="$work/log" FAKE_UDID="$udid" FAKE_BOOT_STATUS=$1 \
        FAKE_XCODEBUILD_STATUS=$2 FAKE_WIDTH=$3 FAKE_HEIGHT=$4 \
        "$root/Scripts/screenshots.sh" > "$work/out" 2>&1 || status=$?
    touch "$work/log"
}

expect_status() {
    [ "$status" -eq "$2" ] || fail "$1: exit $status, expected $2: $(cat "$work/out")"
}

expect_failure() {
    [ "$status" -ne 0 ] || fail "$1: exit 0"
}

expect_shutdown() {
    grep -qxF "xcrun simctl shutdown $udid" "$work/log" || fail "$1: the simulator was not shut down"
}

expect_previous_kept() {
    [ "$(ls "$output/$locale")" = previous.png ] || fail "$1: the shots are $(ls "$output/$locale")"
}

run 0 0 "$landscape_width" "$landscape_height"
expect_status "landscape shots" 0
[ "$(ls "$output/$locale" | tr '\n' ' ')" = "$slug-01-demo.png $slug-02-game.png " ] ||
    fail "landscape shots: the shots are $(ls "$output/$locale")"
expect_shutdown "landscape shots"

run 0 0 "$landscape_height" "$landscape_width"
expect_failure "a portrait shot"
grep -qxF "01-demo is $landscape_height x $landscape_width, not landscape" "$work/out" ||
    fail "a portrait shot: no refusal in: $(cat "$work/out")"
expect_previous_kept "a portrait shot"
expect_shutdown "a portrait shot"

run 0 1 "$landscape_width" "$landscape_height"
expect_failure "a failed test run"
expect_previous_kept "a failed test run"
expect_shutdown "a failed test run"

run "$already_booted" 0 "$landscape_width" "$landscape_height"
expect_status "a simulator already booted" 0
! grep -q "simctl shutdown" "$work/log" || fail "a simulator already booted: it was shut down"

[ "$failures" -eq 0 ] || exit 1
echo "screenshots.sh: all checks passed"
