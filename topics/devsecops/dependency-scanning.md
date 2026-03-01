# 📦 Dependency Scanning

> Modern applications are 80–90% third-party code. Every `npm install`, `pip install`, and `go get` pulls in code you didn't write and can't fully audit. Dependency scanning automatically identifies packages with known CVEs, license violations, and supply-chain risks — before they reach production.

---

## The Supply Chain Threat

```
Your application code: ~10%
Third-party dependencies: ~90%

Attack vectors:
  ├── Typosquatting:    malicious "lodahs" published to npm (vs "lodash")
  ├── Dependency confusion: attacker publishes internal-package-name to public registry
  ├── Compromised package: legitimate maintainer account hijacked (event-stream, ua-parser-js)
  ├── Known CVE:        existing package has a published vulnerability (log4j, xz-utils)
  └── Abandoned package: unmaintained, no security patches

Defense:
  ├── Lock files:       package-lock.json, Pipfile.lock, go.sum — pin exact versions
  ├── Audit in CI:      fail pipeline on high/critical CVEs
  ├── Dependabot:       auto-PRs for vulnerable package updates
  ├── SBOM:             inventory of every dependency (know what you have)
  └── Registry policies: only allow packages from approved registries
```

---

## npm audit (Node.js)

```bash
# ── Basic audit ───────────────────────────────────────────────────────────────
npm audit                          # list all vulnerabilities
npm audit --audit-level=high       # exit 1 only if high/critical found
npm audit --audit-level=critical   # exit 1 only if critical found
npm audit --json                   # JSON output for CI processing
npm audit --json | jq '.metadata.vulnerabilities'  # summary counts

# ── Fix ───────────────────────────────────────────────────────────────────────
npm audit fix                      # auto-fix compatible updates
npm audit fix --force              # force semver-breaking updates (test carefully)
npm audit fix --dry-run            # show what would change

# ── In CI: parse JSON output ──────────────────────────────────────────────────
npm audit --json > audit.json
# Check if any high/critical:
jq '.metadata.vulnerabilities | (.high + .critical) > 0' audit.json

# ── .nsprc / .npmrc: configure audit behavior ─────────────────────────────────
# .nsprc (audit exceptions for known false positives):
{
  "exceptions": [
    "https://npmjs.com/advisories/1234"
  ]
}
```

---

## Snyk

Snyk provides deeper analysis than `npm audit` — it understands reachability (is the vulnerable function actually called?), has broader CVE coverage, and supports multiple languages.

```bash
# ── Install ────────────────────────────────────────────────────────────────────
npm install -g snyk
snyk auth                          # authenticate with Snyk account

# ── Scan dependencies ─────────────────────────────────────────────────────────
snyk test                          # test current project
snyk test --severity-threshold=high   # fail only on high+
snyk test --json > snyk-report.json   # JSON output
snyk test --sarif > snyk.sarif        # SARIF for GitHub Security tab

# Scan specific package managers:
snyk test --file=requirements.txt    # Python
snyk test --file=go.mod              # Go
snyk test --file=pom.xml             # Java/Maven
snyk test --file=Gemfile.lock        # Ruby

# ── Scan container image ──────────────────────────────────────────────────────
snyk container test nginx:latest
snyk container test --file=Dockerfile myapp:latest

# ── Monitor (track over time in Snyk dashboard) ───────────────────────────────
snyk monitor                       # report current state to Snyk dashboard
snyk monitor --project-name="myapp-production"

# ── Fix ───────────────────────────────────────────────────────────────────────
snyk wizard                        # interactive fix suggestions
snyk fix                           # automatic fix (applies patches/updates)

# ── .snyk: policy file (suppress known issues) ────────────────────────────────
# .snyk:
version: v1.19.0
ignore:
  SNYK-JS-LODASH-1234567:
    - '*':
        reason: "Not exploitable in our use case — only called with trusted data"
        expires: "2025-06-01T00:00:00.000Z"
```

### Snyk in GitHub Actions

```yaml
# .github/workflows/snyk.yml
name: Snyk Dependency Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  snyk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Snyk to check for vulnerabilities
        uses: snyk/actions/node@master   # or: python, golang, docker
        continue-on-error: true          # upload results even if vulnerabilities found
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high --sarif-file-output=snyk.sarif

      - name: Upload result to GitHub Code Scanning
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: snyk.sarif
```

---

## pip-audit (Python)

```bash
# ── Install and run ────────────────────────────────────────────────────────────
pip install pip-audit

pip-audit                                   # audit current environment
pip-audit -r requirements.txt              # audit a requirements file
pip-audit --requirement requirements.txt --requirement requirements-dev.txt
pip-audit --format json -o audit.json       # JSON output
pip-audit --fix                             # auto-upgrade vulnerable packages

# With virtual environment:
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pip-audit                                   # audits the venv

# ── Safety (alternative with broader CVE database) ────────────────────────────
pip install safety
safety check                               # check current environment
safety check -r requirements.txt           # check a file
safety check --json > safety-report.json  # JSON output
safety check --full-report                # verbose output with remediation
```

