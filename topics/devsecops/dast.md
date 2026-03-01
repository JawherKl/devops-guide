# 🔍 DAST — Dynamic Application Security Testing

> DAST tests your application while it's **running** — probing it like a real attacker would. Unlike SAST (which reads source code), DAST sends actual HTTP requests and observes responses. It finds the bugs that only appear at runtime: injection flaws, authentication bypasses, exposed admin panels, misconfigured CORS, and broken access control. Run DAST in CI against a staging environment before every release.

---

## SAST vs DAST: Complementary, Not Competing

```
                         Source code          Running application
                              │                       │
         SAST ────────────────┘               DAST ───┘
    (static analysis)                    (dynamic scanning)
         │                                       │
    Finds:                                  Finds:
    • Insecure code patterns                • SQL injection (confirmed)
    • Hardcoded secrets                     • XSS in rendered HTML
    • Dangerous function calls              • Auth bypass
    • IaC misconfigurations                 • IDOR / broken access control
    • Dependency CVEs                       • Security misconfigurations
                                            • Exposed endpoints
    Fast (no server needed)                 Slower (needs running app)
    Many false positives                    Fewer false positives (real traffic)
```

Both belong in your pipeline: SAST catches issues early in PR checks; DAST validates the deployed build before it reaches production.

---

## OWASP ZAP (Zed Attack Proxy)

OWASP ZAP is the most widely used open-source DAST tool. It acts as an intercepting proxy, crawls your application, and actively probes for vulnerabilities.

### ZAP Modes

| Mode | What it does | Use when |
|------|-------------|---------|
| **Baseline** | Passive scan only — no attack traffic | Any branch (safe, fast) |
| **Full** | Passive + active scan (sends attack payloads) | Staging/pre-prod only |
| **API** | Scans OpenAPI/Swagger specs or GraphQL | REST/GraphQL APIs |
| **Ajax Spider** | Crawls JavaScript-heavy SPAs | React/Vue/Angular apps |

### ZAP Baseline Scan (Passive — Safe for Any Environment)

```bash
# Pull the official ZAP Docker image
docker pull ghcr.io/zaproxy/zaproxy:stable

# Baseline scan: passive only, no attack payloads
# Reports misconfigs, missing headers, information disclosure
docker run --rm \
  -v $(pwd)/reports:/zap/wrk \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t https://staging.example.com \
  -r zap-baseline-report.html \
  -J zap-baseline-report.json \
  -x zap-baseline-report.xml \
  -I                     # don't fail on warnings, only on alerts

# Exit codes:
# 0 = no alerts
# 1 = warnings found
# 2 = alerts found (FAIL)
```

### ZAP Full Scan (Active — Staging Only)

```bash
# Full scan: active attack payloads — NEVER run against production
# Sends SQLi, XSS, path traversal, and other payloads
docker run --rm \
  -v $(pwd)/reports:/zap/wrk \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-full-scan.py \
  -t https://staging.example.com \
  -r zap-full-report.html \
  -J zap-full-report.json \
  -m 5 \           # 5 minute max spider time
  -T 60 \          # 60 minute overall timeout
  -I               # don't fail on warnings

# With authentication (cookie-based):
docker run --rm \
  -v $(pwd)/reports:/zap/wrk \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-full-scan.py \
  -t https://staging.example.com \
  -r zap-full-report.html \
  -n context.context \   # ZAP context file with auth config
  -U "testuser"
```

### ZAP API Scan (OpenAPI / Swagger / GraphQL)

```bash
# Scan a REST API using its OpenAPI spec
# Much more thorough than crawling — tests every documented endpoint
docker run --rm \
  -v $(pwd)/reports:/zap/wrk \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py \
  -t https://staging.example.com/api/openapi.json \
  -f openapi \
  -r zap-api-report.html \
  -J zap-api-report.json \
  -x zap-api-report.xml

# GraphQL:
docker run --rm \
  -v $(pwd)/reports:/zap/wrk \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py \
  -t https://staging.example.com/graphql \
  -f graphql \
  -r zap-graphql-report.html

# With Bearer token authentication:
docker run --rm \
  -v $(pwd)/reports:/zap/wrk \
  -e ZAP_AUTH_HEADER="Authorization" \
  -e ZAP_AUTH_HEADER_VALUE="Bearer eyJhbGci..." \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py \
  -t https://staging.example.com/api/openapi.json \
  -f openapi \
  -r zap-api-report.html
```

