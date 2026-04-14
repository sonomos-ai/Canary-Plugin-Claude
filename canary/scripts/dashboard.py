#!/usr/bin/env python3
# Copyright © 2026 Sonomos, Inc.
# All rights reserved.
#
# dashboard.py — Generates an interactive HTML dashboard from leaks.jsonl.
# Outputs the HTML file path to stdout.

import json
import sys
import os
import webbrowser
from collections import Counter, defaultdict
from datetime import datetime

SONOMOS_DIR = os.environ.get("CLAUDE_PLUGIN_DATA", os.path.expanduser("~/.sonomos"))
LEAKS_FILE = os.path.join(SONOMOS_DIR, "leaks.jsonl")
CONFIG_FILE = os.path.join(SONOMOS_DIR, "config.json")
OUTPUT_FILE = os.path.join(SONOMOS_DIR, "dashboard.html")

def load_leaks():
    if not os.path.exists(LEAKS_FILE):
        return []
    leaks = []
    with open(LEAKS_FILE) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    leaks.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return leaks

def load_config():
    default = {"llm_scan_enabled": True, "regex_enabled": True}
    if not os.path.exists(CONFIG_FILE):
        return default
    try:
        with open(CONFIG_FILE) as f:
            return json.loads(f.read())
    except (json.JSONDecodeError, OSError):
        return default

def categorize_type(t):
    categories = {
        "Identity": ["name", "entity_name", "email", "us_ssn", "us_passport", "date_of_birth",
                      "us_drivers_license", "national_id", "tin_non_us", "nhs_number",
                      "sin_canadian", "us_itin", "passport_non_us", "license_plate", "us_mbi"],
        "Financial": ["credit_card", "iban", "aba_routing", "us_bank_account", "swift_bic",
                       "stripe_api_key", "twilio_credentials", "sendgrid_api_key",
                       "us_ein_fein", "financial_records"],
        "Crypto": ["bitcoin_address", "ethereum_address", "private_key", "seed_phrase",
                    "wallet_key", "xpub_key", "monero_address", "ripple_address",
                    "solana_address", "metamask_key", "exchange_api_key", "txid",
                    "private_key_hex"],
        "Legal": ["case_number", "attorney_number", "court_order", "litigation_id",
                   "contract_number", "patent_number", "trademark", "legal_entity",
                   "settlement_ref", "subpoena", "deposition", "evidence_id",
                   "witness_id", "filing_number"],
        "Medical": ["medical_record_mrn", "health_plan_id", "dea_number", "npi_number",
                     "diagnosis_code_icd10", "procedure_code_cpt", "vin"],
        "Technical": ["jwt", "oauth_token", "gcp_key", "azure_key", "aws_access_key",
                       "aws_secret_key", "generic_secret", "generic_api_key",
                       "github_pat", "slack_token", "mac_address", "uuid", "imei",
                       "serial_number", "android_id", "iphone_udid", "url_credentials"],
        "Network": ["ipv4", "ipv6", "geolocation", "street_address", "zip_code", "phone_number"],
        "Organizational": ["customer_data", "employee_data", "third_party_data",
                            "trade_secret", "internal_comms", "credentials_compound"],
    }
    for cat, types in categories.items():
        if t in types:
            return cat
    return "Other"

