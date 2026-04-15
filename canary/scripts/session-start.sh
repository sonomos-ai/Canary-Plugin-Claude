#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# session-start.sh — Prints PII counter summary on every session start.
# Also stores session baseline for the HUD's "+N this session" counter,
# persists the session_id for accurate LLM-hit tracking, and copies
# the statusline script to ~/.sonomos for persistent access.

set -euo pipefail

SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
LEAKS_FILE="$SONOMOS_DIR/leaks.jsonl"

mkdir -p "$SONOMOS_DIR"

# ── Parse stdin for session context ──────────────────────────
# Claude Code pipes hook JSON; we extract session_id for tracking.
INPUT=$(cat 2>/dev/null || true)
SESSION_ID=""
if [[ -n "$INPUT" ]]; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
fi

# Persist session_id so record-llm-hit.sh can use the real ID
if [[ -n "$SESSION_ID" ]]; then
  echo "$SESSION_ID" > "$SONOMOS_DIR/.current_session_id"
fi

# ── Store HUD session baseline ───────────────────────────────
# Current PII total at session start. The statusline computes
# "+N session" as (current_total - baseline).
if [[ -f "$LEAKS_FILE" && -s "$LEAKS_FILE" ]]; then
  wc -l < "$LEAKS_FILE" | tr -d ' ' > "$SONOMOS_DIR/.hud_session_baseline"
else
  echo 0 > "$SONOMOS_DIR/.hud_session_baseline"
fi

# ── First run: install statusline and show welcome ───────────
if [[ ! -f "$SONOMOS_DIR/.initialized" ]]; then
  touch "$SONOMOS_DIR/.initialized"

  # Copy statusline script to persistent location
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "$SCRIPT_DIR/statusline.sh" ]]; then
    cp "$SCRIPT_DIR/statusline.sh" "$SONOMOS_DIR/statusline.sh"
    chmod +x "$SONOMOS_DIR/statusline.sh"
  fi

  cat << WELCOME
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🐤 SONOMOS CANARY — Installed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sonomos is now monitoring your conversations for PII exposure.

  ✓ Regex:  16 detectors run silently after every task
            (credit cards, SSNs, emails, crypto addresses, ...)
  ✓ LLM:   70+ semantic PII categories scanned automatically
            after every task (names, addresses, legal IDs,
            medical records, trade secrets, ...)
            No API key needed. Zero extra cost.

Commands:
  /canary:leaked           Open interactive dashboard
  /canary:leaked stats     Quick text summary
  /canary:scan             Deep scan of full conversation history
  /canary:leaked reset     Clear all data

HUD (status bar):
  A persistent 2-line HUD shows live PII metrics below your prompt.
  Add to ~/.claude/settings.json to enable:
  "statusLine": {"type":"command","command":"bash ${SONOMOS_DIR}/statusline.sh"}

  The HUD shows: PII count + severity bar, detection breakdown,
  protection status, dashboard link, scan recency, and git branch.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WELCOME
  exit 0
fi

# ── Subsequent sessions: print counter summary ───────────────

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
  🐤 Canary: ${TOTAL} PII items exposed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  across ${SESSIONS} session(s) | ${HIGH_CONF} high-confidence
  regex: ${REGEX_COUNT} | claude self-scan: ${LLM_COUNT}
${BREAKDOWN}
  /canary:leaked → dashboard | /canary:scan → full conversation scan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
