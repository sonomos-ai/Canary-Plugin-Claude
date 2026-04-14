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

SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
LEAKS_FILE="$SONOMOS_DIR/leaks.jsonl"
CONFIDENCE_THRESHOLD="${CLAUDE_PLUGIN_OPTION_CONFIDENCE_THRESHOLD:-medium}"

# Respect confidence threshold from userConfig
if [[ "$CONFIDENCE_THRESHOLD" == "high" && "$CONFIDENCE" != "high" ]]; then
  exit 0
fi

mkdir -p "$SONOMOS_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "{\"type\":\"${TYPE}\",\"value\":\"${VALUE}\",\"detector\":\"llm\",\"confidence\":\"${CONFIDENCE}\",\"timestamp\":\"${TIMESTAMP}\",\"session_id\":\"current\"}" >> "$LEAKS_FILE"
