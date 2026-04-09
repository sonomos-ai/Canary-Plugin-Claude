#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# session-start.sh — Prints PII counter summary on every session start.
# Output goes to stdout → injected as context visible to Claude and user.

set -euo pipefail

SONOMOS_DIR="$HOME/.sonomos"
LEAKS_FILE="$SONOMOS_DIR/leaks.jsonl"

mkdir -p "$SONOMOS_DIR"

# First run: install statusline script and show welcome
if [[ ! -f "$SONOMOS_DIR/.initialized" ]]; then
  touch "$SONOMOS_DIR/.initialized"

  # Copy statusline script to persistent location
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "$SCRIPT_DIR/statusline.sh" ]]; then
    cp "$SCRIPT_DIR/statusline.sh" "$SONOMOS_DIR/statusline.sh"
    chmod +x "$SONOMOS_DIR/statusline.sh"
  fi

  cat << 'WELCOME'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ◆ SONOMOS LEAK COUNTER — Installed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sonomos is now monitoring your conversations for PII exposure.

  ✓ Regex:  16 detectors run silently after every task
            (credit cards, SSNs, emails, crypto addresses, ...)
  ✓ LLM:   /sonomos:scan — Claude scans its own conversation
            for 70+ semantic PII categories (names, addresses,
            legal IDs, medical records, trade secrets, ...)
            No API key needed. Zero extra cost.

Commands:
  /sonomos:leaked           Open interactive dashboard
  /sonomos:leaked stats     Quick text summary
  /sonomos:scan             Deep LLM scan of current conversation
  /sonomos:leaked reset     Clear all data

Persistent counter:
  Add to ~/.claude/settings.json to always see your PII count:
  "statusLine": {"type":"command","command":"bash ~/.sonomos/statusline.sh"}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WELCOME
  exit 0
fi

# No leaks yet
if [[ ! -f "$LEAKS_FILE" || ! -s "$LEAKS_FILE" ]]; then
  echo "◆ Sonomos: 0 PII items detected. Clean so far."
  exit 0
fi

# Aggregate stats
TOTAL=$(wc -l < "$LEAKS_FILE")
SESSIONS=$(jq -r '.session_id' "$LEAKS_FILE" 2>/dev/null | sort -u | wc -l)

BREAKDOWN=$(jq -r '.type' "$LEAKS_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -8 | \
  awk '{printf "  %-22s %d\n", $2, $1}')

HIGH_CONF=$(jq -r 'select(.confidence == "high") | .type' "$LEAKS_FILE" 2>/dev/null | wc -l)
REGEX_COUNT=$(jq -r 'select(.detector == "regex") | .type' "$LEAKS_FILE" 2>/dev/null | wc -l)
LLM_COUNT=$(jq -r 'select(.detector == "llm") | .type' "$LEAKS_FILE" 2>/dev/null | wc -l)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ◆ SONOMOS: ${TOTAL} PII items exposed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  across ${SESSIONS} session(s) | ${HIGH_CONF} high-confidence
  regex: ${REGEX_COUNT} | claude self-scan: ${LLM_COUNT}
${BREAKDOWN}
  /sonomos:leaked → dashboard | /sonomos:scan → deep scan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
