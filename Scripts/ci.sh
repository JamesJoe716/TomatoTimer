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
XCB_FLAGS=(-project "$PROJECT")

# Hosted CI runners have no "Mac Development" certificate for the project's team,
# so a normal signed build fails with exit 65. Ad-hoc sign there instead: it needs
# no secrets, and unlike CODE_SIGNING_ALLOWED=NO it still produces a binary that
# will actually launch on Apple Silicon — which the test stage needs.
#
# Only applied when CI is set, so local builds keep their real signing identity.
if [[ -n "${CI:-}" ]]; then
    XCB_FLAGS+=(
        CODE_SIGN_IDENTITY="-"
        CODE_SIGN_STYLE=Manual
        DEVELOPMENT_TEAM=""
        PROVISIONING_PROFILE_SPECIFIER=""
        CODE_SIGNING_REQUIRED=NO
    )
fi

# xcodebuild writes into the repo by default; keep it out of the source tree so
# .gitignore stays simple and the widget/app builds share one cache.
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"

run_lint() {
    echo "==> [1/4] SwiftLint"
    Scripts/lint.sh
}

run_macos() {
    echo "==> [2/4] macOS Release build"
    xcodebuild "${XCB_FLAGS[@]}" -quiet \
        -scheme TomatoTimer \
        -configuration Release \
        -derivedDataPath "$DERIVED_DATA" \
        build
}

run_ios() {
    echo "==> [3/4] iOS Release build (app + widget extension)"
    xcodebuild "${XCB_FLAGS[@]}" -quiet \
        -scheme TomatoTimer-iOS \
        -configuration Release \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$DERIVED_DATA" \
        build
}

run_test() {
    echo "==> [4/4] Unit tests (macOS, Debug)"

    # Deliberately not -quiet: it suppresses the "Executed N tests" summary, which
    # makes a silently-skipped suite look identical to a passing one. Capture the
    # full log instead and report the count.
    local log="$DERIVED_DATA/test.log"
    mkdir -p "$DERIVED_DATA"

    local status=0
    xcodebuild "${XCB_FLAGS[@]}" \
        -scheme TomatoTimer \
        -configuration Debug \
        -derivedDataPath "$DERIVED_DATA" \
        test >"$log" 2>&1 || status=$?

    if (( status != 0 )); then
        echo "--- failures ---" >&2
        grep -E "error:|XCTAssert|failed \(" "$log" | head -40 >&2 || true
        echo "--- last 40 log lines ---" >&2
        tail -40 "$log" >&2
        return "$status"
    fi

    local summary
    summary=$(grep -E "^[[:space:]]*Executed [0-9]+ tests?," "$log" | tail -1 || true)

    # A green xcodebuild that ran nothing is a failure, not a pass.
    if [[ -z "$summary" ]]; then
        echo "error: no 'Executed N tests' summary found — the suite did not run" >&2
        tail -30 "$log" >&2
        return 1
    fi

    local count
    count=$(sed -E 's/^[[:space:]]*Executed ([0-9]+) tests?,.*/\1/' <<<"$summary")
    if (( count == 0 )); then
        echo "error: 0 tests executed" >&2
        return 1
    fi

    echo "    ${summary#"${summary%%[![:space:]]*}"}"
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
