#!/bin/sh
# QixKit's line coverage as a Markdown table, on standard output and, on GitHub Actions, in the job
# summary; fails below `minimum`.
#
#   Scripts/coverage.sh <codecov.json>
#
# <codecov.json> is the llvm-cov export `swift test --enable-code-coverage` writes and
# `swift test --show-codecov-path` names. Only the package's own sources count, not its tests.
set -eu

# Percent of QixKit's lines its own tests must run.
minimum=90

[ $# -eq 1 ] || { echo "usage: $0 <codecov.json>" >&2; exit 2; }
summary=${GITHUB_STEP_SUMMARY:-/dev/null}
report=$(mktemp)
trap 'rm -f "$report"' EXIT
status=0

python3 - "$1" "$minimum" > "$report" <<'PY' || status=$?
import json, os, sys

SOURCES = "/Sources/QixKit/"
path, minimum = sys.argv[1], float(sys.argv[2])
files = [f for f in json.load(open(path))["data"][0]["files"] if SOURCES in f["filename"]]
covered = sum(f["summary"]["lines"]["covered"] for f in files)
count = sum(f["summary"]["lines"]["count"] for f in files)
total = 100 * covered / count if count else 0
print("### QixKit coverage\n\n| File | Lines | Coverage |\n| --- | ---: | ---: |")
for f in sorted(files, key=lambda f: f["filename"]):
    lines = f["summary"]["lines"]
    print(f"| {os.path.basename(f['filename'])} | {lines['covered']}/{lines['count']} | {lines['percent']:.1f}% |")
print(f"| **Total** | **{covered}/{count}** | **{total:.2f}%** |\n")
if total < minimum:
    print(f"**Below the {minimum:g}% minimum.**\n")
    sys.exit(1)
print(f"Minimum: {minimum:g}%.\n")
PY

# The report goes to a file first: piped straight into tee, the script's status would be lost.
tee -a "$summary" < "$report"
exit "$status"
