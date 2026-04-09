#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# statusline.sh — Persistent PII counter for Claude Code status bar.
# Reads ~/.sonomos/leaks.jsonl and displays a compact counter.
# Configure in settings.json:
#   "statusLine": {"type":"command","command":"~/.sonomos/statusline.sh"}

set -euo pipefail

LEAKS_FILE="$HOME/.sonomos/leaks.jsonl"

# Read stdin (Claude Code session JSON) but we don't need it for the counter
cat > /dev/null

if [[ ! -f "$LEAKS_FILE" || ! -s "$LEAKS_FILE" ]]; then
  printf '◆ Sonomos: 0 PII'
  exit 0
fi

TOTAL=$(wc -l < "$LEAKS_FILE")
HIGH=$(grep -c '"confidence":"high"' "$LEAKS_FILE" 2>/dev/null || echo 0)

# Color code: green if 0, yellow if <10, red if >=10
if [[ "$TOTAL" -eq 0 ]]; then
  COLOR="\033[32m"  # green
elif [[ "$TOTAL" -lt 10 ]]; then
  COLOR="\033[33m"  # yellow
else
  COLOR="\033[31m"  # red
fi
RESET="\033[0m"

printf '%b◆ Sonomos: %d PII%b (%d high)' "$COLOR" "$TOTAL" "$RESET" "$HIGH"
