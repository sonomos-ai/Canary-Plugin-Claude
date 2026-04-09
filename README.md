# Sonomos Claude Plugins

Privacy plugins for Claude Code by [Sonomos](https://sonomos.ai).

## Quick Install

```bash
# 1. Add the Sonomos marketplace
/plugin marketplace add sonomos/claude-plugins

# 2. Install the leak counter
/plugin install sonomos@sonomos
```

Or install directly without a marketplace:

```bash
/plugin install --dir https://github.com/sonomos/claude-plugins.git/leak-counter
```

## Plugins

### Leak Counter (`sonomos`)

A persistent PII exposure counter for Claude Code. Tracks every piece of sensitive data you share with Claude across all sessions.

**The number only goes up.**

- **16 regex detectors** with checksum validation (Luhn, MOD-97, ABA, Base58Check, EIP-55, MOD-11, SSA exclusion rules)
- **70+ semantic categories** via Claude self-scan — no API key, zero extra cost
- **Persistent terminal counter** — always visible in your statusline
- **Interactive HTML dashboard** — category breakdown, timeline, detection details
- **Session-start banner** — see your count every time you open Claude Code

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ◆ SONOMOS: 142 PII items exposed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  across 31 session(s) | 89 high-confidence
  regex: 97 | claude self-scan: 45
  email                  23
  phone_number           18
  name                   15
  ...
  /sonomos:leaked → dashboard | /sonomos:scan → deep scan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Commands

| Command | Description |
|---------|-------------|
| `/sonomos:leaked` | Open interactive dashboard |
| `/sonomos:leaked stats` | Text summary |
| `/sonomos:scan` | Claude scans its own conversation for semantic PII |
| `/sonomos:leaked reset` | Clear all data |

#### Persistent Counter

Add to `~/.claude/settings.json` to always see your PII count in the terminal:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.sonomos/statusline.sh"
  }
}
```

The counter is color-coded: green (0), yellow (<10), red (≥10).

#### How It Works

Regex detectors run silently on every task (via async Stop hook). For deeper analysis, `/sonomos:scan` instructs Claude to read its own conversation and identify PII — names, addresses, legal IDs, medical records, trade secrets, crypto credentials, and more. No external API call. Claude *is* the LLM.

All data is stored locally at `~/.sonomos/`. Values are redacted at detection time. Raw PII is never stored.

## About Sonomos

[Sonomos](https://sonomos.ai) detects and masks PII *before* it reaches AI. The browser extension works with Claude, ChatGPT, Gemini, Grok, and more.

The Leak Counter shows you what you've already exposed. Sonomos prevents exposure in the first place.

---

Copyright © 2026 Sonomos Inc. All rights reserved.
