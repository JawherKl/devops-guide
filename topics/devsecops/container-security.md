# 🐳 Container Security

> A container image is the atomic unit of deployment. Once it leaves CI and enters production, it is assumed trustworthy. This file covers how to ensure that trust is earned: scanning images for CVEs before pushing, hardening Dockerfiles to minimise the attack surface, and signing images so only verified builds can run.

---

## Trivy — Image & Filesystem Scanner

Trivy is the most widely-adopted container security scanner. It scans OS packages, language dependencies, IaC files, secrets, and Kubernetes manifests in one tool.

```bash
# ── Install ────────────────────────────────────────────────────────────────────
# Ubuntu/Debian:
apt install -y wget apt-transport-https gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | \
  tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | \
  tee /etc/apt/sources.list.d/trivy.list
apt update && apt install trivy

# macOS:
brew install trivy

# Docker (no install needed):
docker run --rm aquasec/trivy image nginx:latest

# ── Scan a container image ─────────────────────────────────────────────────────
trivy image nginx:latest                             # scan latest nginx
trivy image --severity HIGH,CRITICAL nginx:latest    # only high/critical CVEs
trivy image --exit-code 1 --severity CRITICAL nginx:latest  # fail if CRITICAL found
trivy image --ignore-unfixed nginx:latest            # skip CVEs with no fix available

# ── Scan before push (in CI) ──────────────────────────────────────────────────
trivy image \
  --exit-code 1 \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --format table \
  registry.example.com/myapp:${IMAGE_TAG}

# ── Output formats ────────────────────────────────────────────────────────────
trivy image --format json  -o report.json nginx:latest   # JSON (machine-readable)
trivy image --format sarif -o report.sarif nginx:latest  # SARIF (GitHub Security tab)
trivy image --format cyclonedx -o sbom.json nginx:latest # SBOM (CycloneDX)
trivy image --format spdx-json  -o sbom.spdx nginx:latest # SBOM (SPDX)

# ── Scan a local filesystem (not just images) ─────────────────────────────────
trivy fs .                         # scan current directory (deps, secrets, IaC)
trivy fs --security-checks vuln,secret,config .

# ── Scan a running container ──────────────────────────────────────────────────
trivy image --input $(docker save myapp | -) # from docker save output

# ── Scan Kubernetes cluster live resources ────────────────────────────────────
trivy k8s --report summary cluster       # all resources in cluster
trivy k8s --report all --namespace myapp # specific namespace

# ── .trivyignore: suppress known false positives ─────────────────────────────
# .trivyignore:
CVE-2023-12345   # known false positive — not reachable in our code
CVE-2023-67890   # accepted risk — no fix available, mitigated at network level
```

---

## Grype — Alternative Scanner

Grype produces clean output and integrates tightly with Syft for SBOM generation.

```bash
# ── Install ────────────────────────────────────────────────────────────────────
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
brew install grype

# ── Scan ──────────────────────────────────────────────────────────────────────
grype nginx:latest                         # scan image
grype dir:.                                # scan local filesystem
grype --fail-on high nginx:latest          # exit 1 if high/critical found
grype --only-fixed nginx:latest            # only show fixable CVEs
grype -o json nginx:latest > report.json   # JSON output

# ── Generate SBOM with Syft, then scan with Grype ─────────────────────────────
syft packages nginx:latest -o spdx-json > sbom.spdx.json
grype sbom:sbom.spdx.json     # scan the SBOM (faster, reusable)
```

---

## Dockerfile Hardening

A secure Dockerfile reduces the blast radius if a container is compromised.

```dockerfile
# ── GOOD: hardened Dockerfile ────────────────────────────────────────────────

# 1. Pin exact digest (not just tag — tags are mutable)
FROM node:20.11.0-alpine3.19@sha256:f3... AS builder
# At minimum pin the full tag:
# FROM node:20.11.0-alpine3.19

# 2. Multi-stage build — builder stage (has build tools, dev deps)
WORKDIR /build
COPY package*.json ./
RUN npm ci                           # reproducible install
COPY src/ ./src/
RUN npm run build

# 3. Runtime stage — start fresh, copy only what's needed
FROM node:20.11.0-alpine3.19@sha256:f3...
WORKDIR /app

# 4. Create a non-root user before copying files
RUN addgroup --system --gid 1001 appgroup && \
    adduser  --system --uid 1001 --ingroup appgroup appuser

# 5. Copy only the built output (no source, no node_modules for dev deps)
COPY --from=builder --chown=appuser:appgroup /build/dist ./dist
COPY --chown=appuser:appgroup package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# 6. Switch to non-root user
USER appuser

# 7. Expose port (documentation — does not actually publish)
EXPOSE 3000

# 8. Use ENTRYPOINT (not CMD) for the main process — proper signal handling
ENTRYPOINT ["node", "dist/server.js"]

# ── What not to do ────────────────────────────────────────────────────────────
# ❌ FROM ubuntu:latest                    — unpinned, changes without warning
# ❌ RUN apt-get install -y curl wget      — unnecessary tools increase attack surface
# ❌ COPY . .                              — copies .env, .git, secrets
# ❌ USER root (or no USER directive)      — container runs as root
# ❌ RUN npm install (not ci)              — non-reproducible, installs more
# ❌ ENV DB_PASSWORD=secret123             — visible in docker inspect and image layers
# ❌ ADD https://... /tmp/                 — ADD from URL is insecure
```

