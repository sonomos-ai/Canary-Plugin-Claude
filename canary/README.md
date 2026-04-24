# 🐤 Sonomos Canary

**A persistent PII exposure counter for Claude Code.**

Every time you interact with Claude, you may be sharing sensitive data — emails, credit card numbers, SSNs, API keys, addresses, medical records, legal identifiers, and more. Canary tracks every piece of PII you expose across all sessions, maintaining a running count that persists forever.

The number only goes up.

## Install

```bash
/plugin marketplace add sonomos-ai/Canary-Plugin
/plugin install canary@sonomos
```

## How It Works

```
You type a message → Claude processes it → Stop hook fires (async)
                                               │
                                     ┌─────────┴─────────┐
                                Regex Detectors      LLM Self-Scan
                              (16 patterns, checksums)  (70+ categories)
                                     └─────────┬─────────┘
                                               │
                                    Append to ~/.sonomos/leaks.jsonl
                                               │
                           Next session start → counter displayed

Deep scan:  /canary:scan  →  Claude scans full conversation history
                              (automatic scan covers latest message only)
```

### Detection

**Regex (automatic, every task, ~10ms):**
16 detectors with checksum validation — Luhn (credit cards), MOD-97 (IBAN), ABA routing checksums, Base58Check (Bitcoin), EIP-55 (Ethereum), MOD-11 (VIN), SSA exclusion rules (SSN).

**Claude Self-Scan (automatic, zero cost):**
Claude scans each new user message for 70+ semantic categories — names, addresses, legal IDs, medical records, trade secrets, crypto seed phrases, organizational data, and more. Run `/canary:scan` for a deep scan of the full conversation history.

## Commands

| Command | Description |
|---------|-------------|
| `/canary:leaked` | Open interactive HTML dashboard |
| `/canary:leaked stats` | Print text summary |
| `/canary:scan` | Deep scan of full conversation history |
| `/canary:leaked reset` | Clear all data (with confirmation) |

## Persistent Counter

Add to `~/.claude/settings.json` to always see your PII count:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.sonomos/statusline.sh"
  }
}
```

Color-coded: green (0), yellow (<10), red (≥10).

## Data Storage

All data is local at `~/.sonomos/`:

| File | Purpose |
|------|---------|
| `leaks.jsonl` | Detected PII items (redacted values only) |
| `dashboard.html` | Generated dashboard |
| `statusline.sh` | Counter script (copied on first run) |
| `.cursor_*` | Scan cursors per transcript |

**Privacy:** Values are redacted at detection time using a "first 2 + last 2" rule — the middle characters are replaced with bullet points. For example, `4532015112830366` becomes `45••••••••••••66`. Values of 5 characters or fewer are fully masked as `••••`. Raw PII is never stored. All files are created with `0700`/`0600` permissions (owner-only access).

## Plugin Structure

```
canary/
├── .claude-plugin/plugin.json       # Plugin manifest
├── hooks/hooks.json                 # Stop, PostToolUse, SessionStart hooks
├── scripts/
│   ├── detectors.sh                 # 16 regex detectors with checksum validation
│   ├── scan.sh                      # Stop hook: regex scan on new messages
│   ├── scan-file.sh                 # PostToolUse hook: scan written/edited files
│   ├── session-start.sh             # SessionStart hook: welcome + summary
│   ├── statusline.sh                # Rich HUD for status bar
│   ├── record-llm-hit.sh           # Record LLM-detected hits safely (jq)
│   └── dashboard.py                 # Interactive HTML dashboard generator
├── skills/
│   ├── leaked/SKILL.md              # /canary:leaked — dashboard, stats, reset
│   └── scan/SKILL.md               # /canary:scan — deep conversation scan
├── agents/
│   └── pii-audit.md                 # Cross-session PII audit agent
├── bin/
│   ├── canary-stats                 # CLI: quick PII summary
│   └── canary-export                # CLI: export to CSV/JSON
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## About Sonomos

[Sonomos](https://sonomos.ai) detects and masks PII *before* it reaches AI. Canary shows you what you've already exposed. Sonomos prevents it.

---

Copyright © 2026 Sonomos Inc. All rights reserved.
