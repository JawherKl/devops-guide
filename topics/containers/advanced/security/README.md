# Container Security

> Harden containers from the inside out — non-root users, Linux capabilities, read-only filesystems, CVE scanning, and secrets management. These are not optional in production.

---

## 🔒 Security Model: Defense in Depth

Container security works in layers. Each layer compensates for weaknesses in the others — if one is bypassed, the others remain.

```
┌──────────────────────────────────────────────────────────┐
│  Layer 5 — Runtime constraints                           │
│  read_only FS · no-new-privileges · pids-limit           │
├──────────────────────────────────────────────────────────┤
│  Layer 4 — Linux capabilities                            │
│  cap_drop: ALL · add only NET_BIND_SERVICE if needed     │
├──────────────────────────────────────────────────────────┤
│  Layer 3 — Non-root user                                 │
│  UID 1001 · explicit GID · no sudo                       │
├──────────────────────────────────────────────────────────┤
│  Layer 2 — CVE scanning                                  │
│  Trivy on every build · fail CI on HIGH/CRITICAL         │
├──────────────────────────────────────────────────────────┤
│  Layer 1 — Minimal base image                            │
│  Alpine · distroless · scratch (smallest attack surface) │
└──────────────────────────────────────────────────────────┘
```

---

## 📁 Files in This Section

| File | Purpose |
|------|---------|
| `hardened.dockerfile` | Reference Dockerfile applying every security layer |
| `trivy-scan.sh` | CI-ready scan script (CVE + config + SBOM) |
| `.trivyignore` | Documented CVE exception template |

---

## 👤 Layer 3: Non-Root User

Running as root inside a container means a container escape gives an attacker root on the host. Always run as a non-root user.

```dockerfile
# Alpine
RUN addgroup -g 1001 -S appgroup && \
    adduser  -u 1001 -S appuser -G appgroup -s /sbin/nologin
USER 1001:1001   # use UID/GID, not name — required for Kubernetes SecurityContext

# Debian/Ubuntu
RUN groupadd -r -g 1001 appgroup && \
    useradd  -r -u 1001 -g appgroup -s /sbin/nologin appuser
USER 1001:1001
```

```bash
# Verify at runtime
docker run --rm myapp:hardened whoami      # → appuser ✅
docker run --rm myapp:hardened id          # → uid=1001(appuser) gid=1001(appgroup)
docker run --rm myapp:hardened cat /etc/shadow  # → Permission denied ✅
```

---

## 🔧 Layer 4: Linux Capabilities

By default, Docker grants containers a set of ~15 Linux capabilities. Most apps need none of them. Drop everything, add only what your specific app requires.

```yaml
# compose.yml — runtime capability enforcement
services:
  api:
    cap_drop:
      - ALL                    # drop the entire default set
    cap_add: []                # add nothing (most web apps need no capabilities)
      # - NET_BIND_SERVICE     # uncomment ONLY if binding to port < 1024
    security_opt:
      - no-new-privileges:true # prevent setuid binaries from escalating
```

```bash
# Verify capabilities from inside a running container
docker exec myapp-api capsh --print
# Should show: Current: =  (empty — no capabilities)
```

### Capability reference for common apps

| App type | Capabilities needed |
|----------|-------------------|
| Most web APIs | None |
| App binding port 80/443 | `NET_BIND_SERVICE` |
| App using ping/raw sockets | `NET_RAW` (avoid if possible) |
| App managing network interfaces | `NET_ADMIN` (rare, justify carefully) |

---

## 🗂️ Layer 5: Runtime Constraints

```yaml
# compose.yml — full production hardening
services:
  api:
    read_only: true            # root filesystem is read-only
    tmpfs:
      - /tmp:size=50m,mode=1777   # writable in-memory temp
      - /run:size=10m
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
        reservations:
          memory: 128M
          cpus: "0.25"
    # Prevent fork bombs
    ulimits:
      nproc: 100
```

```bash
# Test read-only filesystem
docker run --rm --read-only myapp:hardened touch /test
# touch: /test: Read-only file system ✅

# Verify no-new-privileges blocks setuid escalation
docker run --rm --security-opt no-new-privileges:true myapp:hardened su - root
# su: must be run from a terminal / permission denied ✅
```

---

## 🔍 Layer 2: CVE Scanning with Trivy

