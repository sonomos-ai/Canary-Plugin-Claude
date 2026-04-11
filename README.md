# Sonomos Claude Plugins

Privacy plugins for Claude Code by [Sonomos](https://sonomos.ai).

## Quick Install

```bash
# 1. Add the Sonomos marketplace
/plugin marketplace add sonomos/claude-plugins

# 2. Install Canary
/plugin install canary@sonomos
```

## Plugins

### 🐤 Canary

A persistent PII exposure counter for Claude Code. Tracks every piece of sensitive data you share with Claude across all sessions. The number only goes up.

- **16 regex detectors** with checksum validation (Luhn, MOD-97, ABA, Base58Check, EIP-55, MOD-11, SSA exclusion rules)
- **70+ semantic categories** via Claude self-scan — no API key, zero extra cost
- **Persistent terminal counter** — always visible in your statusline
- **Interactive HTML dashboard** — category breakdown, timeline, detection details

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🐤 Canary: 142 PII items exposed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  across 31 session(s) | 89 high-confidence
  regex: 97 | claude self-scan: 45
  email                  23
  phone_number           18
  name                   15
  ...
  /canary:leaked → dashboard | /canary:scan → deep scan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

| Command | Description |
|---------|-------------|
| `/canary:leaked` | Open interactive dashboard |
| `/canary:leaked stats` | Text summary |
| `/canary:scan` | Claude scans its own conversation for semantic PII |
| `/canary:leaked reset` | Clear all data |

#### Persistent Counter

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.sonomos/statusline.sh"
  }
}
```

See the [Canary README](canary/README.md) for full documentation.

## About Sonomos

[Sonomos](https://sonomos.ai) detects and masks PII *before* it reaches AI. The browser extension works with Claude, ChatGPT, Gemini, Grok, and more.

Canary shows you what you've already exposed. Sonomos prevents exposure in the first place.

---

Copyright © 2026 Sonomos Inc. All rights reserved.
