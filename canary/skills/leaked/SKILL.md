---
name: leaked
description: View your PII exposure dashboard — shows all sensitive data detected across Claude Code sessions with category breakdown, timeline, and details. Use when the user asks about PII leaks, privacy exposure, or wants to see their Sonomos dashboard.
user-invocable: true
disable-model-invocation: true
argument-hint: "[dashboard|stats|reset]"
allowed-tools: Bash(python3 *) Bash(cat *) Bash(jq *) Bash(wc *) Bash(echo *) Bash(rm *)
---

# Sonomos Leak Counter — Dashboard

The user wants to view their PII exposure data. Handle the subcommand from $ARGUMENTS:

## `dashboard` or no argument (default)

Generate and open the interactive HTML dashboard:

```bash
python3 "${CLAUDE_SKILL_DIR}/../../scripts/dashboard.py"
```

Then give a brief text summary:

```bash
SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
LEAKS="$SONOMOS_DIR/leaks.jsonl"
if [ -f "$LEAKS" ] && [ -s "$LEAKS" ]; then
  TOTAL=$(wc -l < "$LEAKS")
  echo "Total: $TOTAL PII items"
  echo "By type:"
  jq -r '.type' "$LEAKS" | sort | uniq -c | sort -rn | head -10
fi
```

## `stats`

Text-only summary without opening browser:

```bash
SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
LEAKS="$SONOMOS_DIR/leaks.jsonl"
if [ -f "$LEAKS" ] && [ -s "$LEAKS" ]; then
  TOTAL=$(wc -l < "$LEAKS")
  SESSIONS=$(jq -r '.session_id' "$LEAKS" | sort -u | wc -l)
  HIGH=$(jq -r 'select(.confidence=="high")' "$LEAKS" | wc -l)
  echo "Total: $TOTAL | Sessions: $SESSIONS | High confidence: $HIGH"
  echo ""
  jq -r '.type' "$LEAKS" | sort | uniq -c | sort -rn | head -15
  echo ""
  echo "By detector:"
  jq -r '.detector' "$LEAKS" | sort | uniq -c | sort -rn
else
  echo "No PII detected yet. Run /canary:scan for a deep scan."
fi
```

## `reset`

**Ask for confirmation first.** If confirmed:

```bash
SONOMOS_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.sonomos}"
rm -f "$SONOMOS_DIR/leaks.jsonl" "$SONOMOS_DIR/.cursor_"*
echo "Leak counter reset to 0."
```

## Detection Architecture

- **Regex (automatic):** 16 detectors with checksum validation run silently on every Stop hook. Catches structured PII: credit cards, SSNs, emails, IBANs, crypto addresses, AWS keys, VINs, phone numbers, etc.
- **Claude self-scan (automatic):** Claude scans each new user message for 70+ semantic categories on every Stop hook: names, addresses, legal IDs, medical records, trade secrets, API tokens, and more. Run `/canary:scan` for a deeper scan of the full conversation. No API key needed — Claude is the detector.

Never display raw PII values. Always show the redacted `value` field from the leaks file.

Copyright © 2026 Sonomos Inc. All rights reserved.
