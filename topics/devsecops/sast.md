# 🔍 SAST — Static Application Security Testing

> SAST analyses source code without running it to find security vulnerabilities: SQL injection, XSS, hardcoded secrets, insecure cryptography, path traversal, and hundreds of other patterns. The earlier in the development cycle you catch these, the cheaper they are to fix. SAST integrated into a pre-commit hook costs seconds; the same bug found in production costs weeks.

---

## Tools by Language

| Language | Tool | What it finds |
|----------|------|---------------|
| All | **Semgrep** | Custom rules, OWASP Top 10, framework-specific patterns |
| All | **CodeQL** | Deep semantic analysis, data-flow tracking, GitHub native |
| Python | **Bandit** | Python-specific: `eval`, `pickle`, weak crypto, shell injection |
| Go | **gosec** | Go-specific: SQL injection, weak rand, file permission issues |
| JavaScript | **ESLint security plugins** | `no-eval`, injection patterns, prototype pollution |
| IaC (Terraform/K8s) | **Checkov** | Misconfigurations, exposed ports, missing encryption |
| Dockerfile | **Hadolint** | Dockerfile best practices, security anti-patterns |

---

## Semgrep

Semgrep is the most versatile SAST tool — it has rules for 30+ languages and frameworks, runs in milliseconds, and you can write custom rules in YAML.

```bash
# ── Install ────────────────────────────────────────────────────────────────────
pip install semgrep
# or:
brew install semgrep

# ── Run with community rule packs ─────────────────────────────────────────────
semgrep --config auto .                          # auto-select rules for detected languages
semgrep --config p/owasp-top-ten .              # OWASP Top 10 rules
semgrep --config p/secrets .                    # secret detection
semgrep --config p/python .                     # Python security rules
semgrep --config p/nodejs .                     # Node.js rules
semgrep --config p/golang .                     # Go security rules
semgrep --config p/docker .                     # Dockerfile rules
semgrep --config p/terraform .                  # Terraform misconfigs
semgrep --config p/kubernetes .                 # Kubernetes manifest checks

# ── Output formats ─────────────────────────────────────────────────────────────
semgrep --config auto . --output results.json --json   # JSON for CI processing
semgrep --config auto . --sarif > results.sarif        # SARIF for GitHub Code Scanning
semgrep --config auto . --text                         # human-readable

# ── Ignore files/paths ────────────────────────────────────────────────────────
# .semgrepignore (same syntax as .gitignore)
# node_modules/
# dist/
# **/*.test.js
# vendor/
```

### Writing Custom Semgrep Rules

```yaml
# rules/no-hardcoded-secrets.yaml
rules:
  - id: no-hardcoded-aws-key
    patterns:
      - pattern: |
          $VAR = "AKIA..."
      - pattern: |
          $VAR = "ASIA..."
    message: |
      Hardcoded AWS access key detected in $VAR.
      Use environment variables or AWS IAM roles instead.
    languages: [python, javascript, typescript, go]
    severity: ERROR
    metadata:
      cwe: CWE-798
      owasp: A02:2021 - Cryptographic Failures

  - id: sql-string-concat
    patterns:
      - pattern: |
          $QUERY = "SELECT ... " + $INPUT
      - pattern: |
          cursor.execute("SELECT ..." + $INPUT)
    message: |
      SQL query built with string concatenation — SQL injection risk.
      Use parameterised queries: cursor.execute("SELECT ... WHERE id = %s", [id])
    languages: [python]
    severity: ERROR
    metadata:
      cwe: CWE-89

  - id: weak-random-crypto
    pattern-either:
      - pattern: random.random()
      - pattern: random.randint(...)
      - pattern: random.choice(...)
    message: |
      random module is not cryptographically secure.
      Use secrets.token_hex() or secrets.choice() for security-sensitive code.
    languages: [python]
    severity: WARNING
    paths:
      include:
        - "**/auth/**"
        - "**/token*"
        - "**/crypto*"

# Run custom rules:
# semgrep --config rules/ src/
```

---

## CodeQL (GitHub Native)