### .dockerignore

```
# .dockerignore — prevent accidental inclusion of sensitive files
.git/
.gitignore
*.md
docs/
tests/
.env
.env.*
*.pem
*.key
node_modules/
dist/
coverage/
.vscode/
.idea/
Dockerfile*
docker-compose*.yml
```

---

## Distroless Images

Distroless images contain only the application and its runtime dependencies — no shell, no package manager, no OS utilities. The attack surface is minimal.

```dockerfile
# ── Go: smallest possible — static binary + scratch ─────────────────────────
FROM golang:1.22 AS builder
WORKDIR /src
COPY . .
# CGO_ENABLED=0: static binary (no libc dependency)
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app .

FROM scratch                          # empty image — nothing but your binary
COPY --from=builder /app /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
USER 65534:65534                      # nobody:nogroup (numeric — scratch has no /etc/passwd)
ENTRYPOINT ["/app"]

# ── Node.js: Google distroless ────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM gcr.io/distroless/nodejs20-debian12
# No shell, no package manager — only Node.js runtime
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER nonroot                         # distroless provides nonroot user
EXPOSE 3000
CMD ["dist/server.js"]

# ── Python: distroless ────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt
COPY src/ .

FROM gcr.io/distroless/python3-debian12
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY --from=builder /app .
ENV PATH=/root/.local/bin:$PATH
USER nonroot
CMD ["server.py"]
```

---

## Image Signing with Cosign

Signed images allow Kubernetes admission controllers to verify that only images built by your CI pipeline can run in production.

```bash
# ── Install ────────────────────────────────────────────────────────────────────
brew install cosign
# or:
go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# ── Generate a key pair ───────────────────────────────────────────────────────
cosign generate-key-pair                    # → cosign.key + cosign.pub
cosign generate-key-pair --kms awskms:///arn:aws:kms:... # KMS-backed key (recommended)

# ── Sign an image ─────────────────────────────────────────────────────────────
IMAGE="registry.example.com/myapp:v1.2.3"

# Sign by digest (tags are mutable — sign the immutable digest):
IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE")
cosign sign --key cosign.key "$IMAGE_DIGEST"

# Sign with annotations (embed metadata in the signature):
cosign sign --key cosign.key \
  --annotation "git-sha=$(git rev-parse HEAD)" \
  --annotation "built-by=github-actions" \
  --annotation "pipeline-url=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}" \
  "$IMAGE_DIGEST"

# ── Verify a signature ────────────────────────────────────────────────────────
cosign verify --key cosign.pub "$IMAGE"
cosign verify --key cosign.pub \
  --annotations "built-by=github-actions" \
  "$IMAGE"

# ── Keyless signing (Sigstore — no key management) ────────────────────────────
# In GitHub Actions, Sigstore authenticates using the OIDC token automatically:
cosign sign --yes "$IMAGE_DIGEST"
# Verification:
cosign verify \
  --certificate-identity "https://github.com/JawherKl/devops-guide/.github/workflows/build.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "$IMAGE"
```

### CI Pipeline with Scan + Sign

```yaml
# .github/workflows/build-scan-sign.yml
name: Build, Scan & Sign

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build-scan-sign:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write    # required for keyless signing with Sigstore

    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: |
          docker build -t ${{ env.REGISTRY }}/${{ env.IMAGE }}:${{ github.sha }} .

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE }}:${{ github.sha }}
          exit-code: '1'
          severity: HIGH,CRITICAL
          ignore-unfixed: true
          format: sarif
          output: trivy.sarif

      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy.sarif

      - name: Push image
        run: docker push ${{ env.REGISTRY }}/${{ env.IMAGE }}:${{ github.sha }}

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign image (keyless)
        run: |
          IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' \
            ${{ env.REGISTRY }}/${{ env.IMAGE }}:${{ github.sha }})
          cosign sign --yes \
            --annotation "git-sha=${{ github.sha }}" \
            --annotation "build-url=${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}" \
            "$IMAGE_DIGEST"

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE }}:${{ github.sha }}
          artifact-name: sbom.spdx.json
          format: spdx-json
```