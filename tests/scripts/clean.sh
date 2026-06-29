#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

rm -rf "$ROOT/tests/tmp"
# Remove legacy generated location if it exists from older test runs.
rm -rf "$ROOT/.test"

echo "Removed generated test state."
