#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# scan-file.sh — Lightweight PII scan triggered by PostToolUse on Write/Edit.
# Reads the hook JSON from stdin, extracts the file path, and runs
# fast-path detectors (credit cards, SSNs, API keys) on the file content.

set -euo pipefail

SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
LEAKS_FILE="$SONOMOS_DIR/leaks.jsonl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIDENCE_THRESHOLD="${CLAUDE_PLUGIN_OPTION_CONFIDENCE_THRESHOLD:-medium}"

mkdir -p "$SONOMOS_DIR"

# Read hook input from stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Skip binary files and large files (>100KB)
FILE_SIZE=$(wc -c < "$FILE_PATH" 2>/dev/null || echo 0)
if [[ "$FILE_SIZE" -gt 102400 ]]; then
  exit 0
fi

# Read file content
FILE_TEXT=$(cat "$FILE_PATH" 2>/dev/null || true)
if [[ -z "$FILE_TEXT" ]]; then
  exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Run full detectors on the file content
HITS=$(bash "$SCRIPT_DIR/detectors.sh" "$FILE_TEXT" 2>/dev/null || true)

if [[ -n "$HITS" ]]; then
  echo "$HITS" | while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    # Respect confidence threshold
    if [[ "$CONFIDENCE_THRESHOLD" == "high" ]]; then
      HIT_CONF=$(echo "$hit" | jq -r '.confidence // "medium"')
      [[ "$HIT_CONF" != "high" ]] && continue
    fi
    echo "$hit" | jq -c \
      --arg ts "$TIMESTAMP" \
      --arg sid "$SESSION_ID" \
      --arg src "file:$FILE_PATH" \
      '. + {timestamp: $ts, session_id: $sid, source: $src}' >> "$LEAKS_FILE"
  done
fi

# Update HUD last-scan timestamp (epoch for fast relative-time display)
date +%s > "$SONOMOS_DIR/.last_scan" 2>/dev/null || true

exit 0