CodeQL performs deep semantic analysis — it builds a database of your code and runs queries against it. It tracks data flow across function calls, which finds vulnerabilities that pattern-matching tools miss.

```yaml
# .github/workflows/codeql.yml
name: CodeQL Analysis

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * 1'   # weekly scan on Monday at 2 AM

jobs:
  analyze:
    name: Analyze (${{ matrix.language }})
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write   # required to upload SARIF results

    strategy:
      fail-fast: false
      matrix:
        language: [javascript, python, go]
        # Full list: cpp, csharp, go, java, javascript, python, ruby, swift

    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}
          # Use extended queries for more coverage (slower):
          queries: security-extended
          # Or: security-and-quality

      # For compiled languages (Go, Java, C++), CodeQL must observe the build:
      - name: Build (Go only)
        if: matrix.language == 'go'
        run: go build ./...

      - name: Autobuild
        if: matrix.language != 'go'
        uses: github/codeql-action/autobuild@v3

      - name: Perform Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: /language:${{ matrix.language }}
          # Upload SARIF to GitHub Security tab:
          upload: true
```

---

## Bandit (Python)

```bash
# ── Install and run ────────────────────────────────────────────────────────────
pip install bandit

bandit -r src/                         # scan src/ recursively
bandit -r src/ -l                      # low severity and above (default: all)
bandit -r src/ -ll                     # medium and above
bandit -r src/ -lll                    # high severity only
bandit -r src/ -x tests/,migrations/   # exclude directories
bandit -r src/ -f json -o bandit.json  # JSON output for CI

# ── Key checks Bandit runs ────────────────────────────────────────────────────
# B101: assert statement usage (removed in optimised Python)
# B102: use of exec()
# B105-107: hardcoded passwords
# B301-305: pickle, yaml.load (use yaml.safe_load), marshal
# B307: use of eval()
# B311: use of random (not cryptographically secure)
# B324: use of md5/sha1 for security (weak hashing)
# B501-509: TLS/SSL issues (unverified context, old protocols)
# B601-612: shell injection risks (subprocess with shell=True)

# ── CI integration ────────────────────────────────────────────────────────────
# In a GitHub Actions step:
- name: Bandit security scan
  run: |
    pip install bandit
    bandit -r src/ -ll -f json -o bandit-report.json || true
    bandit -r src/ -ll    # fail CI on medium/high findings
```

---

## gosec (Go)

```bash
# ── Install ────────────────────────────────────────────────────────────────────
go install github.com/securego/gosec/v2/cmd/gosec@latest

# ── Run ────────────────────────────────────────────────────────────────────────
gosec ./...                             # scan all packages
gosec -severity medium ./...            # only medium and above
gosec -exclude=G104,G304 ./...          # exclude specific rules
gosec -fmt json -out report.json ./...  # JSON output
gosec -fmt sarif -out report.sarif ./.. # SARIF for GitHub

# ── Key rules ─────────────────────────────────────────────────────────────────
# G101: hardcoded credentials
# G104: errors unhandled  (err := something)
# G106: use of ssh.InsecureIgnoreHostKey
# G107: URL provided to HTTP request as a taint variable (SSRF)
# G115: potential integer overflow on type conversion
# G201-203: SQL injection
# G304-307: file path manipulation
# G401-403: weak cryptography (DES, RC4, MD5, SHA1)
# G501: import of blacklisted crypto packages
```

---

## ESLint Security (JavaScript/TypeScript)

```bash
npm install --save-dev \
  eslint \
  eslint-plugin-security \
  eslint-plugin-no-secrets \
  @typescript-eslint/parser \
  @typescript-eslint/eslint-plugin
```