### ZAP Rules Configuration

Control which rules run and how they fail:

```ini
# .zap/rules.tsv  (tab-separated: rule_id  IGNORE|WARN|FAIL  description)

# Suppress false positives for known issues
10202	IGNORE	Absence of Anti-CSRF Tokens (SPA uses JWT, not cookies)
10010	IGNORE	Cookie No HttpOnly Flag (third-party analytics cookie)

# Downgrade severity of informational findings
10035	WARN	Strict-Transport-Security Header Not Set
10036	WARN	Server Leaks Version Information

# Upgrade to FAIL (must fix before merge):
40014	FAIL	Cross Site Scripting (Persistent)
40018	FAIL	SQL Injection
40012	FAIL	Cross Site Scripting (Reflected)
90022	FAIL	Application Error Disclosure
```

```bash
# Use the rules file with any ZAP scan:
docker run --rm \
  -v $(pwd):/zap/wrk \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t https://staging.example.com \
  -c .zap/rules.tsv \
  -r zap-report.html
```

---

## ZAP in GitHub Actions

### Baseline on Every PR

```yaml
# .github/workflows/dast-baseline.yml
name: DAST — Baseline

on:
  pull_request:
    branches: [main]

jobs:
  zap-baseline:
    name: ZAP Baseline Scan
    runs-on: ubuntu-latest
    permissions:
      issues: write           # ZAP action can create GitHub issues for findings
      security-events: write  # upload SARIF to GitHub Security tab

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to ephemeral staging
        run: |
          docker compose -f docker-compose.staging.yml up -d
          # Wait for app to be healthy
          for i in $(seq 1 30); do
            curl -sf http://localhost:8080/health && break
            sleep 2
          done

      - name: ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.12.0
        with:
          target: http://localhost:8080
          rules_file_name: .zap/rules.tsv
          cmd_options: "-I"                    # don't fail on warnings
          artifact_name: zap-baseline-results

      - name: Upload SARIF to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: results.sarif

      - name: Teardown
        if: always()
        run: docker compose -f docker-compose.staging.yml down
```

### Full Scan on Release Branch

```yaml
# .github/workflows/dast-full.yml
name: DAST — Full Scan

on:
  push:
    branches: [release/*]
  schedule:
    - cron: "0 2 * * 1"   # also run every Monday at 2 AM

jobs:
  zap-full:
    name: ZAP Full Scan
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    environment: staging   # requires manual approval + staging secrets

    steps:
      - uses: actions/checkout@v4

      - name: ZAP Full Scan
        uses: zaproxy/action-full-scan@v0.10.0
        with:
          target: ${{ vars.STAGING_URL }}
          rules_file_name: .zap/rules.tsv
          token: ${{ secrets.GITHUB_TOKEN }}
          cmd_options: "-T 60"      # 60 min timeout

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: results.sarif
```

### API Scan with Auth Token

```yaml
# .github/workflows/dast-api.yml
name: DAST — API Scan

on:
  push:
    branches: [main]

jobs:
  zap-api:
    name: ZAP API Scan
    runs-on: ubuntu-latest
    permissions:
      security-events: write

    steps:
      - uses: actions/checkout@v4

      - name: Get auth token for test user
        id: auth
        run: |
          TOKEN=$(curl -s -X POST ${{ vars.STAGING_URL }}/auth/login \
            -H "Content-Type: application/json" \
            -d '{"email":"zap-bot@example.com","password":"${{ secrets.ZAP_BOT_PASSWORD }}"}' \
            | jq -r '.token')
          echo "token=$TOKEN" >> $GITHUB_OUTPUT

      - name: ZAP API Scan
        uses: zaproxy/action-api-scan@v0.7.0
        with:
          target: ${{ vars.STAGING_URL }}/api/openapi.json
          format: openapi
          rules_file_name: .zap/rules.tsv
          cmd_options: >-
            -z "-config replacer.full_list(0).description=auth-token
                -config replacer.full_list(0).enabled=true
                -config replacer.full_list(0).matchtype=REQ_HEADER
                -config replacer.full_list(0).matchstr=Authorization
                -config replacer.full_list(0).replacement=Bearer ${{ steps.auth.outputs.token }}"
```

---

## Nuclei — Template-Based Vulnerability Scanner

Nuclei uses YAML templates to check for specific CVEs, misconfigurations, and exposed services. Faster and more targeted than ZAP for known vulnerability patterns.

