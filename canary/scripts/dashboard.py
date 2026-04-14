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

SONOMOS_DIR = os.path.expanduser("~/.sonomos")
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
        "Identity": "#ef4444", "Financial": "#f59e0b", "Crypto": "#8b5cf6",
        "Legal": "#6366f1", "Medical": "#ec4899", "Technical": "#06b6d4",
        "Network": "#10b981", "Organizational": "#f97316", "Other": "#6b7280"
    }

    # JSON data for JS
    cat_data = json.dumps([{"name": k, "count": v, "color": cat_colors.get(k, "#6b7280")}
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
          <span class="warn-icon">⚠</span>
          <div>
            <strong>LLM scanning is disabled</strong>
            <p>70+ semantic categories are not being detected: names, addresses, legal IDs,
            medical records, trade secrets, crypto keys, API tokens, and more.</p>
            <p>Enable in <code>~/.sonomos/config.json</code> → <code>"llm_scan_enabled": true</code></p>
          </div>
        </div>"""

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sonomos — PII Leak Dashboard</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&family=Poppins:wght@400;500;600;700&display=swap');

  :root {{
    --bg: #0a0a0f;
    --surface: #12121a;
    --surface2: #1a1a27;
    --border: #2a2a3d;
    --text: #e4e4ed;
    --text-dim: #8888a0;
    --accent: #6ee7b7;
    --accent2: #34d399;
    --danger: #ef4444;
    --warn: #f59e0b;
    --sonomos-gradient: linear-gradient(135deg, #6ee7b7 0%, #3b82f6 100%);
  }}

  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: 'Poppins', sans-serif; background: var(--bg); color: var(--text); min-height: 100vh; }}

  .header {{
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 20px 32px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    position: sticky;
    top: 0;
    z-index: 100;
    backdrop-filter: blur(12px);
  }}
  .logo {{ display: flex; align-items: center; gap: 12px; }}
  .logo-mark {{
    width: 36px; height: 36px;
    background: var(--sonomos-gradient);
    border-radius: 8px;
    display: flex; align-items: center; justify-content: center;
    font-size: 18px; font-weight: 700; color: #0a0a0f;
  }}
  .logo-text {{ font-size: 18px; font-weight: 700; letter-spacing: -0.5px; }}
  .logo-sub {{ font-size: 12px; color: var(--text-dim); font-weight: 400; }}

  .big-counter {{
    font-family: 'JetBrains Mono', monospace;
    font-size: 48px;
    font-weight: 700;
    background: var(--sonomos-gradient);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    text-align: right;
    line-height: 1;
  }}
  .big-counter-label {{ font-size: 11px; color: var(--text-dim); text-align: right; text-transform: uppercase; letter-spacing: 1px; }}

  .container {{ max-width: 1200px; margin: 0 auto; padding: 24px 32px; }}

  .stats-row {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }}
  .stat-card {{
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px;
  }}
  .stat-value {{ font-family: 'JetBrains Mono', monospace; font-size: 28px; font-weight: 700; }}
  .stat-label {{ font-size: 12px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 0.5px; margin-top: 4px; }}

  .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 24px; }}
  .card {{
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px;
  }}
  .card-title {{ font-size: 13px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 16px; font-weight: 600; }}

  .bar-row {{ display: flex; align-items: center; margin: 8px 0; gap: 8px; }}
  .bar-label {{ width: 120px; font-size: 12px; color: var(--text-dim); text-align: right; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
  .bar {{ height: 24px; border-radius: 4px; transition: width 0.6s ease; min-width: 2px; }}
  .bar-count {{ font-family: 'JetBrains Mono', monospace; font-size: 12px; color: var(--text-dim); min-width: 30px; }}

  .cat-grid {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }}
  .cat-chip {{
    display: flex; align-items: center; gap: 8px;
    background: var(--surface2); border-radius: 8px; padding: 10px 12px;
  }}
  .cat-dot {{ width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }}
  .cat-name {{ font-size: 12px; flex: 1; }}
  .cat-count {{ font-family: 'JetBrains Mono', monospace; font-size: 14px; font-weight: 600; }}

  .timeline-bar {{ display: flex; align-items: flex-end; gap: 2px; height: 80px; }}
  .timeline-col {{ flex: 1; background: var(--accent2); border-radius: 2px 2px 0 0; min-width: 4px; opacity: 0.7; transition: opacity 0.2s; cursor: pointer; position: relative; }}
  .timeline-col:hover {{ opacity: 1; }}
  .timeline-col .tip {{ display: none; position: absolute; bottom: 105%; left: 50%; transform: translateX(-50%);
    background: var(--surface2); border: 1px solid var(--border); padding: 4px 8px; border-radius: 4px;
    font-size: 10px; white-space: nowrap; z-index: 10; }}
  .timeline-col:hover .tip {{ display: block; }}

  .recent-table {{ width: 100%; }}
  .recent-table th {{ font-size: 11px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 0.5px; text-align: left; padding: 8px 12px; border-bottom: 1px solid var(--border); }}
  .recent-table td {{ font-size: 13px; padding: 10px 12px; border-bottom: 1px solid var(--border); }}
  .recent-table tr:hover {{ background: var(--surface2); }}
  .badge {{ font-size: 10px; padding: 2px 6px; border-radius: 4px; font-weight: 600; text-transform: uppercase; }}
  .badge-high {{ background: rgba(239,68,68,0.15); color: #ef4444; }}
  .badge-medium {{ background: rgba(245,158,11,0.15); color: #f59e0b; }}
  .badge-low {{ background: rgba(107,114,128,0.15); color: #9ca3af; }}
  .badge-regex {{ background: rgba(6,182,212,0.1); color: #06b6d4; }}
  .badge-llm {{ background: rgba(139,92,246,0.1); color: #8b5cf6; }}
  .mono {{ font-family: 'JetBrains Mono', monospace; font-size: 12px; }}

  .llm-warning {{
    background: rgba(245,158,11,0.08);
    border: 1px solid rgba(245,158,11,0.3);
    border-radius: 12px;
    padding: 16px 20px;
    margin-bottom: 24px;
    display: flex;
    gap: 12px;
    align-items: flex-start;
  }}
  .llm-warning .warn-icon {{ font-size: 20px; }}
  .llm-warning p {{ font-size: 13px; color: var(--text-dim); margin-top: 4px; }}
  .llm-warning code {{ background: var(--surface2); padding: 2px 6px; border-radius: 4px; font-size: 12px; }}

  .cta {{
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 24px;
    text-align: center;
    margin-top: 24px;
  }}
  .cta-title {{ font-size: 16px; font-weight: 600; margin-bottom: 8px; }}
  .cta-desc {{ font-size: 13px; color: var(--text-dim); margin-bottom: 16px; }}
  .cta-btn {{
    display: inline-block;
    background: var(--sonomos-gradient);
    color: #0a0a0f;
    padding: 10px 24px;
    border-radius: 8px;
    text-decoration: none;
    font-weight: 600;
    font-size: 14px;
  }}

  .footer {{ text-align: center; padding: 24px; font-size: 11px; color: var(--text-dim); }}
</style>
</head>
<body>
<div class="header">
  <div class="logo">
    <div class="logo-mark">S</div>
    <div>
      <div class="logo-text">Sonomos</div>
      <div class="logo-sub">PII Leak Counter</div>
    </div>
  </div>
  <div>
    <div class="big-counter">{total}</div>
    <div class="big-counter-label">PII Items Exposed</div>
  </div>
</div>

<div class="container">
  {llm_warning}

  <div class="stats-row">
    <div class="stat-card">
      <div class="stat-value" style="color: var(--danger)">{total}</div>
      <div class="stat-label">Total Exposures</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">{session_count}</div>
      <div class="stat-label">Sessions</div>
    </div>
    <div class="stat-card">
      <div class="stat-value" style="color: var(--danger)">{high_conf}</div>
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

  <div class="card" style="margin-bottom: 24px">
    <div class="card-title">Exposure Timeline</div>
    <div class="timeline-bar" id="timeline"></div>
  </div>

  <div class="card" style="margin-bottom: 24px">
    <div class="card-title">Detection Split</div>
    <div style="display:flex;gap:24px;align-items:center">
      <div style="flex:1">
        <div class="bar-row">
          <div class="bar-label">Regex</div>
          <div class="bar" style="width:{regex_count*100/max(total,1):.0f}%;background:#06b6d4"></div>
          <div class="bar-count">{regex_count}</div>
        </div>
        <div class="bar-row">
          <div class="bar-label">LLM</div>
          <div class="bar" style="width:{llm_count*100/max(total,1):.0f}%;background:#8b5cf6"></div>
          <div class="bar-count">{llm_count}</div>
        </div>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="card-title">Recent Detections</div>
    <table class="recent-table">
      <thead><tr><th>Type</th><th>Value</th><th>Detector</th><th>Confidence</th><th>Time</th></tr></thead>
      <tbody id="recentTable"></tbody>
    </table>
  </div>

  <div class="cta">
    <div class="cta-title">Catch PII before it reaches AI</div>
    <div class="cta-desc">Sonomos detects and masks sensitive data in real-time — before you hit send.<br>Browser extension for Claude, ChatGPT, Gemini, and more.</div>
    <a href="https://sonomos.ai" class="cta-btn">Get Sonomos →</a>
  </div>
</div>

<div class="footer">Copyright &copy; 2026 Sonomos Inc. All rights reserved.</div>

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
  topEl.innerHTML += `<div class="bar-row"><div class="bar-label">${{t.type}}</div><div class="bar" style="width:${{t.count*100/maxCount}}%;background:var(--accent2)"></div><div class="bar-count">${{t.count}}</div></div>`;
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
  tbody.innerHTML += `<tr><td>${{r.type}}</td><td class="mono">${{r.value}}</td><td><span class="badge ${{detClass}}">${{r.detector}}</span></td><td><span class="badge ${{confClass}}">${{r.confidence}}</span></td><td class="mono" style="color:var(--text-dim)">${{r.timestamp}}</td></tr>`;
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
