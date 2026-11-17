#!/bin/sh
# Tests of Scripts/upload-listing.sh, in a copy of the repository's layout with bundle stubbed: a
# wrong argument count, a misspelled --submit, a missing key file, a key file not named as Apple names
# it, no MARKETING_VERSION and a locale without screenshots each stop it before fastlane; otherwise
# deliver runs in AppStore with the version, --submit forwarded and the API key file, deleted on exit.
#
#   Scripts/upload-listing_test.sh
set -u

script=$(cd "$(dirname "$0")" && pwd)/upload-listing.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

usage_status=2
refusal_status=1
issuer_id=issuer
locale=en-US
root=$work/root
upload=$root/Scripts/upload-listing.sh
mkdir -p "$root/Scripts" "$root/AppStore/metadata/$locale" "$work/bin"
cp "$script" "$upload"
key=$work/AuthKey_KEYID.p8
misnamed_key=$work/key.p8
echo key > "$key"
echo key > "$misnamed_key"
version=1.0.0
version_line="    MARKETING_VERSION: \"$version\""
deliver="bundle exec fastlane deliver"

# The stub logs its calls and the directory deliver runs in, and keeps a copy of the API key file it
# is given, which the script deletes on exit.
cat > "$work/bin/bundle" <<'SH'
#!/bin/sh
echo "bundle $*" >> "$FAKE_LOG"
if [ "$1 $2 $3 $4" = "exec fastlane deliver --api_key_path" ]; then
    echo "cwd $PWD" >> "$FAKE_LOG"
    cp "$5" "$FAKE_KEY_COPY"
fi
SH
chmod +x "$work/bin/bundle"

fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

# expect <name> <status> <line> <args...>: runs the script, checks its status and an output line.
expect() {
    name=$1 status=$2 line=$3
    shift 3
    actual=0
    PATH="$work/bin:$PATH" FAKE_LOG="$work/log" "$upload" "$@" > "$work/out" 2>&1 || actual=$?
    [ "$actual" -eq "$status" ] || fail "$name: exit $actual, expected $status"
    grep -qxF -- "$line" "$work/out" || fail "$name: no line '$line' in: $(cat "$work/out")"
}

usage="usage: $upload <AuthKey_<KEYID>.p8> <issuer id> [--submit]"
echo "$version_line" > "$root/project.yml"
expect "no argument" "$usage_status" "$usage"
expect "one argument" "$usage_status" "$usage" "$key"
expect "four arguments" "$usage_status" "$usage" "$key" "$issuer_id" --submit --submit
expect "a misspelled --submit" "$usage_status" "$usage" "$key" "$issuer_id" --sumbit
expect "no key file" "$refusal_status" "No key file at $work/missing.p8." "$work/missing.p8" "$issuer_id"
expect "a key file not named AuthKey_<KEYID>.p8" "$refusal_status" \
    "The key file must be named AuthKey_<KEYID>.p8, as Apple names it." "$misnamed_key" "$issuer_id"
expect "no screenshots" "$refusal_status" "No screenshots for $locale: run Scripts/screenshots.sh first." \
    "$key" "$issuer_id" --submit

: > "$root/project.yml"
expect "no version" "$refusal_status" "No MARKETING_VERSION in project.yml." "$key" "$issuer_id"

[ ! -e "$work/log" ] || fail "fastlane was reached: $(cat "$work/log")"

# expect_upload <name> <submit_for_review> <args...>: runs the script with every locale's
# screenshots and checks what deliver received.
expect_upload() {
    name=$1 submit=$2
    shift 2
    rm -f "$work/log" "$work/api_key.json"
    actual=0
    PATH="$work/bin:$PATH" FAKE_LOG="$work/log" FAKE_KEY_COPY="$work/api_key.json" "$upload" "$@" \
        > "$work/out" 2>&1 || actual=$?
    [ "$actual" -eq 0 ] || fail "$name: exit $actual: $(cat "$work/out")"
    key_path=$(sed -n "s|^$deliver --api_key_path \([^ ]*\) .*|\1|p" "$work/log")
    expected="bundle install --quiet
$deliver --api_key_path $key_path --app_version $version --submit_for_review $submit
cwd $root/AppStore"
    { [ -n "$key_path" ] && [ "$(cat "$work/log")" = "$expected" ]; } ||
        fail "$name: the calls were $(cat "$work/log")"
    [ ! -e "$key_path" ] || fail "$name: the API key file $key_path was left behind"
    python3 - "$work/api_key.json" "$issuer_id" "$(cat "$key")" <<'PY' || fail "$name: wrong API key file"
import json, sys
path, issuer_id, key = sys.argv[1:]
expected = {"key_id": "KEYID", "issuer_id": issuer_id, "key": key + "\n", "in_house": False}
with open(path) as file:
    actual = json.load(file)
if actual != expected:
    sys.exit(f"{actual} != {expected}")
PY
}

echo "$version_line" > "$root/project.yml"
mkdir -p "$root/AppStore/screenshots/$locale"
echo shot > "$root/AppStore/screenshots/$locale/shot.png"
expect_upload "an upload" false "$key" "$issuer_id"
expect_upload "an upload with --submit" true "$key" "$issuer_id" --submit

[ "$failures" -eq 0 ] || exit 1
echo "upload-listing.sh: all checks passed"