```bash
# Install
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
# or:
docker pull projectdiscovery/nuclei:latest

# Update templates (community-maintained library of 7000+ checks)
nuclei -update-templates

# ── Basic scans ──────────────────────────────────────────────────────────────
# Scan with all default templates:
nuclei -u https://staging.example.com

# Scan with specific severity only:
nuclei -u https://staging.example.com -severity critical,high

# Scan specific categories:
nuclei -u https://staging.example.com -tags cve,misconfig,exposure
nuclei -u https://staging.example.com -tags oast    # out-of-band (SSRF, blind injection)

# Scan multiple targets from file:
nuclei -l targets.txt -severity high,critical

# ── Output formats ────────────────────────────────────────────────────────────
nuclei -u https://staging.example.com \
  -o nuclei-results.txt \
  -json-export nuclei-results.json \
  -markdown-export nuclei-report/

# ── Rate limiting (be kind to staging) ───────────────────────────────────────
nuclei -u https://staging.example.com \
  -rate-limit 50 \          # max 50 requests/second
  -concurrency 10 \         # max 10 concurrent templates
  -timeout 10               # 10 second per-request timeout

# ── With authentication ───────────────────────────────────────────────────────
nuclei -u https://staging.example.com \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Key: $API_KEY"
```

### Nuclei in CI

```yaml
# .github/workflows/nuclei.yml
name: Nuclei Scan

on:
  push:
    branches: [main]

jobs:
  nuclei:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Nuclei Scan
        uses: projectdiscovery/nuclei-action@main
        with:
          target: ${{ vars.STAGING_URL }}
          flags: "-severity critical,high -tags cve,misconfig"
          sarif-export: results.sarif

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: results.sarif
```

---

## API Fuzzing with Schemathesis

Schemathesis generates test cases from your OpenAPI spec and sends edge-case inputs to find crashes, 500 errors, and schema violations — bugs ZAP won't catch.

```bash
# Install
pip install schemathesis

# ── Basic fuzzing ─────────────────────────────────────────────────────────────
# Fuzz all endpoints in the spec:
schemathesis run https://staging.example.com/api/openapi.json

# Only test specific HTTP methods:
schemathesis run https://staging.example.com/api/openapi.json \
  --method GET --method POST

# With authentication:
schemathesis run https://staging.example.com/api/openapi.json \
  -H "Authorization: Bearer $TOKEN"

# ── Stateful testing (sequences: login → action → verify) ────────────────────
schemathesis run https://staging.example.com/api/openapi.json \
  --stateful=links         # follow OpenAPI links between operations

# ── Output formats ────────────────────────────────────────────────────────────
schemathesis run https://staging.example.com/api/openapi.json \
  --report=junit.xml \     # JUnit XML for CI
  --show-errors-tracebacks

# Exit codes:
# 0 = all tests passed
# 1 = test failures found (API returned errors)
```

### Schemathesis in CI

```yaml
# .github/workflows/api-fuzz.yml
name: API Fuzzing

on:
  push:
    branches: [main]
  schedule:
    - cron: "0 3 * * *"    # nightly full fuzz

jobs:
  fuzz:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up staging app
        run: docker compose up -d && sleep 10

      - name: Get auth token
        id: auth
        run: |
          TOKEN=$(curl -sf -X POST http://localhost:8080/auth/login \
            -H "Content-Type: application/json" \
            -d '{"email":"test@example.com","password":"${{ secrets.TEST_PASSWORD }}"}' \
            | jq -r '.token')
          echo "token=$TOKEN" >> $GITHUB_OUTPUT

      - name: Install Schemathesis
        run: pip install schemathesis

      - name: Fuzz API
        run: |
          schemathesis run http://localhost:8080/api/openapi.json \
            -H "Authorization: Bearer ${{ steps.auth.outputs.token }}" \
            --report=schemathesis-results.xml \
            --max-response-time=2000 \
            --show-errors-tracebacks
        continue-on-error: true

      - name: Upload results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: schemathesis-results
          path: schemathesis-results.xml
```

---

## Testing Authenticated Endpoints

Most real applications require login. Here's a pattern for authenticating DAST tools before scanning.

