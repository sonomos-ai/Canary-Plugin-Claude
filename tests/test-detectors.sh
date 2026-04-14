#!/usr/bin/env bash
# test-detectors.sh — Verify regex PII detectors produce correct output.
# Usage: bash tests/test-detectors.sh
# Exit code 0 = all passed, 1 = failures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTORS="$SCRIPT_DIR/canary/scripts/detectors.sh"

PASS=0
FAIL=0

assert_detects() {
  local label="$1"
  local input="$2"
  local expected_type="$3"

  local output
  output=$(bash "$DETECTORS" "$input" 2>/dev/null || true)

  if echo "$output" | grep -q "\"type\":\"$expected_type\""; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected type '$expected_type')"
    echo "        input: $input"
    echo "        output: $output"
  fi
}

assert_no_detect() {
  local label="$1"
  local input="$2"

  local output
  output=$(bash "$DETECTORS" "$input" 2>/dev/null || true)

  if [[ -z "$output" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label (no detection)"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected no detection but got output)"
    echo "        output: $output"
  fi
}

echo "=== Credit Card Detectors ==="
assert_detects "Visa (Luhn valid)" "4532015112830366" "credit_card"
assert_detects "Visa with dashes" "4532-0151-1283-0366" "credit_card"
assert_detects "Mastercard" "5425233430109903" "credit_card"

echo ""
echo "=== Email Detectors ==="
assert_detects "Standard email" "john.doe@company.org" "email"
assert_detects "Email with subdomain" "sarah@mail.example.com" "email"
assert_no_detect "Excluded: test@" "test@example.com"
assert_no_detect "Excluded: noreply@" "noreply@example.com"

echo ""
echo "=== SSN Detectors ==="
assert_detects "SSN with dashes" "078-05-1120" "us_ssn"
assert_detects "SSN without dashes" "219099999" "us_ssn"
assert_no_detect "SSN excluded: 000 area" "000-12-3456"
assert_no_detect "SSN excluded: 666 area" "666-12-3456"

echo ""
echo "=== AWS Key Detectors ==="
assert_detects "AWS access key" "AKIAIOSFODNN7EXAMPLE" "aws_access_key"

echo ""
echo "=== Bitcoin Address Detectors ==="
assert_detects "Bitcoin legacy" "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa" "bitcoin_address"

echo ""
echo "=== Ethereum Address Detectors ==="
assert_detects "Ethereum address" "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD08" "ethereum_address"

echo ""
echo "=== Phone Number Detectors ==="
assert_detects "US phone" "+1 (555) 123-4567" "phone_number"
assert_detects "International phone" "+14155551234" "phone_number"

echo ""
echo "=== URL Credentials Detectors ==="
assert_detects "URL with password" "https://admin:secret123@db.example.com" "url_credentials"

echo ""
echo "=== IPv4 Detectors ==="
assert_detects "Public IPv4" "203.0.113.42" "ipv4"
assert_no_detect "Private IPv4 (192.168)" "192.168.1.1"
assert_no_detect "Localhost" "127.0.0.1"

echo ""
echo "=== IBAN Detectors ==="
assert_detects "German IBAN" "DE89370400440532013000" "iban"

echo ""
echo "=== Medicare MBI Detectors ==="
assert_detects "Medicare MBI" "1EG4-TE5-MK72" "us_mbi"

echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
echo "==============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