```bash
# Quick scan (table output)
./trivy-scan.sh myapp:1.0

# Strict mode — fails the script if HIGH/CRITICAL found
./trivy-scan.sh myapp:1.0 HIGH,CRITICAL strict

# Scan with custom severity
./trivy-scan.sh myapp:1.0 CRITICAL strict

# Scan just the Dockerfile for misconfigurations (no image needed)
trivy config ./hardened.dockerfile
```

### Integrate into CI (GitHub Actions)

```yaml
# .github/workflows/build.yml
- name: Build image
  run: docker build -f hardened.dockerfile -t myapp:${{ github.sha }} .

- name: Scan for vulnerabilities
  run: |
    chmod +x ./topics/containers/advanced/security/trivy-scan.sh
    ./topics/containers/advanced/security/trivy-scan.sh myapp:${{ github.sha }} HIGH,CRITICAL strict

- name: Upload SARIF to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: trivy-reports/
  if: always()   # upload even if scan fails, so you can see the report
```

---

## 🔑 Secrets Management

```dockerfile
# ❌ NEVER — secrets baked into image layers (visible in `docker history`)
ENV API_KEY=secret123
RUN curl -H "Authorization: $API_KEY" https://api.example.com
COPY ./secrets/api.key /app/
```

```dockerfile
# ✅ BuildKit secrets — used at build time, never stored in any layer
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm install

# Build with:
# DOCKER_BUILDKIT=1 docker build --secret id=npm_token,env=NPM_TOKEN .
```

```yaml
# ✅ Runtime secrets via Docker Swarm secrets
# Mounted as files at /run/secrets/<name> — not in environment variables
services:
  api:
    secrets:
      - db_password
    # Read in app code: fs.readFileSync('/run/secrets/db_password', 'utf8').trim()

secrets:
  db_password:
    external: true   # created with: echo "secret" | docker secret create db_password -
```

---

## 🧪 Labs

### Lab 1: Build and verify the hardened image

```bash
cd advanced/security/

# Build
docker build -f hardened.dockerfile -t myapp:hardened .

# Verify non-root
docker run --rm myapp:hardened id
# uid=1001(appuser) gid=1001(appgroup) ✅

# Verify no shell escalation
docker run --rm --cap-drop ALL --security-opt no-new-privileges:true \
  myapp:hardened su -
# su: permission denied ✅
```

### Lab 2: CVE scan comparison

```bash
# Scan an old image (lots of CVEs)
./trivy-scan.sh nginx:1.19 HIGH,CRITICAL

# Scan a current hardened image (far fewer)
./trivy-scan.sh nginx:1.25-alpine HIGH,CRITICAL

# Compare the counts
echo "Old image CVEs vs current alpine — significant difference"
```

### Lab 3: Read-only filesystem in practice

```bash
# This should FAIL — correct behavior for hardened container
docker run --rm \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  myapp:hardened \
  sh -c "echo 'hack' > /app/src/index.js"
# sh: can't create /app/src/index.js: Read-only file system ✅

# Writing to /tmp should SUCCEED (that's the safe writable space)
docker run --rm \
  --read-only \
  --tmpfs /tmp \
  myapp:hardened \
  sh -c "echo 'temp' > /tmp/test && cat /tmp/test"
# temp ✅
```

---

## ✅ Security Checklist

- [ ] Base image pinned to specific digest (not just a tag)
- [ ] Minimal base image used (alpine, distroless, or scratch)
- [ ] Non-root user defined with explicit UID/GID (1001+)
- [ ] `USER 1001:1001` at the end of Dockerfile
- [ ] `cap_drop: [ALL]` in compose.yml for all services
- [ ] `security_opt: [no-new-privileges:true]` in compose.yml
- [ ] `read_only: true` with `tmpfs` mounts for writable dirs
- [ ] `pids-limit` set to prevent fork bombs
- [ ] Memory and CPU limits defined for all services
- [ ] Trivy scan runs in CI pipeline (not just locally)
- [ ] CI fails on HIGH or CRITICAL CVEs (`--exit-code 1`)
- [ ] `.trivyignore` has documented, time-limited exceptions only
- [ ] No secrets in Dockerfile ENV, image layers, or compose files
- [ ] BuildKit `--secret` used for build-time credentials
- [ ] Docker Swarm secrets or Vault used for runtime credentials
- [ ] SBOM generated and archived as a CI artifact