```python
#!/usr/bin/env python3
# scripts/dast-auth-helper.py
# Gets a short-lived test token and saves it for use by ZAP / Nuclei

import os
import json
import subprocess
import requests

STAGING_URL = os.environ["STAGING_URL"]
TEST_EMAIL   = os.environ["ZAP_TEST_EMAIL"]
TEST_PASS    = os.environ["ZAP_TEST_PASSWORD"]

def get_token() -> str:
    resp = requests.post(
        f"{STAGING_URL}/auth/login",
        json={"email": TEST_EMAIL, "password": TEST_PASS},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()["accessToken"]

def write_zap_context(token: str) -> None:
    """Write a ZAP context file with the auth token pre-configured."""
    context = {
        "replacer": {
            "rules": [{
                "description": "Auth Bearer Token",
                "matchtype": "REQ_HEADER",
                "matchstr": "Authorization",
                "enabled": True,
                "replacement": f"Bearer {token}",
            }]
        }
    }
    with open(".zap/auth-context.json", "w") as f:
        json.dump(context, f, indent=2)
    print(f"ZAP context written with token (first 10 chars): {token[:10]}...")

if __name__ == "__main__":
    token = get_token()
    write_zap_context(token)
    # Also export for shell scripts
    print(f"::set-output name=token::{token}")  # GitHub Actions output
```

---

## Complete DAST Pipeline

```yaml
# .github/workflows/dast-pipeline.yml
name: Full DAST Pipeline

on:
  push:
    branches: [main, release/*]

jobs:
  # Stage 1: Deploy ephemeral staging environment
  deploy-staging:
    runs-on: ubuntu-latest
    outputs:
      staging-url: ${{ steps.deploy.outputs.url }}
    steps:
      - uses: actions/checkout@v4
      - name: Build and start app
        id: deploy
        run: |
          docker compose -f docker-compose.staging.yml up -d
          echo "url=http://localhost:8080" >> $GITHUB_OUTPUT
          # Wait for health
          for i in $(seq 1 30); do
            curl -sf http://localhost:8080/health && break || sleep 3
          done

  # Stage 2: ZAP baseline (passive — fast, safe)
  zap-baseline:
    needs: deploy-staging
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - uses: zaproxy/action-baseline@v0.12.0
        with:
          target: ${{ needs.deploy-staging.outputs.staging-url }}
          rules_file_name: .zap/rules.tsv
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: results.sarif

  # Stage 3: Nuclei CVE / misconfiguration scan
  nuclei:
    needs: deploy-staging
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - uses: projectdiscovery/nuclei-action@main
        with:
          target: ${{ needs.deploy-staging.outputs.staging-url }}
          flags: "-severity critical,high -tags cve,misconfig,exposure"
          sarif-export: nuclei.sarif
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: nuclei.sarif

  # Stage 4: API fuzzing with Schemathesis
  api-fuzz:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install schemathesis
      - run: |
          schemathesis run \
            ${{ needs.deploy-staging.outputs.staging-url }}/api/openapi.json \
            --report=fuzz-results.xml \
            --max-response-time=2000
        continue-on-error: true
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: fuzz-results
          path: fuzz-results.xml

  # Stage 5: Gate — fail if critical DAST findings
  security-gate:
    needs: [zap-baseline, nuclei, api-fuzz]
    runs-on: ubuntu-latest
    steps:
      - name: Check security gate
        run: |
          echo "All DAST stages complete."
          echo "Review findings in GitHub Security tab before merging."
          # Add custom logic here to block on critical findings
```

---

## DAST Best Practices

```
Scope DAST correctly
  ✅ Always scan staging, never production (active scans send attack payloads)
  ✅ Use a dedicated DAST test account with realistic permissions
  ✅ Scope the scan: include authenticated paths, exclude logout/delete-all endpoints
  ✅ If you must scan production: passive baseline only, rate-limit heavily

Authentication strategy
  ✅ Create a dedicated DAST service account (not a real user)
  ✅ Pre-auth the scanner (get token before scan, inject via header)
  ✅ Test both authenticated and unauthenticated paths
  ✅ Rotate the DAST account credentials regularly

Managing findings
  ✅ Triage alerts: ZAP produces false positives — verify before filing a ticket
  ✅ Use rules.tsv to suppress known false positives (document WHY)
  ✅ FAIL CI on High/Critical; WARN on Medium; IGNORE informational
  ✅ Export SARIF and view in GitHub Security tab for unified tracking

❌ Common mistakes:
  • Running full active scan against production → real attack traffic on live users
  • Scanning without auth → misses all authenticated functionality (80% of bugs)
  • Ignoring all findings because of false positives → defeats the purpose
  • Not rate-limiting → floods staging logs, fills disks, crashes the app under test
```