#!/usr/bin/env bash
#
# The full local gate: lint, build both platforms in Release, run the test suite.
# This is the same sequence .github/workflows/ci.yml runs.
#
# Usage:
#   Scripts/ci.sh            # everything
#   Scripts/ci.sh lint       # a single stage: lint | macos | ios | test

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PROJECT="TomatoTimer.xcodeproj"
XCB_FLAGS=(-project "$PROJECT" -quiet)

# xcodebuild writes into the repo by default; keep it out of the source tree so
# .gitignore stays simple and the widget/app builds share one cache.
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"

run_lint() {
    echo "==> [1/4] SwiftLint"
    Scripts/lint.sh
}

run_macos() {
    echo "==> [2/4] macOS Release build"
    xcodebuild "${XCB_FLAGS[@]}" \
        -scheme TomatoTimer \
        -configuration Release \
        -derivedDataPath "$DERIVED_DATA" \
        build
}

run_ios() {
    echo "==> [3/4] iOS Release build (app + widget extension)"
    xcodebuild "${XCB_FLAGS[@]}" \
        -scheme TomatoTimer-iOS \
        -configuration Release \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$DERIVED_DATA" \
        build
}

run_test() {
    echo "==> [4/4] Unit tests (macOS, Debug)"
    xcodebuild "${XCB_FLAGS[@]}" \
        -scheme TomatoTimer \
        -configuration Debug \
        -derivedDataPath "$DERIVED_DATA" \
        test
}

case "${1:-all}" in
    lint)  run_lint ;;
    macos) run_macos ;;
    ios)   run_ios ;;
    test)  run_test ;;
    all)
        run_lint
        run_macos
        run_ios
        run_test
        echo
        echo "==> All checks passed."
        ;;
    *)
        echo "error: unknown stage '$1' (expected: lint | macos | ios | test | all)" >&2
        exit 2
        ;;
esac
