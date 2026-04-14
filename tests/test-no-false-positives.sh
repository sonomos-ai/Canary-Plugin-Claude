#!/usr/bin/env bash
# test-no-false-positives.sh — Verify code samples and documentation don't trigger detectors.
# Usage: bash tests/test-no-false-positives.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTORS="$SCRIPT_DIR/canary/scripts/detectors.sh"

PASS=0
FAIL=0

assert_no_detect() {
  local label="$1"
  local input="$2"

  local output
  output=$(bash "$DETECTORS" "$input" 2>/dev/null || true)

  if [[ -z "$output" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label (no false positive)"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (false positive detected)"
    echo "        input: $input"
    echo "        output: $output"
  fi
}

echo "=== Code Variable Names ==="
assert_no_detect "Variable email" 'email_address = "placeholder"'
assert_no_detect "Function name" "def validate_credit_card(number):"
assert_no_detect "Config key" "AWS_ACCESS_KEY_ID="

echo ""
echo "=== Documentation Text ==="
assert_no_detect "SSN format description" "SSN format is XXX-XX-XXXX"
assert_no_detect "Example placeholder" "Enter your email: user@example.com"
assert_no_detect "IP documentation range" "10.0.0.1 is a private network address"
assert_no_detect "Localhost reference" "Connect to 127.0.0.1:8080"

echo ""
echo "=== Common Non-PII Patterns ==="
assert_no_detect "Version number" "v2.1.0"
assert_no_detect "Date string" "2026-04-14"
assert_no_detect "UUID" "550e8400-e29b-41d4-a716-446655440000"
assert_no_detect "Short number" "12345"
assert_no_detect "Noreply email" "noreply@service.com"

echo ""
echo "=== Private/Reserved IPs ==="
assert_no_detect "Private 192.168" "192.168.1.100"
assert_no_detect "Private 10.x" "10.0.0.50"
assert_no_detect "Loopback" "127.0.0.1"

echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
echo "==============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
