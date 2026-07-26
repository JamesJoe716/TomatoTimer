#!/usr/bin/env bash
#
# Runs SwiftLint over the project using .swiftlint.yml.
#
# Exit status: SwiftLint exits non-zero only for *error*-severity violations, so
# warnings (e.g. the two known `file_length` ones) are reported without failing
# the gate. Pass --strict to also fail on warnings.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "error: swiftlint not found. Install it with:" >&2
    echo "    brew install swiftlint" >&2
    exit 127
fi

echo "==> SwiftLint $(swiftlint version)"
swiftlint lint --quiet "$@"
echo "==> Lint passed (no error-severity violations)"
