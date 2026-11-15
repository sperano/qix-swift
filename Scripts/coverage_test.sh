#!/bin/sh
# Tests of Scripts/coverage.sh on llvm-cov exports written here: the gate passes at the minimum,
# fails below it and without any QixKit source, totals the lines of several sources, ignores the
# package's tests, appends its report to the job summary, and refuses a missing argument.
#
#   Scripts/coverage_test.sh
set -u

script=$(dirname "$0")/coverage.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

# The source and test files of an export, as `swift test` names them.
source_file=/work/QixKit/Sources/QixKit/BoardSize.swift
other_source_file=/work/QixKit/Sources/QixKit/Rng.swift
test_file=/work/QixKit/Tests/QixKitTests/BoardSizeTests.swift
# Lines in each fixture file: the minimum (90 %) is 9 of them.
lines=10
at_minimum=9
below_minimum=8
# Two sources whose lines total 105/110 (95.45 %) though their mean percentage is 75 %: only a sum
# of both files' covered lines and of their counts gives that total.
large_lines=100
small_lines=10
small_covered=5

# export_json <path> <file>:<covered>[:<count>] ...: writes an llvm-cov export holding those files,
# each of `lines` lines unless <count> says otherwise.
export_json() {
    path=$1
    shift
    python3 - "$path" "$lines" "$@" <<'PY'
import json, sys

path, default_count = sys.argv[1], int(sys.argv[2])
files = []
for spec in sys.argv[3:]:
    name, covered, *rest = spec.split(":")
    covered, count = int(covered), int(rest[0]) if rest else default_count
    lines = {"covered": covered, "count": count, "percent": 100 * covered / count}
    files.append({"filename": name, "summary": {"lines": lines}})
json.dump({"data": [{"files": files}]}, open(path, "w"))
PY
}

fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

# expect <name> <status> <line> <args...>: runs the script, checks its status and an output line.
expect() {
    name=$1 status=$2 line=$3
    shift 3
    actual=0
    GITHUB_STEP_SUMMARY= "$script" "$@" > "$work/out" 2>&1 || actual=$?
    [ "$actual" -eq "$status" ] || fail "$name: exit $actual, expected $status"
    grep -qxF -- "$line" "$work/out" || fail "$name: no line '$line' in: $(cat "$work/out")"
}

export_json "$work/minimum.json" "$source_file:$at_minimum"
expect "at the minimum" 0 "Minimum: 90%." "$work/minimum.json"
expect "at the minimum, total" 0 "| **Total** | **9/10** | **90.00%** |" "$work/minimum.json"

export_json "$work/below.json" "$source_file:$below_minimum"
expect "below the minimum" 1 "**Below the 90% minimum.**" "$work/below.json"

export_json "$work/sources.json" "$source_file:$large_lines:$large_lines" "$other_source_file:$small_covered:$small_lines"
expect "several sources" 0 "| **Total** | **105/110** | **95.45%** |" "$work/sources.json"

export_json "$work/tests.json" "$source_file:$at_minimum" "$test_file:0"
expect "tests do not count" 0 "| **Total** | **9/10** | **90.00%** |" "$work/tests.json"

export_json "$work/empty.json" "$test_file:$lines"
expect "no QixKit source" 1 "**Below the 90% minimum.**" "$work/empty.json"

expect "no argument" 2 "usage: $script <codecov.json>"

echo "previous step" > "$work/summary"
GITHUB_STEP_SUMMARY="$work/summary" "$script" "$work/minimum.json" > /dev/null
[ "$(head -n 1 "$work/summary")" = "previous step" ] || fail "job summary: earlier content lost"
grep -qxF "Minimum: 90%." "$work/summary" || fail "job summary: no report in $(cat "$work/summary")"

[ "$failures" -eq 0 ] || exit 1
echo "coverage.sh: all checks passed"
