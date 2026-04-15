#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# record-llm-hit.sh — Records a single LLM-detected PII hit to leaks.jsonl.
# Usage: record-llm-hit.sh <type> <redacted_value> [confidence]
# Called by the LLM prompt hook after Claude identifies PII.

set -euo pipefail

TYPE="${1:-unknown}"
VALUE="${2:-••••}"
CONFIDENCE="${3:-high}"

# Respect llm_scan_enabled userConfig (defense-in-depth)
LLM_ENABLED="${CLAUDE_PLUGIN_OPTION_LLM_SCAN_ENABLED:-true}"
if [[ "$LLM_ENABLED" == "false" || "$LLM_ENABLED" == "0" ]]; then
  exit 0
fi

SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
LEAKS_FILE="$SONOMOS_DIR/leaks.jsonl"
CONFIDENCE_THRESHOLD="${CLAUDE_PLUGIN_OPTION_CONFIDENCE_THRESHOLD:-medium}"

# Respect confidence threshold from userConfig
if [[ "$CONFIDENCE_THRESHOLD" == "high" && "$CONFIDENCE" != "high" ]]; then
  exit 0
fi

mkdir -p "$SONOMOS_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Use real session_id persisted by session-start.sh, fall back to "current"
SESSION_ID="current"
if [[ -f "$SONOMOS_DIR/.current_session_id" ]]; then
  SESSION_ID=$(cat "$SONOMOS_DIR/.current_session_id" 2>/dev/null || echo "current")
  [[ -z "$SESSION_ID" ]] && SESSION_ID="current"
fi

echo "{\"type\":\"${TYPE}\",\"value\":\"${VALUE}\",\"detector\":\"llm\",\"confidence\":\"${CONFIDENCE}\",\"timestamp\":\"${TIMESTAMP}\",\"session_id\":\"${SESSION_ID}\"}" >> "$LEAKS_FILE"

# Update HUD last-scan timestamp (epoch for fast relative-time display)
date +%s > "$SONOMOS_DIR/.last_scan" 2>/dev/null || true
