# Sonomos Leak Counter

**A persistent PII exposure counter for Claude Code.**

Every time you interact with Claude, you may be sharing sensitive data — emails, credit card numbers, SSNs, API keys, addresses, medical records, legal identifiers, and more. Sonomos Leak Counter tracks every piece of PII you expose across all sessions, maintaining a running count that persists forever.

The number only goes up.

## How It Works

```
You type a message → Claude processes it → Stop hook fires (async)
                                               │
                                          Regex Detectors
                                          (16 patterns,
                                           checksum validation)
                                               │
                                    Append to ~/.sonomos/leaks.jsonl
                                               │
                           Next session start → counter displayed

On-demand:  /sonomos:scan  →  Claude reads its own conversation
                               and scans for 70+ semantic PII
                               categories. No API key. Zero cost.
```

### Detection Modes

**Regex (automatic, every task, ~10ms):**
16 pattern-based detectors with checksum validation — Luhn (credit cards), MOD-97 (IBAN), ABA routing checksums, Base58Check (Bitcoin), EIP-55 (Ethereum), MOD-11 (VIN), SSA exclusion rules (SSN). Runs silently after every Stop hook.

**Claude Self-Scan (on-demand, zero cost):**
Run `/sonomos:scan` and Claude reviews its own conversation for 70+ semantic categories. No external API call — Claude *is* the LLM. Detects names, addresses, legal IDs, medical records, trade secrets, crypto seed phrases, organizational data, and more.

## Installation

```bash
# As a plugin (recommended)
/plugin install github.com/sonomos/leak-counter

# Or locally for development
claude --plugin-dir ./sonomos-leak-counter
```

## Usage

### Automatic (passive)
On every session start:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ◆ SONOMOS: 142 PII items exposed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  across 31 session(s) | 89 high-confidence
  regex: 97 | claude self-scan: 45
  email                  23
  phone_number           18
  name                   15
  credit_card            12
  ...
  /sonomos:leaked → dashboard | /sonomos:scan → deep scan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Commands

| Command | Description |
|---------|-------------|
| `/sonomos:leaked` | Open interactive HTML dashboard |
| `/sonomos:leaked stats` | Print text summary |
| `/sonomos:scan` | Claude scans its own conversation for semantic PII |
| `/sonomos:leaked reset` | Clear all data (with confirmation) |

## Data Storage

All data is local at `~/.sonomos/`:

| File | Purpose |
|------|---------|
| `leaks.jsonl` | Every detected PII item (redacted values only) |
| `dashboard.html` | Generated dashboard (regenerated on view) |
| `.cursor_*` | Scan position cursors per transcript |
| `.initialized` | First-run flag |

**Privacy:** Values are redacted at detection time (e.g., `jo••••om`). Raw PII is never stored.

## Plugin Structure

```
sonomos-leak-counter/
├── .claude-plugin/plugin.json     # Manifest
├── hooks/hooks.json               # Stop + SessionStart hooks
├── scripts/
│   ├── scan.sh                    # Regex scan orchestrator
│   ├── detectors.sh               # 16 regex detectors + checksums
│   ├── session-start.sh           # Counter banner
│   └── dashboard.py               # HTML report generator
├── skills/
│   ├── leaked/SKILL.md            # /sonomos:leaked command
│   └── scan/SKILL.md              # /sonomos:scan (Claude self-scan)
├── README.md
└── LICENSE
```

## About Sonomos

This plugin is a companion to [Sonomos](https://sonomos.ai) — a privacy-tech product that detects and masks PII *before* it reaches AI. The browser extension works with Claude, ChatGPT, Gemini, Grok, and more.

The Leak Counter shows you what you've already exposed. Sonomos prevents exposure in the first place.

---

Copyright © 2026 Sonomos Inc. All rights reserved.
