#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# statusline.sh — Canary HUD for the Claude Code status bar.
# Renders a rich 2-line heads-up display with live PII metrics,
# severity visualization, protection status, dashboard link,
# scan recency, git branch, and session-specific tracking.
#
# Inspired by github.com/jarrodwatts/claude-hud's multi-line approach
# but focused entirely on Canary's privacy-monitoring domain.
#
# Configure in settings.json:
#   "statusLine": {"type":"command","command":"bash ~/.sonomos/statusline.sh"}

set -euo pipefail

SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
LEAKS_FILE="$SONOMOS_DIR/leaks.jsonl"
CONFIG_FILE="$SONOMOS_DIR/config.json"
DASHBOARD="$SONOMOS_DIR/dashboard.html"
BASELINE_FILE="$SONOMOS_DIR/.hud_session_baseline"
LAST_SCAN_FILE="$SONOMOS_DIR/.last_scan"
SESSION_ID_FILE="$SONOMOS_DIR/.current_session_id"

# ── ANSI Colors ──────────────────────────────────────────────
RST="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
WHITE="\033[97m"

# ── Parse stdin from Claude Code ─────────────────────────────
# Claude Code pipes a JSON payload with session info.
# We extract what's useful and discard the rest.
INPUT=$(cat 2>/dev/null || true)
CWD=""
SESSION_ID=""
if [[ -n "$INPUT" ]]; then
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
fi

# ── PII Metrics (grep-based for speed) ──────────────────────
TOTAL=0
HIGH=0
REGEX_N=0
LLM_N=0

if [[ -f "$LEAKS_FILE" && -s "$LEAKS_FILE" ]]; then
  TOTAL=$(wc -l < "$LEAKS_FILE" | tr -d ' ')
  HIGH=$(grep -c '"confidence":"high"' "$LEAKS_FILE" 2>/dev/null || echo 0)
  REGEX_N=$(grep -c '"detector":"regex"' "$LEAKS_FILE" 2>/dev/null || echo 0)
  LLM_N=$(grep -c '"detector":"llm"' "$LEAKS_FILE" 2>/dev/null || echo 0)
fi

# ── Session delta ────────────────────────────────────────────
# Compares current total against the baseline stored at session start
# to show how many PII items were detected during THIS session.
SESSION_DELTA=0
if [[ -f "$BASELINE_FILE" ]]; then
  BASELINE=$(cat "$BASELINE_FILE" 2>/dev/null || echo 0)
  SESSION_DELTA=$(( TOTAL - BASELINE ))
  [[ $SESSION_DELTA -lt 0 ]] && SESSION_DELTA=0
fi

# ── Severity color ───────────────────────────────────────────
if [[ "$TOTAL" -eq 0 ]]; then
  SEV="$GREEN"
elif [[ "$TOTAL" -lt 10 ]]; then
  SEV="$YELLOW"
else
  SEV="$RED"
fi

# ── Severity bar (10 segments, 1 PII = 1 block, cap at 10) ──
BAR_LEN=10
FILLED=$(( TOTAL > BAR_LEN ? BAR_LEN : TOTAL ))
EMPTY=$(( BAR_LEN - FILLED ))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="█"; done
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done

# ── Protection status ───────────────────────────────────────
LLM_ON="true"
if [[ -f "$CONFIG_FILE" ]]; then
  LLM_ON=$(jq -r 'if .llm_scan_enabled == false then "false" else "true" end' "$CONFIG_FILE" 2>/dev/null || echo true)
fi
if [[ "$LLM_ON" == "true" ]]; then
  SHIELD="🛡"
  PROT="regex+llm"
else
  SHIELD="⚠️"
  PROT="regex only"
fi

# ── Last scan relative time ─────────────────────────────────
# .last_scan stores a Unix epoch written by the scan scripts.
SCAN_AGO=""
if [[ -f "$LAST_SCAN_FILE" ]]; then
  SCAN_EPOCH=$(cat "$LAST_SCAN_FILE" 2>/dev/null || echo 0)
  NOW_EPOCH=$(date +%s 2>/dev/null || echo 0)
  if [[ "$SCAN_EPOCH" -gt 0 && "$NOW_EPOCH" -gt 0 ]]; then
    DIFF=$(( NOW_EPOCH - SCAN_EPOCH ))
    if [[ $DIFF -lt 5 ]]; then
      SCAN_AGO="just now"
    elif [[ $DIFF -lt 60 ]]; then
      SCAN_AGO="${DIFF}s ago"
    elif [[ $DIFF -lt 3600 ]]; then
      SCAN_AGO="$(( DIFF / 60 ))m ago"
    elif [[ $DIFF -lt 86400 ]]; then
      SCAN_AGO="$(( DIFF / 3600 ))h ago"
    else
      SCAN_AGO="$(( DIFF / 86400 ))d ago"
    fi
  fi
fi

# ── Git branch ──────────────────────────────────────────────
BRANCH=$(git -C "${CWD:-.}" symbolic-ref --short HEAD 2>/dev/null || true)

# ════════════════════════════════════════════════════════════
#  RENDER HUD
# ════════════════════════════════════════════════════════════

# ── Line 1: Primary metrics ─────────────────────────────────
# Branding │ PII count + severity bar │ high count │ detector breakdown │ session delta
printf '%b%b🐤 Canary%b │ ' "$SEV" "$BOLD" "$RST"

if [[ "$TOTAL" -eq 0 ]]; then
  printf '%b0 PII%b %b%s%b │ %b%bClean ✓%b' \
    "$GREEN" "$RST" "$DIM" "$BAR" "$RST" "$GREEN" "$BOLD" "$RST"
else
  printf '%b%d PII%b %b%s%b │ %b%d high%b │ regex:%d · llm:%d' \
    "$SEV" "$TOTAL" "$RST" \
    "$SEV" "$BAR" "$RST" \
    "$SEV" "$HIGH" "$RST" \
    "$REGEX_N" "$LLM_N"
  if [[ $SESSION_DELTA -gt 0 ]]; then
    printf ' │ %b+%d session%b' "$SEV" "$SESSION_DELTA" "$RST"
  fi
fi
printf '\n'

# ── Line 2: Secondary info ──────────────────────────────────
# Protection │ dashboard link │ scan recency │ git branch │ quick command
printf '%b%s %s%b' "$DIM" "$SHIELD" "$PROT" "$RST"

if [[ -f "$DASHBOARD" ]]; then
  printf ' │ %b📊 dashboard.html%b' "$CYAN" "$RST"
fi

if [[ -n "$SCAN_AGO" ]]; then
  printf ' │ scanned %s' "$SCAN_AGO"
fi

if [[ -n "$BRANCH" ]]; then
  printf ' │ %bgit:(%s)%b' "$DIM" "$BRANCH" "$RST"
fi

printf ' │ %b/canary:leaked%b' "$DIM" "$RST"
