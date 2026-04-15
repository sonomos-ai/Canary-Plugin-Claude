#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# statusline.sh — Rich HUD for Claude Code status bar.
# Displays a persistent, auto-updating PII dashboard below the input line.
# Reads ~/.sonomos/leaks.jsonl on every render cycle for real-time counts.
#
# Configure in settings.json:
#   "statusLine": {"type":"command","command":"bash ~/.sonomos/statusline.sh"}
#
# HUD elements:
#   - PII counter (color-coded severity: green/yellow/red)
#   - High-confidence count
#   - Session-specific delta
#   - Type diversity (distinct PII categories)
#   - Last detection relative time
#   - Detection method breakdown (regex / llm / file)
#   - Top 3 exposure categories
#   - Dashboard file link (when generated)
#   - Skill shortcuts (/canary:leaked, /canary:scan)

set -euo pipefail

SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
LEAKS_FILE="$SONOMOS_DIR/leaks.jsonl"
DASHBOARD_FILE="$SONOMOS_DIR/dashboard.html"

# ── ANSI escape codes ($'...' for real escape bytes) ───────────
DIM=$'\033[2m'
RST=$'\033[0m'
B=$'\033[1m'
RED=$'\033[31m'
GRN=$'\033[32m'
YLW=$'\033[33m'
CYN=$'\033[36m'
MAG=$'\033[35m'
BRED=$'\033[1;31m'
BGRN=$'\033[1;32m'
BYLW=$'\033[1;33m'
BCYN=$'\033[1;36m'

# ── Read stdin (session JSON from Claude Code) ─────────────────
INPUT=$(cat 2>/dev/null || true)
SESSION_ID=""
if command -v jq &>/dev/null && [[ -n "$INPUT" ]]; then
  SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
fi

# ── Separator ──────────────────────────────────────────────────
BAR="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
FULL_BAR="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Zero-detection state ───────────────────────────────────────
if [[ ! -f "$LEAKS_FILE" || ! -s "$LEAKS_FILE" ]]; then
  printf '%s━━━ %s🐤 CANARY%s %s%s%s\n' "$DIM" "$BGRN" "$RST" "$DIM" "$BAR" "$RST"
  printf ' %s0 PII%s │ monitoring active %s✓%s │ %s/canary:leaked%s · %s/canary:scan%s\n' \
    "$BGRN" "$RST" "$GRN" "$RST" "$DIM" "$RST" "$DIM" "$RST"
  printf '%s%s%s' "$DIM" "$FULL_BAR" "$RST"
  exit 0
fi

# ── Gather stats (grep-first for speed) ────────────────────────
# Note: grep -c outputs "0" even on no-match (exit 1), so use || true
TOTAL=$(wc -l < "$LEAKS_FILE" | tr -d ' ')
HIGH=$(grep -c '"confidence":"high"' "$LEAKS_FILE" 2>/dev/null || true)
REGEX_CT=$(grep -c '"detector":"regex"' "$LEAKS_FILE" 2>/dev/null || true)
LLM_CT=$(grep -c '"detector":"llm"' "$LEAKS_FILE" 2>/dev/null || true)
FILE_CT=$(grep -c '"detector":"file"' "$LEAKS_FILE" 2>/dev/null || true)

# Ensure numeric (fallback to 0 if empty)
HIGH=${HIGH:-0}
REGEX_CT=${REGEX_CT:-0}
LLM_CT=${LLM_CT:-0}
FILE_CT=${FILE_CT:-0}

# Session-specific count (if session_id available)
SESS_CT=0
if [[ -n "$SESSION_ID" ]]; then
  SESS_CT=$(grep -c "\"session_id\":\"${SESSION_ID}\"" "$LEAKS_FILE" 2>/dev/null || true)
  SESS_CT=${SESS_CT:-0}
fi

# Top 3 exposure categories
TOP_TYPES=$(grep -o '"type":"[^"]*"' "$LEAKS_FILE" 2>/dev/null | \
  sed 's/"type":"//;s/"//' | sort | uniq -c | sort -rn | head -3 | \
  awk '{printf "%s(%d) ", $2, $1}' | sed 's/ $//' || true)

# Number of distinct PII types
NUM_TYPES=$(grep -o '"type":"[^"]*"' "$LEAKS_FILE" 2>/dev/null | sort -u | wc -l | tr -d ' ')
NUM_TYPES=${NUM_TYPES:-0}

