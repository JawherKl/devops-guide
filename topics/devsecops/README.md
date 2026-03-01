# 🔐 DevSecOps

<p align="center">
  <img src="https://img.shields.io/badge/Trivy-1904DA?style=for-the-badge&logo=aquasecurity&logoColor=white"/>
  <img src="https://img.shields.io/badge/Snyk-4C4A73?style=for-the-badge&logo=snyk&logoColor=white"/>
  <img src="https://img.shields.io/badge/OWASP-000000?style=for-the-badge&logo=owasp&logoColor=white"/>
  <img src="https://img.shields.io/badge/HashiCorp_Vault-FFEC6E?style=for-the-badge&logo=vault&logoColor=black"/>
  <img src="https://img.shields.io/badge/OPA-7D3F98?style=for-the-badge&logo=openpolicyagent&logoColor=white"/>
  <img src="https://img.shields.io/badge/Semgrep-31B6E7?style=for-the-badge&logoColor=white"/>
</p>

> DevSecOps means security is not a gate at the end of the pipeline — it is woven into every stage. Code is scanned as it is written. Dependencies are checked on every pull request. Container images are scanned before they are pushed. Secrets never touch source code. Infrastructure policies are enforced automatically. This topic covers the full security layer for a modern DevOps pipeline.

---

## The DevSecOps Pipeline

```
Developer writes code
        │
        ▼
┌─────────────────────────────────────────────────────────┐
│  IDE / Pre-commit hooks                                 │
│  • Semgrep / ESLint security rules (SAST)               │
│  • detect-secrets — block credential commits            │
│  • git-secrets — scan for AWS keys, tokens              │
└─────────────────────────────────────────────────────────┘
        │  git push / PR opened
        ▼
┌─────────────────────────────────────────────────────────┐
│  CI Pipeline — Pull Request checks                      │
│  • SAST: CodeQL, Semgrep, Bandit, gosec                 │
│  • Dependency scan: Snyk, npm audit, pip-audit          │
│  • Secret scan: Gitleaks, TruffleHog                    │
│  • IaC scan: Checkov, tfsec (Terraform misconfigs)      │
└─────────────────────────────────────────────────────────┘
        │  merge to main
        ▼
┌─────────────────────────────────────────────────────────┐
│  CI Pipeline — Build & Push                             │
│  • Container image scan: Trivy, Grype                   │
│  • Distroless / minimal base images                     │
│  • Image signing: Cosign + Sigstore                     │
│  • SBOM generation                                      │
└─────────────────────────────────────────────────────────┘
        │  deploy
        ▼
┌─────────────────────────────────────────────────────────┐
│  Runtime / Kubernetes                                   │
│  • Admission control: OPA Gatekeeper, Kyverno           │
│  • Secrets: Vault, Sealed Secrets, External Secrets     │
│  • Network policies: zero-trust pod-to-pod              │
│  • DAST: OWASP ZAP against deployed app                 │
└─────────────────────────────────────────────────────────┘
```

---

## 📋 Files in This Topic

| File | What you'll learn |
|------|-------------------|
| [sast.md](./sast.md) | Static analysis: CodeQL, Semgrep, Bandit, gosec — find bugs before runtime |
| [container-security.md](./container-security.md) | Trivy, Grype, Dockerfile hardening, distroless images, image signing |
| [secrets-management.md](./secrets-management.md) | HashiCorp Vault, SOPS, Sealed Secrets, detect-secrets, Gitleaks |
| [dependency-scanning.md](./dependency-scanning.md) | Snyk, Dependabot, npm audit, pip-audit, OWASP Dependency-Check |
| [dast.md](./dast.md) | OWASP ZAP dynamic scanning, API fuzzing, running DAST in CI |
| [policy-as-code.md](./policy-as-code.md) | OPA Gatekeeper, Kyverno — enforce security policies in Kubernetes |

---

## 🗺️ Learning Path

```
1. secrets-management.md   ← never commit a secret (day-zero practice)
        ↓
2. sast.md                 ← catch vulnerabilities at code-writing time
        ↓
3. dependency-scanning.md  ← audit third-party packages in CI
        ↓
4. container-security.md   ← harden the runtime artifact (image)
        ↓
5. policy-as-code.md       ← enforce rules at cluster admission time
        ↓
6. dast.md                 ← test the running application
```

---

## ⚡ Quick Wins (run today)

```bash
# Scan your current repo for leaked secrets:
docker run --rm -v "$(pwd):/repo" zricethezav/gitleaks detect --source=/repo

# Scan your Dockerfile and Kubernetes manifests for misconfigs:
docker run --rm -v "$(pwd):/src" bridgecrew/checkov -d /src --compact

# Scan a container image for CVEs:
trivy image nginx:latest

# Check npm dependencies for known vulnerabilities:
npm audit --audit-level=high

# Check Python dependencies:
pip-audit

# Scan Terraform configs:
tfsec .
```

---

## 🔗 Related Topics

- [Containers](../containers/) — base image selection, multi-stage builds
- [Orchestration](../orchestration/) — Kubernetes RBAC, network policies
- [CI/CD](../ci-cd/) — integrating all these scans into pipelines
- [Version Control](../version-control/) — branch protection, signed commits
- [Linux](../linux/) — AppArmor, seccomp, capability dropping