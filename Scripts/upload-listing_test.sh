#!/bin/sh
# Tests of Scripts/upload-listing.sh's refusals, in a copy of the repository's layout with bundle
# stubbed: a wrong argument count, a misspelled --submit, a missing key file, a key file not named as
# Apple names it, no MARKETING_VERSION and a locale without screenshots each stop it before fastlane.
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
version_line='    MARKETING_VERSION: "1.0.0"'

# Nothing may reach fastlane: the stub fails and logs the call.
cat > "$work/bin/bundle" <<'SH'
#!/bin/sh
echo "bundle $*" >> "$FAKE_LOG"
exit 1
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

[ "$failures" -eq 0 ] || exit 1
echo "upload-listing.sh: all checks passed"
