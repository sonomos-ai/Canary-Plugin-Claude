#!/usr/bin/env bash
# test-checksums.sh — Verify checksum validation functions.
# Usage: bash tests/test-checksums.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTORS="$SCRIPT_DIR/canary/scripts/detectors.sh"

PASS=0
FAIL=0

# Source the validation functions from detectors.sh
source <(sed -n '/^luhn_valid()/,/^}/p' "$DETECTORS")
source <(sed -n '/^mod97_valid()/,/^}/p' "$DETECTORS")
source <(sed -n '/^aba_valid()/,/^}/p' "$DETECTORS")
source <(sed -n '/^base58check_valid()/,/^}/p' "$DETECTORS")
source <(sed -n '/^eth_valid()/,/^}/p' "$DETECTORS")
source <(sed -n '/^ssn_valid()/,/^}/p' "$DETECTORS")

assert_valid() {
  local label="$1"
  local func="$2"
  local input="$3"

  if $func "$input"; then
    PASS=$((PASS + 1))
    echo "  PASS: $label (valid)"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected valid, got invalid)"
  fi
}

assert_invalid() {
  local label="$1"
  local func="$2"
  local input="$3"

  if $func "$input"; then
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected invalid, got valid)"
  else
    PASS=$((PASS + 1))
    echo "  PASS: $label (invalid)"
  fi
}

echo "=== Luhn Checksum ==="
assert_valid "Visa card" "luhn_valid" "4532015112830366"
assert_valid "Mastercard" "luhn_valid" "5425233430109903"
assert_invalid "Random digits" "luhn_valid" "1234567890123456"

echo ""
echo "=== MOD-97 (IBAN) ==="
assert_valid "German IBAN" "mod97_valid" "DE89370400440532013000"
assert_valid "UK IBAN" "mod97_valid" "GB29NWBK60161331926819"
assert_invalid "Bad IBAN" "mod97_valid" "DE00000000000000000000"

echo ""
echo "=== ABA Routing ==="
assert_valid "Valid routing" "aba_valid" "021000021"
assert_valid "Valid routing 2" "aba_valid" "011401533"
assert_invalid "Bad routing" "aba_valid" "123456789"

echo ""
echo "=== Base58Check (Bitcoin) ==="
assert_valid "Legacy address" "base58check_valid" "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
assert_valid "Bech32 address" "base58check_valid" "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
assert_invalid "Bad address" "base58check_valid" "0xNotABitcoinAddress"

echo ""
echo "=== Ethereum Address ==="
assert_valid "Valid ETH" "eth_valid" "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD08"
assert_invalid "Too short" "eth_valid" "0x742d35Cc6634"
assert_invalid "Not hex" "eth_valid" "0xZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"

echo ""
echo "=== SSN SSA Rules ==="
assert_valid "Valid SSN" "ssn_valid" "078051120"
assert_invalid "Area 000" "ssn_valid" "000121234"
assert_invalid "Area 666" "ssn_valid" "666121234"
assert_invalid "Area 900+" "ssn_valid" "900121234"
assert_invalid "Group 00" "ssn_valid" "123001234"
assert_invalid "Serial 0000" "ssn_valid" "123450000"

echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
echo "==============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
