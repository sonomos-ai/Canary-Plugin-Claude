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

umask 0077
mkdir -p "$SONOMOS_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Use jq for safe JSON construction — prevents injection from
# values containing quotes, backslashes, or control characters.
jq -n -c \
  --arg type "$TYPE" \
  --arg value "$VALUE" \
  --arg confidence "$CONFIDENCE" \
  --arg timestamp "$TIMESTAMP" \
  '{type: $type, value: $value, detector: "llm", confidence: $confidence, timestamp: $timestamp, session_id: "current"}' >> "$LEAKS_FILE"
