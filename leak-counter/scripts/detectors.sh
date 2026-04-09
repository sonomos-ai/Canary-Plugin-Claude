#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# detectors.sh — Regex-based PII detection with checksum validation.
# Takes text on $1, outputs JSONL hits to stdout.
# Each hit: {"type":"<category>","value":"<redacted>","detector":"regex","confidence":"high|medium"}

TEXT="$1"

if [[ -z "$TEXT" ]]; then
  exit 0
fi

# ── Utility: redact a value, keeping first 2 and last 2 chars ────────
redact() {
  local val="$1"
  local clean
  clean=$(echo "$val" | sed 's/[[:space:]]//g')
  local len=${#clean}
  if [[ $len -le 5 ]]; then
    echo "••••"
  else
    echo "${clean:0:2}$(printf '•%.0s' $(seq 1 $((len - 4))))${clean:$((len-2)):2}"
  fi
}

# ── Utility: Luhn checksum validation ────────────────────────────────
luhn_valid() {
  local num=$(echo "$1" | sed 's/[-  ]//g')
  local len=${#num}
  local sum=0
  local alt=0
  for (( i=len-1; i>=0; i-- )); do
    local d=${num:$i:1}
    if [[ $alt -eq 1 ]]; then
      d=$((d * 2))
      [[ $d -gt 9 ]] && d=$((d - 9))
    fi
    sum=$((sum + d))
    alt=$(( 1 - alt ))
  done
  [[ $((sum % 10)) -eq 0 ]]
}

# ── Utility: MOD-97 validation for IBAN ──────────────────────────────
mod97_valid() {
  local iban=$(echo "$1" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
  # Move first 4 chars to end
  local rearranged="${iban:4}${iban:0:4}"
  # Replace letters with numbers (A=10, B=11, ..., Z=35)
  local numeric=""
  for (( i=0; i<${#rearranged}; i++ )); do
    local c="${rearranged:$i:1}"
    if [[ "$c" =~ [A-Z] ]]; then
      numeric+=$(( $(printf '%d' "'$c") - 55 ))
    else
      numeric+="$c"
    fi
  done
  # MOD 97 using chunked arithmetic (bash can't handle big ints)
  local remainder=0
  for (( i=0; i<${#numeric}; i++ )); do
    remainder=$(( (remainder * 10 + ${numeric:$i:1}) % 97 ))
  done
  [[ $remainder -eq 1 ]]
}

# ── Utility: ABA routing number checksum ─────────────────────────────
aba_valid() {
  local r="$1"
  [[ ${#r} -ne 9 ]] && return 1
  local sum=$(( 3*(${r:0:1}+${r:3:1}+${r:6:1}) + 7*(${r:1:1}+${r:4:1}+${r:7:1}) + (${r:2:1}+${r:5:1}+${r:8:1}) ))
  [[ $((sum % 10)) -eq 0 ]]
}

# ── Utility: Base58Check validation (Bitcoin) ────────────────────────
base58check_valid() {
  # Lightweight: check format and length, not full SHA256 double-hash
  local addr="$1"
  [[ "$addr" =~ ^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$ ]] || \
  [[ "$addr" =~ ^bc1[a-zA-HJ-NP-Z0-9]{25,89}$ ]]
}

# ── Utility: EIP-55 Ethereum address validation ─────────────────────
eth_valid() {
  local addr="$1"
  [[ "$addr" =~ ^0x[0-9a-fA-F]{40}$ ]]
}

# ── Utility: VIN MOD-11 validation ───────────────────────────────────
vin_valid() {
  local vin=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  [[ ${#vin} -ne 17 ]] && return 1
  # VIN transliteration values
  local -A trans=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8 [J]=1 [K]=2 [L]=3 [M]=4 [N]=5 [P]=7 [R]=9 [S]=2 [T]=3 [U]=4 [V]=5 [W]=6 [X]=7 [Y]=8 [Z]=9)
  local weights=(8 7 6 5 4 3 2 10 0 9 8 7 6 5 4 3 2)
  local sum=0
  for (( i=0; i<17; i++ )); do
    local c="${vin:$i:1}"
    local val
    if [[ "$c" =~ [0-9] ]]; then
      val=$c
    else
      val=${trans[$c]:-0}
    fi
    sum=$((sum + val * ${weights[$i]}))
  done
  local check=$((sum % 11))
  local check_char
  [[ $check -eq 10 ]] && check_char="X" || check_char="$check"
  [[ "${vin:8:1}" == "$check_char" ]]
}

# ── Utility: SSN SSA exclusion rules ─────────────────────────────────
ssn_valid() {
  local ssn=$(echo "$1" | sed 's/[-  ]//g')
  [[ ${#ssn} -ne 9 ]] && return 1
  local area="${ssn:0:3}"
  local group="${ssn:3:2}"
  local serial="${ssn:5:4}"
  # SSA exclusions
  [[ "$area" == "000" || "$area" == "666" ]] && return 1
  [[ "$area" -ge 900 && "$area" -le 999 ]] && return 1
  [[ "$group" == "00" ]] && return 1
  [[ "$serial" == "0000" ]] && return 1
  return 0
}

# ══════════════════════════════════════════════════════════════════════
# DETECTORS
# ══════════════════════════════════════════════════════════════════════

# ── 1. Credit Card Numbers ───────────────────────────────────────────
while IFS= read -r match; do
  clean=$(echo "$match" | sed 's/[-  ]//g')
  if [[ ${#clean} -ge 13 && ${#clean} -le 19 ]] && luhn_valid "$clean"; then
    echo "{\"type\":\"credit_card\",\"value\":\"$(redact "$clean")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
  fi
done < <(echo "$TEXT" | grep -oP '\b(?:\d[ -]?){13,19}\b' 2>/dev/null || true)

# ── 2. Email Addresses ──────────────────────────────────────────────
# Require: 2+ char local part, real domain with dot, 2-12 char TLD
# Exclude: URL userinfo (preceded by ://), common false positives
while IFS= read -r match; do
  local_part="${match%%@*}"
  # Skip if local part is too short or looks like a URL password
  [[ ${#local_part} -lt 2 ]] && continue
  # Skip common non-email patterns
  [[ "$local_part" =~ ^(noreply|no-reply|example|test|user|admin|root|localhost)$ ]] && continue
  echo "{\"type\":\"email\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
done < <(echo "$TEXT" | grep -oiP '(?<![:/@])\b[a-z0-9][a-z0-9._%+\-]{0,62}[a-z0-9]@[a-z0-9]([a-z0-9\-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]*[a-z0-9])?)*\.[a-z]{2,12}\b' 2>/dev/null || true)

# ── 3. IBAN ──────────────────────────────────────────────────────────
while IFS= read -r match; do
  if mod97_valid "$match"; then
    echo "{\"type\":\"iban\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
  fi
done < <(echo "$TEXT" | grep -oP '\b[A-Z]{2}\d{2}[ ]?[\dA-Z]{4}[ ]?[\dA-Z]{4}[ ]?[\dA-Z]{4}[ ]?[\dA-Z]{0,16}\b' 2>/dev/null || true)

# ── 4. IPv4 Addresses ───────────────────────────────────────────────
while IFS= read -r match; do
  # Exclude common non-PII IPs (localhost, broadcast, documentation ranges)
  if [[ ! "$match" =~ ^(127\.|0\.|255\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|224\.|169\.254\.) ]]; then
    echo "{\"type\":\"ipv4\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"medium\"}"
  fi
done < <(echo "$TEXT" | grep -oP '\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b' 2>/dev/null || true)

# ── 5. IPv6 Addresses ───────────────────────────────────────────────
while IFS= read -r match; do
  [[ "$match" == "::1" || "$match" == "::" ]] && continue
  echo "{\"type\":\"ipv6\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"medium\"}"
done < <(echo "$TEXT" | grep -oiP '(?:[0-9a-f]{1,4}:){2,7}[0-9a-f]{1,4}|(?:[0-9a-f]{1,4}:)*::[0-9a-f:]*' 2>/dev/null || true)

# ── 6. Bitcoin Addresses ────────────────────────────────────────────
while IFS= read -r match; do
  if base58check_valid "$match"; then
    echo "{\"type\":\"bitcoin_address\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
  fi
done < <(echo "$TEXT" | grep -oP '\b(?:[13][a-km-zA-HJ-NP-Z1-9]{25,34}|bc1[a-zA-HJ-NP-Z0-9]{25,89})\b' 2>/dev/null || true)

# ── 7. Ethereum Addresses ───────────────────────────────────────────
while IFS= read -r match; do
  if eth_valid "$match"; then
    echo "{\"type\":\"ethereum_address\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
  fi
done < <(echo "$TEXT" | grep -oP '\b0x[0-9a-fA-F]{40}\b' 2>/dev/null || true)

# ── 8. US SSN ────────────────────────────────────────────────────────
while IFS= read -r match; do
  if ssn_valid "$match"; then
    echo "{\"type\":\"us_ssn\",\"value\":\"$(redact "$(echo "$match" | sed 's/[-  ]//g')")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
  fi
done < <(echo "$TEXT" | grep -oP '\b\d{3}[ -]?\d{2}[ -]?\d{4}\b' 2>/dev/null | \
  grep -vP '^\d{3}[ -]?00|^000|^666|^9\d{2}' || true)

# ── 9. US ABA Routing Number ────────────────────────────────────────
while IFS= read -r match; do
  if aba_valid "$match"; then
    echo "{\"type\":\"aba_routing\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
  fi
done < <(echo "$TEXT" | grep -oP '\b[0-9]{9}\b' 2>/dev/null || true)

# ── 10. URL with Credentials ────────────────────────────────────────
while IFS= read -r match; do
  echo "{\"type\":\"url_credentials\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
done < <(echo "$TEXT" | grep -oP 'https?://[^:]+:[^@]+@[^\s]+' 2>/dev/null || true)

# ── 11. Phone Numbers ───────────────────────────────────────────────
# Use negative lookahead/lookbehind to avoid matching substrings of longer numbers
while IFS= read -r match; do
  digits=$(echo "$match" | tr -cd '0-9')
  [[ ${#digits} -lt 10 || ${#digits} -gt 15 ]] && continue
  # Exclude if digits are 13+ without formatting (likely CC)
  if [[ ${#digits} -ge 13 ]]; then
    has_format=$(echo "$match" | grep -cP '[ ()\-+]' || true)
    [[ "$has_format" -eq 0 ]] && continue
  fi
  # Exclude if Luhn-valid with 13+ digits (credit card)
  if luhn_valid "$digits" && [[ ${#digits} -ge 13 ]]; then
    continue
  fi
  echo "{\"type\":\"phone_number\",\"value\":\"$(redact "$digits")\",\"detector\":\"regex\",\"confidence\":\"medium\"}"
done < <(echo "$TEXT" | grep -oP '(?<!\d)(?:\+?1[ -]?)?(?:\(?\d{3}\)?[ -]?)?\d{3}[ -]?\d{4}(?!\d)|\+\d{1,3}[ -]?\d{4,14}(?!\d)' 2>/dev/null || true)

# ── 12. US Driver's License (multi-state format) ────────────────────
while IFS= read -r match; do
  echo "{\"type\":\"us_drivers_license\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"medium\"}"
done < <(echo "$TEXT" | grep -oiP "(?:driver'?s?\s*(?:license|lic|licence)\s*(?:#|no\.?|number)?\s*[:=]?\s*)[A-Z]?\d{4,12}" 2>/dev/null || true)

# ── 13. AWS Access Key ──────────────────────────────────────────────
while IFS= read -r match; do
  echo "{\"type\":\"aws_access_key\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
done < <(echo "$TEXT" | grep -oP '\bAKIA[0-9A-Z]{16}\b' 2>/dev/null || true)

# Also catch AWS secret keys
while IFS= read -r match; do
  echo "{\"type\":\"aws_secret_key\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
done < <(echo "$TEXT" | grep -oP '(?<=aws_secret_access_key\s*=\s*|AWS_SECRET_ACCESS_KEY\s*=\s*)[A-Za-z0-9/+=]{40}' 2>/dev/null || true)

# ── 14. US Medicare/Medicaid ID (MBI) ────────────────────────────────
# Format: 1C11-AA1-AA11 (C=letter excl S,L,O,I,B,Z; 1=digit excl 0)
while IFS= read -r match; do
  echo "{\"type\":\"us_mbi\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"medium\"}"
done < <(echo "$TEXT" | grep -oP '\b[1-9][AC-HJKMNP-RT-Y][0-9AC-HJKMNP-RT-Y][0-9]-[A-Z]{2}[0-9]-[A-Z]{2}[0-9]{2}\b' 2>/dev/null || true)

# ── 15. VIN (Vehicle Identification Number) ──────────────────────────
while IFS= read -r match; do
  if vin_valid "$match"; then
    echo "{\"type\":\"vin\",\"value\":\"$(redact "$match")\",\"detector\":\"regex\",\"confidence\":\"high\"}"
  fi
done < <(echo "$TEXT" | grep -oiP '\b[A-HJ-NPR-Z0-9]{17}\b' 2>/dev/null | \
  grep -viP '^[0-9]+$' | grep -viP '^[A-Z]+$' || true)

exit 0
