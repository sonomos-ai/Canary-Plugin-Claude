#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# session-start.sh — Prints PII counter summary on every session start.
# Output goes to stdout → injected as context visible to Claude and user.
# Also installs the HUD statusline script to ~/.sonomos/ for persistence.

set -euo pipefail
umask 0077

# Drain stdin (Claude Code pipes hook JSON data that we don't need)
cat > /dev/null &

SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
LEAKS_FILE="$SONOMOS_DIR/leaks.jsonl"

mkdir -p "$SONOMOS_DIR"

# Always keep statusline script up to date
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/statusline.sh" ]]; then
  cp "$SCRIPT_DIR/statusline.sh" "$SONOMOS_DIR/statusline.sh"
  chmod +x "$SONOMOS_DIR/statusline.sh"
fi

# First run: show welcome
if [[ ! -f "$SONOMOS_DIR/.initialized" ]]; then
  touch "$SONOMOS_DIR/.initialized"

  cat << WELCOME
━━━ 🐤 CANARY — Installed ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sonomos is now monitoring your conversations for PII exposure.

  Detectors:
  ✓ Regex:  16 detectors with checksum validation
            (credit cards, SSNs, emails, crypto addresses, ...)
  ✓ LLM:   70+ semantic categories scanned automatically
            (names, addresses, legal IDs, medical records, ...)
            No API key needed. Zero extra cost.

  Commands:
  /canary:leaked           Open interactive dashboard
  /canary:leaked stats     Quick text summary
  /canary:scan             Deep scan of full conversation
  /canary:leaked reset     Clear all data

  HUD (always-visible status bar):
  Add to ~/.claude/settings.json:
  "statusLine": {"type":"command","command":"bash ${SONOMOS_DIR}/statusline.sh"}

  The HUD shows your live PII counter, detection breakdown,
  top exposure categories, dashboard link, and more — all
  updating in real time below the input line.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WELCOME
  exit 0
fi

# No leaks yet
if [[ ! -f "$LEAKS_FILE" || ! -s "$LEAKS_FILE" ]]; then
  echo "━━━ 🐤 CANARY ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  0 PII items detected. Clean so far."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi

# ── Aggregate stats ────────────────────────────────────────────
TOTAL=$(wc -l < "$LEAKS_FILE" | tr -d ' ')
SESSIONS=$(jq -r '.session_id' "$LEAKS_FILE" 2>/dev/null | sort -u | wc -l | tr -d ' ')
HIGH_CONF=$(jq -r 'select(.confidence == "high") | .type' "$LEAKS_FILE" 2>/dev/null | wc -l | tr -d ' ')
REGEX_COUNT=$(jq -r 'select(.detector == "regex") | .type' "$LEAKS_FILE" 2>/dev/null | wc -l | tr -d ' ')
LLM_COUNT=$(jq -r 'select(.detector == "llm") | .type' "$LEAKS_FILE" 2>/dev/null | wc -l | tr -d ' ')

BREAKDOWN=$(jq -r '.type' "$LEAKS_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -8 | \
  awk '{printf "    %-22s %d\n", $2, $1}')

NUM_TYPES=$(jq -r '.type' "$LEAKS_FILE" 2>/dev/null | sort -u | wc -l | tr -d ' ')

# Dashboard status
DASH_STATUS=""
if [[ -f "$SONOMOS_DIR/dashboard.html" ]]; then
  DASH_STATUS="📊 dashboard: ~/.sonomos/dashboard.html"
else
  DASH_STATUS="📊 /canary:leaked → generate dashboard"
fi

echo "━━━ 🐤 CANARY ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${TOTAL} PII items exposed"
echo "  across ${SESSIONS} session(s) │ ${HIGH_CONF} high-confidence │ ${NUM_TYPES} types"
echo "  regex: ${REGEX_COUNT} │ llm: ${LLM_COUNT}"
echo ""
echo "  Top categories:"
echo "${BREAKDOWN}"
echo ""
echo "  ${DASH_STATUS}"
echo "  /canary:leaked → dashboard │ /canary:scan → deep audit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
