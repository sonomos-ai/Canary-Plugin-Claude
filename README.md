# 🐤 Canary

**You have no idea how much PII you've fed to Claude. Canary counts it for you.**

Canary is a privacy plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by [Sonomos](https://sonomos.ai). It monitors every conversation for sensitive data exposure and keeps a persistent, running tally across all sessions. The number only goes up.

Every time you paste code, logs, configs, stack traces, or messages into Claude Code, there's a chance you're leaking API keys, email addresses, phone numbers, SSNs, credit card numbers, crypto wallets, and dozens of other PII categories without realizing it. Canary catches them in real time and makes the count impossible to ignore.

━━━ 🐤 CANARY ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
142 PII (89 high) │ ▲12 session │ 15 types │ last: 3m ago
regex:97 · llm:45 │ top: email(23) phone_number(18) name(15)
📊 ~/.sonomos/dashboard.html │ /canary:leaked · /canary:scan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Install

```bash
# Add the Sonomos marketplace
/plugin marketplace add sonomos-ai/Canary-Plugin

# Install Canary
/plugin install canary@sonomos
```

That's it. No API keys. No external services. Everything runs locally.

## What It Detects

### Regex Engine (16 detectors)

Pattern-matched detection with real checksum validation, not just "looks like a number." Canary validates against Luhn (credit cards), MOD-97 (IBANs), ABA (routing numbers), Base58Check (Bitcoin addresses), EIP-55 (Ethereum addresses), MOD-11 (various ID formats), and SSA exclusion rules (Social Security numbers).

Covers credit card numbers, SSNs, phone numbers, email addresses, IP addresses, API keys, AWS credentials, crypto wallets, IBANs, routing numbers, passport numbers, and more.

### Semantic Scan (70+ categories)

Claude scans its own conversation history for PII that regex can't catch: names, addresses, dates of birth, medical information, legal case details, financial data, employment history, and dozens of other contextual categories. No external API call required. Claude is the model doing the scanning.

## Commands

| Command | Description |
|---------|-------------|
| `/canary:leaked` | Open the interactive HTML dashboard |
| `/canary:leaked stats` | Print a text summary to the terminal |
| `/canary:scan` | Trigger a Claude self-scan of the current conversation |
| `/canary:leaked reset` | Clear all detection data |

### CLI Tools

After installing, these are available in the Bash tool:

| Command | Description |
|---------|-------------|
| `canary-stats` | Quick PII exposure summary |
| `canary-stats --json` | Stats as JSON |
| `canary-export` | Export all detections to CSV |
| `canary-export --json` | Export as JSON array |

## The Dashboard

Canary generates an interactive HTML dashboard at `~/.sonomos/dashboard.html` with:

- Running PII count with severity breakdown (high / medium / low)
- Category breakdown (which types of data you're leaking most)
- Detection timeline (when exposure is happening)
- Per-detection details (what was caught, which detector, when)

## Persistent Statusline

To keep Canary's counter visible in your Claude Code statusline across all sessions, add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.sonomos/statusline.sh"
  }
}
```

The statusline shows your total PII count, session delta, top categories, and a link to the dashboard. It updates in real time as you work.

## Team Distribution

To auto-install Canary for every developer on your team, add this to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "sonomos": {
      "source": {
        "source": "github",
        "repo": "sonomos-ai/Canary-Plugin"
      }
    }
  },
  "enabledPlugins": {
    "canary@sonomos": true
  }
}
```

Team members will be prompted to install the marketplace when they open the project. From there, Canary runs automatically.

## How It Works

Canary is built in Shell and Python. The regex engine runs locally via Bash scripts with validation logic for each detector type. The semantic scan leverages Claude's own context window to identify PII that pattern matching misses. All detection data is stored locally at `~/.sonomos/`. Nothing is transmitted externally. No telemetry. No analytics. No network requests.
.claude-plugin/       # Plugin manifest and hook definitions
canary/               # Core plugin code
├── detectors/      # Regex detection engine (16 patterns + checksums)
├── semantic/       # Claude self-scan prompt and parser
├── dashboard/      # HTML dashboard generator
└── statusline.sh   # Persistent statusline script
tests/                # Test suite
.github/workflows/    # CI

## Why This Exists

Most developers don't know how much sensitive data they've shared with AI tools. The answer is almost always "more than you think." Canary makes that number visible and persistent. It doesn't block anything. It doesn't redact anything. It just counts, because you can't fix what you can't see.

Canary shows you what you've already exposed. If you want to prevent exposure before it happens, that's what the [Sonomos browser extension](https://sonomos.ai) does. It detects and masks PII in real time across Claude, ChatGPT, Gemini, Grok, and any other AI tool, before your data ever leaves the browser.

## License

MIT

---

Built by [Sonomos](https://sonomos.ai)

---

Copyright © 2026 Sonomos, Inc. All rights reserved.
