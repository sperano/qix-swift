# The checks, as CI runs them: lint and the package tests (brew install swiftlint swiftformat), and
# the app's build, unit, snapshot and UI tests on the simulator. The app targets need Xcode; they
# are named targets so CI and mactest run the same steps.
.PHONY: lint format coverage test-scripts check-project build unit snapshot record-snapshots ui

# Every recipe line runs with pipefail, so a test failure is not lost in the pipe to the formatter.
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# What xcodegen writes from project.yml, committed: the project and the app's Info.plist.
GENERATED = Qix.xcodeproj Qix/Resources/Info.plist

# The destinations, overridable from the environment or the command line (CI passes its iPhone by
# id). The snapshot images are recorded on SNAPSHOT_SIMULATOR; the snapshot tests skip on any other
# device (they check its name, not its iOS version).
SIMULATOR ?= platform=iOS Simulator,name=iPhone 17
SNAPSHOT_SIMULATOR ?= platform=iOS Simulator,name=iPhone 17,OS=27.2

# Fixed artifact paths: one result bundle per target, and the failed snapshots with their diffs.
# Everything is under build/, which git ignores. One DerivedData for every target, so a target run
# after another builds incrementally.
DERIVED_DATA = build/DerivedData
RESULTS = build/results
TEST_RUNNER_SNAPSHOT_ARTIFACTS ?= $(CURDIR)/build/snapshot-failures
export TEST_RUNNER_SNAPSHOT_ARTIFACTS

# xcodebuild's output goes through xcbeautify when it is installed; CI adds its GitHub renderer.
XCBEAUTIFY ?= $(if $(shell command -v xcbeautify),xcbeautify,cat)

XCODEBUILD = xcodebuild -project Qix.xcodeproj -scheme Qix -derivedDataPath $(DERIVED_DATA) \
	CODE_SIGNING_ALLOWED=NO
# $(call xcodebuild,<action>,<result bundle name>,<destination>,<options>): runs xcodebuild with a
# fresh result bundle at $(RESULTS)/<name>.xcresult (xcodebuild refuses to overwrite one).
xcodebuild = mkdir -p $(RESULTS) && rm -rf $(RESULTS)/$(2).xcresult && \
	$(XCODEBUILD) $(1) -destination '$(3)' $(4) -resultBundlePath $(RESULTS)/$(2).xcresult | $(XCBEAUTIFY)

# Checks only; fails on any finding. Both tools read their configuration from the repository root.
lint:
	swiftformat --lint .
	swiftlint lint --strict --quiet

# Rewrites the files SwiftFormat can fix, then reports what SwiftLint still finds.
format:
	swiftformat .
	swiftlint lint --strict --quiet

# Runs the package tests with coverage and fails below the minimum CI enforces (Scripts/coverage.sh).
coverage:
	cd QixKit && swift test --parallel --enable-code-coverage
	Scripts/coverage.sh "$$(cd QixKit && swift test --show-codecov-path)"

# Tests of the coverage gate itself (Scripts/coverage_test.sh), on fixture coverage exports.
test-scripts:
	Scripts/coverage_test.sh

# Fails when the committed Qix.xcodeproj or app Info.plist is not what xcodegen generates from
# project.yml.
check-project:
	xcodegen generate
	@changes=$$(git status --porcelain --untracked-files=all -- $(GENERATED)); \
	if [ -n "$$changes" ]; then \
		echo "Out of date; run xcodegen generate and commit:"; \
		echo "$$changes"; \
		exit 1; \
	fi

# Builds the app and every test target, without running a test.
build:
	$(call xcodebuild,build-for-testing,build,$(SIMULATOR))

unit:
	$(call xcodebuild,test,unit,$(SIMULATOR),-only-testing:QixTests)

snapshot:
	$(call xcodebuild,test,snapshot,$(SNAPSHOT_SIMULATOR),-only-testing:QixSnapshotTests)

# Rewrites the reference PNGs in place, then checks them with a normal snapshot run. Recording
# reports every snapshot test as failed ("Record mode is on"), so its status is ignored and the
# second run decides. Review the changed images before committing them.
record-snapshots:
	export TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all && \
	$(call xcodebuild,test,record-snapshots,$(SNAPSHOT_SIMULATOR),-only-testing:QixSnapshotTests) || true
	$(MAKE) snapshot

ui:
	$(call xcodebuild,test,ui,$(SIMULATOR),-only-testing:QixUITests)