# Last detection — relative time
LAST_TS=$(tail -1 "$LEAKS_FILE" | grep -o '"timestamp":"[^"]*"' 2>/dev/null | \
  sed 's/"timestamp":"//;s/"//' || true)
LAST_AGO=""
if [[ -n "$LAST_TS" ]]; then
  # GNU date (-d) first, macOS date (-j) fallback
  LE=$(date -d "$LAST_TS" +%s 2>/dev/null || \
       date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_TS" +%s 2>/dev/null || echo 0)
  NOW=$(date +%s)
  if [[ "$LE" -gt 0 ]]; then
    D=$((NOW - LE))
    if   [[ $D -lt 60 ]];    then LAST_AGO="${D}s ago"
    elif [[ $D -lt 3600 ]];  then LAST_AGO="$((D/60))m ago"
    elif [[ $D -lt 86400 ]]; then LAST_AGO="$((D/3600))h ago"
    else                          LAST_AGO="$((D/86400))d ago"
    fi
  fi
fi

# ── Severity color (based on total count) ──────────────────────
if   [[ $TOTAL -eq 0 ]]; then SC="$BGRN"; HC="$GRN"
elif [[ $TOTAL -lt 10 ]]; then SC="$BYLW"; HC="$YLW"
else                           SC="$BRED"; HC="$RED"
fi

# ── Dashboard indicator ────────────────────────────────────────
DASH_SEG=""
if [[ -f "$DASHBOARD_FILE" ]]; then
  DASH_SEG="${DIM}📊 ~/.sonomos/dashboard.html${RST}"
else
  DASH_SEG="${DIM}📊 /canary:leaked → generate${RST}"
fi

# ── Session segment ────────────────────────────────────────────
SESS_SEG=""
if [[ $SESS_CT -gt 0 ]]; then
  SESS_SEG=" │ ${MAG}▲${SESS_CT} session${RST}"
fi

# ── Detector breakdown ─────────────────────────────────────────
DET_PARTS=""
[[ $REGEX_CT -gt 0 ]] && DET_PARTS="regex:${REGEX_CT}"
if [[ $LLM_CT -gt 0 ]]; then
  [[ -n "$DET_PARTS" ]] && DET_PARTS="${DET_PARTS} · "
  DET_PARTS="${DET_PARTS}llm:${LLM_CT}"
fi
if [[ $FILE_CT -gt 0 ]]; then
  [[ -n "$DET_PARTS" ]] && DET_PARTS="${DET_PARTS} · "
  DET_PARTS="${DET_PARTS}file:${FILE_CT}"
fi

# ── Last-hit segment ──────────────────────────────────────────
LAST_SEG=""
[[ -n "$LAST_AGO" ]] && LAST_SEG=" │ ${DIM}last: ${LAST_AGO}${RST}"

# ══════════════════════════════════════════════════════════════
#  RENDER HUD
# ══════════════════════════════════════════════════════════════

# Line 1: Header bar with branding
printf '%s━━━ %s🐤 CANARY%s %s%s%s\n' "$DIM" "${B}${HC}" "$RST" "$DIM" "$BAR" "$RST"

# Line 2: Core counter — total, high, session delta, types, last hit
printf ' %s%d PII%s (%d high)%s │ %s%s types%s%s\n' \
  "$SC" "$TOTAL" "$RST" \
  "$HIGH" \
  "$SESS_SEG" \
  "$CYN" "$NUM_TYPES" "$RST" \
  "$LAST_SEG"

# Line 3: Detection breakdown + top categories
if [[ -n "$DET_PARTS" && -n "$TOP_TYPES" ]]; then
  printf ' %s%s%s │ %stop: %s%s\n' \
    "$DIM" "$DET_PARTS" "$RST" \
    "$DIM" "$TOP_TYPES" "$RST"
elif [[ -n "$DET_PARTS" ]]; then
  printf ' %s%s%s\n' "$DIM" "$DET_PARTS" "$RST"
fi

# Line 4: Dashboard link + skill shortcuts
printf ' %s │ %s/canary:leaked%s · %s/canary:scan%s\n' \
  "$DASH_SEG" \
  "$BCYN" "$RST" \
  "$BCYN" "$RST"

# Line 5: Footer bar
printf '%s%s%s' "$DIM" "$FULL_BAR" "$RST"
