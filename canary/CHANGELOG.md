# Changelog

All notable changes to the Sonomos Canary plugin are documented here.

## [1.3.0] - 2026-04-15

### Added
- Rich multi-line HUD replacing the single-line PII counter
- Session-specific detection delta (▲N) showing detections in the current session
- Type diversity count (distinct PII categories detected)
- Last detection relative timestamp (e.g., "3m ago")
- Detection method breakdown (regex/llm/file counts)
- Top 3 exposure categories with hit counts
- Dashboard file link in HUD (path when generated, command hint otherwise)
- Skill shortcut references (/canary:leaked, /canary:scan) in HUD footer

### Changed
- statusline.sh: rewritten as a 5-line bordered HUD with ANSI color-coding
- session-start.sh: now syncs statusline script on every session (not just first run)
- session-start.sh: updated welcome message with HUD setup instructions
- session-start.sh: returning-user summary uses new bordered layout with dashboard link

## [1.2.0] - 2026-04-14

### Fixed
- hooks.json: Added required `"hooks"` wrapper key (fixes hook loading failure in v1.1.0)

### Added
- Automatic LLM semantic scanning on every Stop hook (previously required manual `/canary:scan`)
- Defense-in-depth `llm_scan_enabled` gating in `record-llm-hit.sh`

### Changed
- LLM scan is now automatic (runs on every Stop alongside regex); `/canary:scan` remains for deep full-conversation audits
- Updated session-start welcome message to reflect automatic LLM scanning
- Updated skill descriptions to reflect new automatic behavior

## [1.1.0] - 2026-04-14

### Added
- macOS compatibility: Perl fallback when `grep -P` (GNU PCRE) is unavailable
- Bash 3.2 compatibility: VIN validator no longer requires associative arrays
- `userConfig` support: configure `llm_scan_enabled` and `confidence_threshold` at install time
- `PostToolUse` hook: real-time PII scanning when Claude writes/edits files
- `pii-audit` agent: comprehensive PII audit across all conversation transcripts
- `canary-stats` CLI tool: quick terminal stats from the command line
- `canary-export` CLI tool: export detections to CSV or JSON
- `record-llm-hit.sh` script: dedicated script for recording LLM-detected PII
- Test suite: 63 tests covering detectors, redaction, checksums, and false positives
- CI pipeline: GitHub Actions workflow for automated validation and testing
- Team distribution docs: `extraKnownMarketplaces` template for project-level auto-install

### Changed
- Data storage: uses `${CLAUDE_PLUGIN_DATA}` with `~/.sonomos` fallback for backward compatibility
- Marketplace source: simplified from `git-subdir` to relative path `./canary`
- Version management: removed duplicate version from marketplace.json (plugin.json is authoritative)
- LLM prompt hook: refactored to use `record-llm-hit.sh` script instead of inline shell

### Fixed
- SSN validator: fixed octal interpretation bug with leading-zero area codes (e.g., 078)

## [1.0.0] - 2026-04-14

### Added
- 16 regex-based PII detectors with cryptographic validation (Luhn, MOD-97, ABA checksum, Base58Check, EIP-55, VIN MOD-11, SSA exclusion rules)
- 70+ semantic PII categories via Claude self-scan (LLM prompt hook on Stop event)
- Persistent PII counter stored in `leaks.jsonl`
- Interactive HTML dashboard with category breakdown, timeline, top types, and recent detections
- Terminal status line integration with color-coded counter
- `/canary:leaked` skill — dashboard, stats, and reset subcommands
- `/canary:scan` skill — on-demand deep LLM scan of current conversation
- SessionStart hook — welcome message on first run, counter summary on subsequent sessions
- Stop hook — automatic regex scan after every Claude task

### Fixed
- Repaired broken plugin: hooks never registered due to wrapping `"hooks"` key in hooks.json (Claude Code expects event names at root level)

### Changed
- Rebranded from "leak-counter" to "Canary"
- Redesigned dashboard: white theme, Jost/Poppins fonts, "sensitive data" language