def generate_html(leaks, config):
    total = len(leaks)
    type_counts = Counter(l["type"] for l in leaks)
    session_count = len(set(l.get("session_id", "") for l in leaks))
    high_conf = sum(1 for l in leaks if l.get("confidence") == "high")
    regex_count = sum(1 for l in leaks if l.get("detector") == "regex")
    llm_count = sum(1 for l in leaks if l.get("detector") == "llm")
    llm_enabled = config.get("llm_scan_enabled", True)

    # Category aggregation
    cat_counts = Counter()
    for l in leaks:
        cat_counts[categorize_type(l["type"])] += 1

    # Timeline (by date)
    daily = Counter()
    for l in leaks:
        ts = l.get("timestamp", "")[:10]
        if ts:
            daily[ts] += 1
    timeline = sorted(daily.items())

    # Recent hits (last 20)
    recent = leaks[-20:][::-1]

    # Top types (for bar chart)
    top_types = type_counts.most_common(12)

    # Category colors
    cat_colors = {
        "Identity": "#e74c3c", "Financial": "#e67e22", "Crypto": "#8e44ad",
        "Legal": "#5b6abf", "Medical": "#d35498", "Technical": "#16a085",
        "Network": "#27ae60", "Organizational": "#e67e22", "Other": "#7f8c8d"
    }

    # JSON data for JS
    cat_data = json.dumps([{"name": k, "count": v, "color": cat_colors.get(k, "#7f8c8d")}
                           for k, v in sorted(cat_counts.items(), key=lambda x: -x[1])])
    timeline_data = json.dumps([{"date": d, "count": c} for d, c in timeline])
    top_types_data = json.dumps([{"type": t.replace("_", " "), "count": c} for t, c in top_types])
    recent_data = json.dumps([{
        "type": l["type"].replace("_", " "),
        "value": l.get("value", "••••"),
        "detector": l.get("detector", "?"),
        "confidence": l.get("confidence", "?"),
        "timestamp": l.get("timestamp", "")[:19].replace("T", " "),
        "category": categorize_type(l["type"])
    } for l in recent])

    llm_warning = ""
    if not llm_enabled:
        llm_warning = """
        <div class="llm-warning">
          <strong>LLM scanning is disabled.</strong>
          70+ semantic categories are not being detected — names, addresses, legal IDs,
          medical records, trade secrets, crypto keys, and more.
          Enable in <code>~/.sonomos/config.json</code> &rarr; <code>"llm_scan_enabled": true</code>
        </div>"""

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SONOMOS &mdash; Sensitive Data Exposure Report</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Jost:wght@400;500;600;700&family=Poppins:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500;600&display=swap');

  :root {{
    --bg: #ffffff;
    --surface: #f7f8f9;
    --surface2: #eef0f2;
    --border: #e2e5e9;
    --text: #1a1a1f;
    --text-secondary: #52555c;
    --text-dim: #8b8f96;
    --accent: #a8e6c3;
    --accent-deep: #6dcf97;
    --accent-subtle: #e8f8ef;
    --dark: #1a1a1f;
    --danger: #d94a4a;
    --warn: #d4930d;
  }}

  * {{ margin: 0; padding: 0; box-sizing: border-box; }}

  body {{
    font-family: 'Poppins', -apple-system, BlinkMacSystemFont, sans-serif;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
    font-weight: 400;
    font-size: 14px;
    line-height: 1.6;
  }}

  h1, h2, h3, .heading {{
    font-family: 'Jost', 'Futura', sans-serif;
  }}

  /* ── Header ─────────────────────────────────────── */

  .header {{
    background: var(--bg);
    border-bottom: 1px solid var(--border);
    padding: 24px 40px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    position: sticky;
    top: 0;
    z-index: 100;
  }}

  .logo {{
    font-family: 'Jost', 'Futura', sans-serif;
    font-size: 20px;
    font-weight: 700;
    letter-spacing: 3px;
    color: var(--dark);
    text-decoration: none;
  }}
  .logo-sub {{
    font-family: 'Poppins', sans-serif;
    font-size: 11px;
    color: var(--text-dim);
    font-weight: 400;
    letter-spacing: 0.5px;
    margin-top: 1px;
  }}

  .header-right {{ text-align: right; }}
  .big-counter {{
    font-family: 'Jost', 'Futura', sans-serif;
    font-size: 44px;
    font-weight: 700;
    color: var(--dark);
    line-height: 1;
  }}
  .big-counter-label {{
    font-family: 'Poppins', sans-serif;
    font-size: 11px;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 1.5px;
    font-weight: 500;
  }}

  /* ── Layout ─────────────────────────────────────── */

  .container {{ max-width: 1120px; margin: 0 auto; padding: 32px 40px; }}

  .stats-row {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
    margin-bottom: 28px;
  }}

  .stat-card {{
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 20px 22px;
  }}
  .stat-value {{
    font-family: 'Jost', 'Futura', sans-serif;
    font-size: 30px;
    font-weight: 700;
    color: var(--dark);
  }}
  .stat-value.warn {{ color: var(--danger); }}
  .stat-label {{
    font-size: 11px;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-top: 4px;
    font-weight: 500;
  }}

  .grid {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin-bottom: 28px;
  }}

  .card {{
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 22px 24px;
  }}
  .card-title {{
    font-family: 'Jost', 'Futura', sans-serif;
    font-size: 12px;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 1.5px;
    margin-bottom: 18px;
    font-weight: 600;
  }}

  /* ── Bar Charts ──────────────────────────────────── */

  .bar-row {{
    display: flex;
    align-items: center;
    margin: 7px 0;
    gap: 10px;
  }}
  .bar-label {{
    width: 110px;
    font-size: 12px;
    color: var(--text-secondary);
    text-align: right;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }}
  .bar {{
    height: 22px;
    border-radius: 4px;
    transition: width 0.5s ease;
    min-width: 2px;
  }}
  .bar-count {{
    font-family: 'JetBrains Mono', monospace;
    font-size: 12px;
    color: var(--text-dim);
    min-width: 28px;
  }}

  /* ── Category Grid ──────────────────────────────── */

  .cat-grid {{
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }}
  .cat-chip {{
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 10px 12px;
  }}
  .cat-dot {{ width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }}
  .cat-name {{ font-size: 12px; color: var(--text-secondary); flex: 1; }}
  .cat-count {{
    font-family: 'JetBrains Mono', monospace;
    font-size: 14px;
    font-weight: 600;
    color: var(--dark);
  }}

  /* ── Timeline ───────────────────────────────────── */

  .timeline-bar {{
    display: flex;
    align-items: flex-end;
    gap: 3px;
    height: 80px;
  }}
  .timeline-col {{
    flex: 1;
    background: var(--accent-deep);
    border-radius: 3px 3px 0 0;
    min-width: 4px;
    opacity: 0.6;
    transition: opacity 0.2s;
    cursor: pointer;
    position: relative;
  }}
  .timeline-col:hover {{ opacity: 1; }}
  .timeline-col .tip {{
    display: none;
    position: absolute;
    bottom: 105%;
    left: 50%;
    transform: translateX(-50%);
    background: var(--dark);
    color: #fff;
    padding: 4px 10px;
    border-radius: 4px;
    font-size: 10px;
    white-space: nowrap;
    z-index: 10;
  }}
  .timeline-col:hover .tip {{ display: block; }}

  /* ── Table ───────────────────────────────────────── */

  .recent-table {{ width: 100%; border-collapse: collapse; }}
  .recent-table th {{
    font-family: 'Jost', 'Futura', sans-serif;
    font-size: 10px;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 1px;
    text-align: left;
    padding: 10px 14px;
    border-bottom: 2px solid var(--border);
    font-weight: 600;
  }}
  .recent-table td {{
    font-size: 13px;
    padding: 11px 14px;
    border-bottom: 1px solid var(--border);
    color: var(--text-secondary);
  }}
  .recent-table tr:hover {{ background: var(--accent-subtle); }}

  .badge {{
    font-family: 'Jost', 'Futura', sans-serif;
    font-size: 9px;
    padding: 3px 7px;
    border-radius: 4px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }}
  .badge-high {{ background: #fdeaea; color: #c0392b; }}
  .badge-medium {{ background: #fef4e0; color: #b8860b; }}
  .badge-low {{ background: #f0f1f3; color: #7f8c8d; }}
  .badge-regex {{ background: #e0f5f1; color: #0e8a6d; }}
  .badge-llm {{ background: #ece5f8; color: #6c3fad; }}

  .mono {{
    font-family: 'JetBrains Mono', monospace;
    font-size: 12px;
    color: var(--text-dim);
  }}

  /* ── LLM Warning ────────────────────────────────── */

  .llm-warning {{
    background: #fef8ed;
    border: 1px solid #f0ddb8;
    border-radius: 10px;
    padding: 16px 22px;
    margin-bottom: 28px;
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.7;
  }}
  .llm-warning strong {{ color: var(--dark); }}
  .llm-warning code {{
    background: var(--surface);
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 12px;
  }}

  /* ── Sonomos Section ────────────────────────────── */

  .sonomos-section {{
    margin-top: 40px;
    padding: 32px 0;
    border-top: 1px solid var(--border);
    text-align: center;
  }}
  .sonomos-section .tagline {{
    font-family: 'Jost', 'Futura', sans-serif;
    font-size: 18px;
    font-weight: 600;
    color: var(--dark);
    margin-bottom: 10px;
    letter-spacing: -0.2px;
  }}
  .sonomos-section .tagline-sub {{
    font-size: 14px;
    color: var(--text-dim);
    max-width: 480px;
    margin: 0 auto 20px;
    line-height: 1.6;
  }}
  .sonomos-link {{
    display: inline-block;
    font-family: 'Jost', 'Futura', sans-serif;
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    color: var(--dark);
    text-decoration: none;
    border-bottom: 2px solid var(--accent);
    padding-bottom: 2px;
    transition: border-color 0.2s;
  }}
  .sonomos-link:hover {{ border-color: var(--accent-deep); }}

  /* ── Footer ─────────────────────────────────────── */

  .footer {{
    text-align: center;
    padding: 20px 40px;
    font-size: 11px;
    color: var(--text-dim);
    border-top: 1px solid var(--border);
  }}
  .footer a {{ color: var(--text-dim); text-decoration: none; }}
  .footer a:hover {{ color: var(--dark); }}
</style>
</head>
<body>

<div class="header">
  <div>
    <a href="https://sonomos.ai" class="logo">SONOMOS</a>
    <div class="logo-sub">Sensitive Data Monitor</div>
  </div>
  <div class="header-right">
    <div class="big-counter">{total}</div>
    <div class="big-counter-label">Exposures Detected</div>
  </div>
</div>

<div class="container">
  {llm_warning}

  <div class="stats-row">
    <div class="stat-card">
      <div class="stat-value warn">{total}</div>
      <div class="stat-label">Total Exposures</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">{session_count}</div>
      <div class="stat-label">Sessions</div>
    </div>
    <div class="stat-card">
      <div class="stat-value warn">{high_conf}</div>
      <div class="stat-label">High Confidence</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">{len(type_counts)}</div>
      <div class="stat-label">Data Types</div>
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <div class="card-title">Detection by Category</div>
      <div class="cat-grid" id="catGrid"></div>
    </div>
    <div class="card">
      <div class="card-title">Top Data Types</div>
      <div id="topTypes"></div>
    </div>
  </div>

  <div class="card" style="margin-bottom: 28px">
    <div class="card-title">Exposure Timeline</div>
    <div class="timeline-bar" id="timeline"></div>
  </div>

  <div class="card" style="margin-bottom: 28px">
    <div class="card-title">Detection Method</div>
    <div style="display:flex;gap:24px;align-items:center">
      <div style="flex:1">
        <div class="bar-row">
          <div class="bar-label">Pattern</div>
          <div class="bar" style="width:{regex_count*100/max(total,1):.0f}%;background:var(--accent-deep)"></div>
          <div class="bar-count">{regex_count}</div>
        </div>
        <div class="bar-row">
          <div class="bar-label">Semantic</div>
          <div class="bar" style="width:{llm_count*100/max(total,1):.0f}%;background:#8e7cc3"></div>
          <div class="bar-count">{llm_count}</div>
        </div>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="card-title">Recent Detections</div>
    <table class="recent-table">
      <thead><tr><th>Type</th><th>Value</th><th>Method</th><th>Confidence</th><th>Time</th></tr></thead>
      <tbody id="recentTable"></tbody>
    </table>
  </div>

  <div class="sonomos-section">
    <div class="tagline">Our "Canary" plugin shows what you've shared. Our tool prevents it.</div>
    <div class="tagline-sub">Detect and mask sensitive data in real time &mdash; before it reaches Claude, ChatGPT, Gemini, or any AI. Works everywhere you type.</div>
    <a href="https://sonomos.ai" class="sonomos-link">sonomos.ai</a>
  </div>
</div>

<div class="footer">
  <a href="https://sonomos.ai">SONOMOS</a> &nbsp;&middot;&nbsp; Copyright &copy; 2026 Sonomos, Inc.
</div>

<script>
const catData = {cat_data};
const timelineData = {timeline_data};
const topTypesData = {top_types_data};
const recentData = {recent_data};
const catColors = {json.dumps(cat_colors)};

// Category grid
const catGrid = document.getElementById('catGrid');
catData.forEach(c => {{
  catGrid.innerHTML += `<div class="cat-chip"><div class="cat-dot" style="background:${{c.color}}"></div><div class="cat-name">${{c.name}}</div><div class="cat-count">${{c.count}}</div></div>`;
}});

// Top types bar chart
const topEl = document.getElementById('topTypes');
const maxCount = topTypesData[0]?.count || 1;
topTypesData.forEach(t => {{
  topEl.innerHTML += `<div class="bar-row"><div class="bar-label">${{t.type}}</div><div class="bar" style="width:${{t.count*100/maxCount}}%;background:var(--accent-deep)"></div><div class="bar-count">${{t.count}}</div></div>`;
}});

// Timeline
const tlEl = document.getElementById('timeline');
const maxDay = Math.max(...timelineData.map(d => d.count), 1);
timelineData.forEach(d => {{
  const h = (d.count / maxDay) * 100;
  tlEl.innerHTML += `<div class="timeline-col" style="height:${{h}}%"><div class="tip">${{d.date}}: ${{d.count}}</div></div>`;
}});

// Recent table
const tbody = document.getElementById('recentTable');
recentData.forEach(r => {{
  const confClass = r.confidence === 'high' ? 'badge-high' : r.confidence === 'medium' ? 'badge-medium' : 'badge-low';
  const detClass = r.detector === 'regex' ? 'badge-regex' : 'badge-llm';
  tbody.innerHTML += `<tr><td>${{r.type}}</td><td class="mono">${{r.value}}</td><td><span class="badge ${{detClass}}">${{r.detector}}</span></td><td><span class="badge ${{confClass}}">${{r.confidence}}</span></td><td class="mono">${{r.timestamp}}</td></tr>`;
}});
</script>
</body>
</html>"""
    return html

def main():
    leaks = load_leaks()
    config = load_config()
    html = generate_html(leaks, config)

    os.makedirs(SONOMOS_DIR, exist_ok=True)
    with open(OUTPUT_FILE, 'w') as f:
        f.write(html)

    # Try to open, but don't fail if headless
    try:
        webbrowser.open(f"file://{OUTPUT_FILE}")
    except Exception:
        pass

    print(OUTPUT_FILE)

if __name__ == "__main__":
    main()
