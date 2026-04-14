---
name: scan
description: Scan the current conversation for PII that regex may have missed. Detects names, addresses, legal IDs, medical records, trade secrets, crypto credentials, API tokens, and 70+ other semantic categories. Use when the user asks to scan for PII, check privacy exposure, or after sensitive work.
disable-model-invocation: false
user-invocable: true
argument-hint: "[full|quick]"
allowed-tools: Bash(cat *) Bash(jq *) Bash(echo *) Bash(wc *) Bash(python3 *)
---

# Sonomos LLM PII Scan

Scan your own conversation history for sensitive data that regex pattern matching cannot catch.

## Instructions

1. Read the conversation transcript:

```bash
TRANSCRIPT="!`cat /dev/stdin <<< '{}' | jq -r '.transcript_path // empty' 2>/dev/null`"
```

If transcript path is not available from hook context, find the most recent transcript:

```bash
LATEST=$(ls -t ~/.claude/projects/*/sessions/*.jsonl 2>/dev/null | head -1)
```

2. Extract the last 3000 characters of user messages from the transcript:

```bash
jq -r 'select(.type == "human") | .message.content // empty' "$LATEST" 2>/dev/null | tail -c 3000
```

If that yields nothing, try alternate format:
```bash
jq -r 'select(.role == "user") | if (.content | type) == "string" then .content elif (.content | type) == "array" then [.content[] | select(.type == "text") | .text] | join("\n") else empty end' "$LATEST" 2>/dev/null | tail -c 3000
```

3. Now scan that text yourself. Look for ALL of the following categories. For each item found, output a JSON line to append to the leaks file.

### Identity
name, entity_name, us_passport, date_of_birth, us_ein_fein, national_id, tin_non_us, nhs_number, sin_canadian, us_itin, passport_non_us, license_plate

### Financial
us_bank_account, swift_bic

### Crypto
private_key, seed_phrase, wallet_key, xpub_key, monero_address, ripple_address, solana_address, metamask_key, exchange_api_key, txid, private_key_hex

### Legal
case_number, attorney_number, court_order, litigation_id, contract_number, patent_number, trademark, legal_entity, settlement_ref, subpoena, deposition, evidence_id, witness_id, filing_number

### Medical
medical_record_mrn, health_plan_id, dea_number, npi_number, diagnosis_code_icd10, procedure_code_cpt

### Technical
jwt, oauth_token, gcp_key, azure_key, generic_secret, generic_api_key, mac_address, geolocation, uuid, imei, serial_number, android_id, iphone_udid, github_pat, slack_token, stripe_api_key, twilio_credentials, sendgrid_api_key, private_key_hex

### Location
street_address, zip_code

### Organizational (high-risk semantic categories)
- **customer_data**: data clearly belonging to a specific customer/client
- **employee_data**: employee names with roles, salaries, reviews, HR info
- **third_party_data**: business partners' or vendors' internal info
- **trade_secret**: proprietary algorithms, formulas, unreleased product details, internal metrics
- **internal_comms**: internal emails, Slack messages, meeting notes with sensitive content
- **credentials_compound**: username+password pairs, connection strings with auth
- **financial_records**: revenue, salary data, pricing strategies, investor info

4. For each PII item found, redact the value (keep first 2 and last 2 chars, replace middle with dots), then record the hit:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-llm-hit.sh" "<category>" "<redacted>" "high"
```

5. After scanning, report a summary:
   - How many new items were found
   - Breakdown by category
   - Current running total from the leaks file

If NO PII is found, say so clearly. That's a good result.

## Important
- NEVER output raw PII values. Always redact: `jo••••oe`, `12••••89`, etc.
- Focus on real PII, not example data, code variable names, or documentation references.
- Be conservative — medium/high confidence only. Don't flag generic words as names.
- Copyright © 2026 Sonomos Inc. All rights reserved.