```js
// eslint.config.js (flat config, ESLint 9+)
import security from 'eslint-plugin-security';
import noSecrets from 'eslint-plugin-no-secrets';
import tsParser from '@typescript-eslint/parser';

export default [
  {
    files: ['**/*.{js,ts,mjs}'],
    languageOptions: { parser: tsParser },
    plugins: { security, 'no-secrets': noSecrets },
    rules: {
      // Security plugin rules:
      'security/detect-eval-with-expression':       'error',
      'security/detect-non-literal-fs-filename':    'error',  // path traversal
      'security/detect-non-literal-regexp':         'warn',   // ReDoS
      'security/detect-object-injection':           'warn',   // prototype pollution
      'security/detect-possible-timing-attacks':    'warn',
      'security/detect-pseudoRandomBytes':          'error',  // crypto.pseudoRandomBytes
      'security/detect-sql-literal-injection':      'error',

      // No hardcoded secrets:
      'no-secrets/no-secrets': ['error', { tolerance: 4.5 }],

      // Core dangerous patterns:
      'no-eval':        'error',
      'no-new-func':    'error',
      'no-implied-eval': 'error',
    },
  },
];
```

---

## Hadolint (Dockerfile)

```bash
# ── Install ────────────────────────────────────────────────────────────────────
brew install hadolint
# or Docker:
docker run --rm -i hadolint/hadolint < Dockerfile

# ── Run ────────────────────────────────────────────────────────────────────────
hadolint Dockerfile
hadolint --format json Dockerfile > hadolint.json
hadolint --ignore DL3008 Dockerfile   # ignore specific rule
hadolint --failure-threshold warning  # fail on warning+

# ── Key rules ─────────────────────────────────────────────────────────────────
# DL3000: MAINTAINER is deprecated — use LABEL
# DL3007: pin base image tag (not :latest)
# DL3008: apt-get packages should be pinned to version
# DL3009: delete apt-get lists after install (reduces image size)
# DL3020: use COPY not ADD for local files
# DL3025: use shell form for ENTRYPOINT (not array) — blocks signal propagation
# SC2086: quote your shell variables to prevent word splitting

# ── .hadolint.yaml config ─────────────────────────────────────────────────────
# .hadolint.yaml:
failure-threshold: warning
ignore:
  - DL3008    # we pin elsewhere
trustedRegistries:
  - registry.example.com
  - gcr.io
```

---

## Checkov (IaC Scanning)

```bash
# ── Install ────────────────────────────────────────────────────────────────────
pip install checkov

# ── Scan different IaC types ──────────────────────────────────────────────────
checkov -d .                           # auto-detect all IaC in directory
checkov -d ./terraform --framework terraform
checkov -d ./k8s       --framework kubernetes
checkov -f Dockerfile  --framework dockerfile
checkov -d .           --framework github_actions

# ── Output ────────────────────────────────────────────────────────────────────
checkov -d . --output json > checkov.json
checkov -d . --output sarif > checkov.sarif
checkov -d . --compact                 # compact human-readable output

# ── Skip specific checks ──────────────────────────────────────────────────────
checkov -d . --skip-check CKV_K8S_14,CKV_K8S_43

# ── Key checks ────────────────────────────────────────────────────────────────
# CKV_K8S_14: Image tag should be pinned (not :latest)
# CKV_K8S_30: Do not admit root containers
# CKV_K8S_37: Minimise the admission of containers with added capabilities
# CKV_K8S_43: Image should use digest (not just tag)
# CKV_AWS_5:  Ensure S3 bucket has access control and versioning
# CKV_TF_1:  Ensure Terraform module sources use a commit hash
```

---

## CI Integration: Full SAST Pipeline

```yaml
# .github/workflows/sast.yml
name: SAST

on:
  pull_request:
  push:
    branches: [main]

jobs:
  semgrep:
    name: Semgrep
    runs-on: ubuntu-latest
    container:
      image: returntocorp/semgrep
    steps:
      - uses: actions/checkout@v4
      - run: semgrep ci --sarif > semgrep.sarif
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: semgrep.sarif

  bandit:
    name: Bandit (Python)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install bandit
      - run: bandit -r src/ -ll -f sarif -o bandit.sarif || true
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: bandit.sarif

  iac-scan:
    name: IaC (Checkov)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          soft_fail: false
          output_format: sarif
          output_file_path: checkov.sarif
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: checkov.sarif
```