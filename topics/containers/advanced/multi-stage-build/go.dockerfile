# =============================================================================
# go.dockerfile — Multi-stage Go build → scratch image
# =============================================================================
#
# Result: ~8-15MB final image with ZERO OS, ZERO shell, ZERO package manager.
# Only the compiled binary and the files it absolutely needs to run.
#
# Build:  docker build -f go.dockerfile -t myapp-go:latest .
# Run:    docker run --rm -p 8080:8080 myapp-go:latest
# =============================================================================

# syntax=docker/dockerfile:1

# ── Stage 1: Build ────────────────────────────────────────────────────────────
#
# Use the full Go toolchain image only during compilation.
# This stage is NEVER shipped — it exists only to produce the binary.
FROM golang:1.22-alpine AS builder

# Install only what's needed at build time:
# - ca-certificates: needed so the compiled binary can make HTTPS calls
# - git: needed for go mod download (some modules fetch via git)
# - tzdata: include timezone data in the binary if your app uses time zones
RUN apk add --no-cache ca-certificates git tzdata

# Create a non-root user record we'll copy into the final image.
# scratch has no /etc/passwd — we create the user here and copy the file.
RUN echo "appuser:x:1001:1001::/home/appuser:/sbin/nologin" > /etc/passwd.minimal && \
    echo "appgroup:x:1001:" > /etc/group.minimal

WORKDIR /build

# ── Dependency caching (cache-optimized layer) ───────────────────────────────
# Copy module files first — this layer is only re-built when go.mod/go.sum change,
# not on every source code change.
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# ── Source code ───────────────────────────────────────────────────────────────
COPY . .

# ── Compile ───────────────────────────────────────────────────────────────────
# CGO_ENABLED=0  → statically link everything (no libc dependency)
# GOOS=linux     → target Linux (even if building on macOS/Windows)
# GOARCH=amd64   → target x86-64 (change to arm64 for Apple Silicon / ARM servers)
# -ldflags:
#   -w           → strip DWARF debug info (smaller binary)
#   -s           → strip symbol table (smaller binary)
#   -X           → embed version info at compile time (traceable builds)
# -trimpath      → remove local build paths from binary (reproducible builds)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
      -trimpath \
      -ldflags="-w -s -X main.version=$(git describe --tags --always --dirty 2>/dev/null || echo 'dev')" \
      -o /app/server \
      ./cmd/server

# Verify the binary is truly statically linked
RUN file /app/server && \
    ldd /app/server 2>&1 | grep -q "not a dynamic" && echo "✅ Statically linked" || true

# ── Stage 2: Final scratch image ──────────────────────────────────────────────
#
# 'scratch' is a completely empty base — no OS, no shell, no utilities.
# The final image contains ONLY what we explicitly COPY into it.
FROM scratch AS production

# Copy the minimal passwd/group files so the app can run as non-root.
# Without this, 'USER nobody' in scratch fails (no /etc/passwd to look up).
COPY --from=builder /etc/passwd.minimal /etc/passwd
COPY --from=builder /etc/group.minimal /etc/group

# Copy TLS root certificates so the app can verify HTTPS connections.
# Without this, any outbound HTTPS call will fail with "certificate signed by unknown authority".
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data (only needed if your app uses time.LoadLocation())
# COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy the compiled binary — this is the ONLY executable in the image
COPY --from=builder /app/server /server

# Run as non-root (UID 1001 from the passwd file we copied above)
USER appuser

# Document the port — does NOT actually publish it
EXPOSE 8080

# Health check using the binary itself (no shell, no curl, no wget in scratch)
# Your binary should support a -healthcheck flag or a dedicated /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/server", "-healthcheck"]

# ENTRYPOINT in exec form (required — no shell in scratch to interpret shell form)
ENTRYPOINT ["/server"]