# Contributing to Canary

PRs welcome. Here's how to get started.

## Setup

```bash
git clone https://github.com/sonomos-ai/Canary.git
cd Canary
```

No build step. Canary is shell scripts + one Python file. Edit and test directly.

## Run Tests

```bash
bash tests/test-detectors.sh          # regex detector accuracy
bash tests/test-checksums.sh          # checksum validation (Luhn, MOD-97, ABA, etc.)
bash tests/test-redact.sh             # redaction format
bash tests/test-no-false-positives.sh # false positive prevention
```

All 4 suites must pass before submitting a PR.

## Adding a New Detector

1. Add the detection logic to `canary/scripts/detectors.sh`
2. Use the existing pattern: regex match -> validation function -> redact -> JSON output
3. Include checksum validation if the format supports it (Luhn, MOD-97, etc.)
4. Set `confidence` to `"high"` if checksum-validated, `"medium"` if pattern-only
5. Add positive and negative tests to `tests/test-detectors.sh`
6. Add false positive cases to `tests/test-no-false-positives.sh`
7. Update the detector count in the README if applicable

## Code Style

- Shell scripts: `set -euo pipefail`, POSIX-compatible where possible, Bash 3.2+ minimum
- Use `|| true` for commands that may legitimately fail (grep no-match, etc.)
- Never log raw PII values — always redact first
- Use `jq` for JSON construction (not string interpolation)
- All files written to `~/.sonomos/` must use `umask 0077`

## What We're Looking For

- New detectors for region-specific PII (Canadian SIN, UK NI, EU VAT, etc.)
- Performance improvements (especially for large `leaks.jsonl` files)
- Dashboard enhancements
- Better false positive prevention
- macOS/Linux/Windows compatibility fixes

## What We Won't Merge

- Features that make network requests
- Telemetry or analytics of any kind
- Changes that store raw (unredacted) PII values
- Dependencies on external services

## Security Issues

Do not open a public issue. Email info@sonomos.ai. See [SECURITY.md](SECURITY.md).
