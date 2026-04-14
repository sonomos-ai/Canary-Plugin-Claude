#!/usr/bin/env bash
# test-redact.sh — Verify redaction function preserves first/last 2 chars.
# Usage: bash tests/test-redact.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTORS="$SCRIPT_DIR/canary/scripts/detectors.sh"

PASS=0
FAIL=0

# Extract the redact function from detectors.sh and test it directly
source <(sed -n '/^redact()/,/^}/p' "$DETECTORS")

assert_redact() {
  local label="$1"
  local input="$2"
  local expected="$3"

  local result
  result=$(redact "$input")

  if [[ "$result" == "$expected" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label → $result"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label"
    echo "        expected: $expected"
    echo "        got:      $result"
  fi
}

echo "=== Redaction Tests ==="
assert_redact "Standard value" "4532015112830366" "45••••••••••••66"
assert_redact "Short value" "12345" "••••"
assert_redact "Email-length" "john@example.com" "jo••••••••••••om"
assert_redact "Six chars" "123456" "12••56"
assert_redact "SSN digits" "078051120" "07•••••20"

echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
echo "==============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