---

## Dependabot (GitHub Automated Updates)

Dependabot automatically opens pull requests when dependencies have newer versions or known vulnerabilities. Zero manual effort.

```yaml
# .github/dependabot.yml
version: 2
updates:
  # ── npm ──────────────────────────────────────────────────────────────────────
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "Europe/Paris"
    open-pull-requests-limit: 10
    groups:
      # Group all dev dependency updates into one PR:
      dev-dependencies:
        dependency-type: "development"
      # Group all AWS SDK updates:
      aws-sdk:
        patterns:
          - "@aws-sdk/*"
    ignore:
      # Don't auto-update major versions (breaking changes):
      - dependency-name: "*"
        update-types: ["version-update:semver-major"]
    labels:
      - "dependencies"
      - "automated"

  # ── Python ───────────────────────────────────────────────────────────────────
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  # ── Go ───────────────────────────────────────────────────────────────────────
  - package-ecosystem: "gomod"
    directory: "/"
    schedule:
      interval: "weekly"

  # ── Docker base images ────────────────────────────────────────────────────────
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "docker"
      - "dependencies"

  # ── GitHub Actions ────────────────────────────────────────────────────────────
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"
```

---

## OWASP Dependency-Check

OWASP Dependency-Check correlates dependencies against the NVD (National Vulnerability Database) and is the most thorough free tool.

```bash
# ── Docker run (no install) ───────────────────────────────────────────────────
docker run --rm \
  -v "$(pwd):/src" \
  -v "$HOME/.dependency-check:/cache" \
  owasp/dependency-check \
  --scan /src \
  --format HTML \
  --format JSON \
  --out /src/dependency-check-report \
  --failOnCVSS 7             # fail if any CVE score >= 7

# ── CLI install ────────────────────────────────────────────────────────────────
# Download from https://github.com/jeremylong/DependencyCheck/releases
./dependency-check.sh \
  --scan ./src \
  --project "myapp" \
  --format "ALL" \
  --out ./reports \
  --failOnCVSS 8

# ── Maven / Gradle plugin ─────────────────────────────────────────────────────
# pom.xml:
<plugin>
  <groupId>org.owasp</groupId>
  <artifactId>dependency-check-maven</artifactId>
  <version>9.0.0</version>
  <configuration>
    <failBuildOnCVSS>8</failBuildOnCVSS>
    <suppressionFile>suppression.xml</suppressionFile>
  </configuration>
</plugin>

# Run:
mvn dependency-check:check
```

---

## go mod & govulncheck (Go)

```bash
# ── Built-in: go mod ─────────────────────────────────────────────────────────
go mod tidy                           # remove unused, add missing
go mod verify                         # verify modules against go.sum (tamper detection)
go list -m -json all | jq .           # list all dependencies with versions

# ── govulncheck — official Go vulnerability scanner ───────────────────────────
go install golang.org/x/vuln/cmd/govulncheck@latest

govulncheck ./...                     # scan current module
govulncheck -json ./... > vuln.json  # JSON output
govulncheck -mode=binary ./bin/app    # scan a compiled binary

# govulncheck understands call graphs — it only reports vulnerabilities in
# functions that are actually reachable from your code (fewer false positives
# than tools that flag all packages with any CVE).
```

---

## License Compliance

```bash
# ── license-checker (npm) ─────────────────────────────────────────────────────
npx license-checker --summary          # summary of license types used
npx license-checker --onlyAllow "MIT;Apache-2.0;BSD-3-Clause;ISC"  # fail on others
npx license-checker --csv > licenses.csv  # export for legal review

# ── pip-licenses (Python) ────────────────────────────────────────────────────
pip install pip-licenses
pip-licenses --format=markdown         # markdown table
pip-licenses --allow-only="MIT;Apache Software License;BSD License"
pip-licenses --with-urls --format=json > licenses.json

# ── go-licenses (Go) ─────────────────────────────────────────────────────────
go install github.com/google/go-licenses@latest
go-licenses report ./...               # report all dependency licenses
go-licenses check ./...                # fail if any non-permitted license found
go-licenses save ./... --save_path=./licenses  # download all license texts
```

---

## CI Pipeline: Full Dependency Scan

```yaml
# .github/workflows/dependency-scan.yml
name: Dependency Scan

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 3 * * 1'   # weekly full scan Monday 3 AM

jobs:
  npm-audit:
    name: npm audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm audit --audit-level=high

  snyk:
    name: Snyk
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high --sarif-file-output=snyk.sarif
        continue-on-error: true
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: snyk.sarif

  govulncheck:
    name: govulncheck (Go)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: go install golang.org/x/vuln/cmd/govulncheck@latest
      - run: govulncheck ./...

  pip-audit:
    name: pip-audit (Python)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install pip-audit
      - run: pip-audit -r requirements.txt
```