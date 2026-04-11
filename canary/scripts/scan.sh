#!/usr/bin/env bash
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# scan.sh — Regex PII scan on Stop hook.
# Reads the transcript, extracts user messages since last scan,
# runs regex detectors, and appends hits to ~/.sonomos/leaks.jsonl.
# LLM scanning is handled separately by the /canary:scan skill,
# which instructs Claude to scan its own conversation — zero API cost.

set -euo pipefail

SONOMOS_DIR="$HOME/.sonomos"
LEAKS_FILE="$SONOMOS_DIR/leaks.jsonl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$SONOMOS_DIR"

# Read hook input from stdin
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Determine where we left off (line-based cursor per transcript)
TRANSCRIPT_HASH=$(echo "$TRANSCRIPT_PATH" | md5sum | cut -d' ' -f1)
CURSOR_KEY="$SONOMOS_DIR/.cursor_${TRANSCRIPT_HASH}"
LAST_LINE=0
if [[ -f "$CURSOR_KEY" ]]; then
  LAST_LINE=$(cat "$CURSOR_KEY")
fi

TOTAL_LINES=$(wc -l < "$TRANSCRIPT_PATH")
if [[ "$TOTAL_LINES" -le "$LAST_LINE" ]]; then
  exit 0
fi

# Extract new user message content from JSONL transcript
NEW_TEXT=$(tail -n +"$((LAST_LINE + 1))" "$TRANSCRIPT_PATH" | \
  jq -r 'select(.type == "human") | .message.content // empty' 2>/dev/null | \
  head -c 50000)

if [[ -z "$NEW_TEXT" ]]; then
  NEW_TEXT=$(tail -n +"$((LAST_LINE + 1))" "$TRANSCRIPT_PATH" | \
    jq -r 'select(.role == "user") |
      if (.content | type) == "string" then .content
      elif (.content | type) == "array" then [.content[] | select(.type == "text") | .text] | join("\n")
      else empty end' 2>/dev/null | \
    head -c 50000)
fi

echo "$TOTAL_LINES" > "$CURSOR_KEY"

if [[ -z "$NEW_TEXT" ]]; then
  exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

HITS=$(bash "$SCRIPT_DIR/detectors.sh" "$NEW_TEXT" 2>/dev/null || true)

if [[ -n "$HITS" ]]; then
  echo "$HITS" | while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    echo "$hit" | jq -c \
      --arg ts "$TIMESTAMP" \
      --arg sid "$SESSION_ID" \
      '. + {timestamp: $ts, session_id: $sid}' >> "$LEAKS_FILE"
  done
fi

exit 0
