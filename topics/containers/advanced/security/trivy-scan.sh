#!/usr/bin/env bash
# =============================================================================
# trivy-scan.sh — Container image vulnerability scanner
# =============================================================================
#
# Usage:
#   ./trivy-scan.sh <image>                    # scan with defaults
#   ./trivy-scan.sh myapp:1.0                  # scan specific image
#   ./trivy-scan.sh myapp:1.0 HIGH             # only HIGH and CRITICAL
#   ./trivy-scan.sh myapp:1.0 CRITICAL strict  # fail on any CRITICAL
#
# Environment variables:
#   TRIVY_EXIT_CODE  — set to 0 to never fail the pipeline (default: 1)
#   TRIVY_FORMAT     — output format: table|json|sarif (default: table)
#   REPORT_DIR       — where to save reports (default: ./trivy-reports)
#
# CI Usage (GitHub Actions example):
#   - name: Scan image
#     run: ./topics/containers/advanced/security/trivy-scan.sh ${{ env.IMAGE_TAG }}
#
# =============================================================================

set -euo pipefail

# ── Arguments ─────────────────────────────────────────────────────────────────
IMAGE="${1:-}"
SEVERITY="${2:-HIGH,CRITICAL}"         # comma-separated: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
MODE="${3:-default}"                   # 'strict' = fail on any finding, 'default' = use exit code

# ── Config ────────────────────────────────────────────────────────────────────
TRIVY_EXIT_CODE="${TRIVY_EXIT_CODE:-1}"
TRIVY_FORMAT="${TRIVY_FORMAT:-table}"
REPORT_DIR="${REPORT_DIR:-./trivy-reports}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Validate input ────────────────────────────────────────────────────────────
if [[ -z "$IMAGE" ]]; then
  error "No image specified."
  echo "Usage: $0 <image[:tag]> [severity] [mode]"
  echo "Example: $0 myapp:1.0 HIGH,CRITICAL strict"
  exit 1
fi

# ── Check Trivy is installed ──────────────────────────────────────────────────
if ! command -v trivy &>/dev/null; then
  warn "Trivy not found. Installing..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin
  success "Trivy installed: $(trivy --version | head -1)"
fi

info "Trivy version: $(trivy --version | head -1)"

# ── Prepare output directory ──────────────────────────────────────────────────
mkdir -p "$REPORT_DIR"
REPORT_BASE="${REPORT_DIR}/$(echo "$IMAGE" | tr '/:' '-')-${TIMESTAMP}"

# ── Scan: OS & language CVEs ──────────────────────────────────────────────────
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Scanning image: ${IMAGE}"
info "Severity filter: ${SEVERITY}"
info "Output format: ${TRIVY_FORMAT}"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCAN_EXIT_CODE=0

# Human-readable table (always printed to terminal)
trivy image \
  --severity "$SEVERITY" \
  --exit-code "$TRIVY_EXIT_CODE" \
  --no-progress \
  --ignore-unfixed \
  --ignorefile ".trivyignore" 2>/dev/null || true \
  "$IMAGE" || SCAN_EXIT_CODE=$?

# JSON report (saved to file for CI artifact upload)
info "Saving JSON report to ${REPORT_BASE}.json"
trivy image \
  --severity "$SEVERITY" \
  --format json \
  --exit-code 0 \
  --no-progress \
  --ignore-unfixed \
  --ignorefile ".trivyignore" 2>/dev/null || true \
  --output "${REPORT_BASE}.json" \
  "$IMAGE" >/dev/null 2>&1

# SARIF report (for GitHub Security tab integration)
info "Saving SARIF report to ${REPORT_BASE}.sarif"
trivy image \
  --severity "$SEVERITY" \
  --format sarif \
  --exit-code 0 \
  --no-progress \
  --ignorefile ".trivyignore" 2>/dev/null || true \
  --output "${REPORT_BASE}.sarif" \
  "$IMAGE" >/dev/null 2>&1

# ── Scan: Dockerfile misconfigurations ───────────────────────────────────────
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Scanning Dockerfile for misconfigurations..."
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CONFIG_EXIT_CODE=0

# Scan the Dockerfile/config files in the current directory
if ls Dockerfile* *.dockerfile 2>/dev/null | head -1 &>/dev/null; then
  trivy config \
    --severity "$SEVERITY" \
    --exit-code 0 \
    . || CONFIG_EXIT_CODE=$?
else
  warn "No Dockerfile found in current directory — skipping config scan"
fi

# ── Generate SBOM (Software Bill of Materials) ────────────────────────────────
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Generating SBOM → ${REPORT_BASE}.sbom.json"
trivy image \
  --format cyclonedx \
  --exit-code 0 \
  --no-progress \
  --output "${REPORT_BASE}.sbom.json" \
  "$IMAGE" >/dev/null 2>&1

success "SBOM saved to ${REPORT_BASE}.sbom.json"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Scan Summary"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Image:        ${IMAGE}"
info "Severity:     ${SEVERITY}"
info "Reports:      ${REPORT_DIR}/"
info "  JSON:       ${REPORT_BASE}.json"
info "  SARIF:      ${REPORT_BASE}.sarif"
info "  SBOM:       ${REPORT_BASE}.sbom.json"

if [[ "$MODE" == "strict" && "$SCAN_EXIT_CODE" -ne 0 ]]; then
  error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  error "SCAN FAILED — vulnerabilities found at severity: ${SEVERITY}"
  error "Fix the CVEs or add acknowledged exceptions to .trivyignore"
  error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit "$SCAN_EXIT_CODE"
elif [[ "$SCAN_EXIT_CODE" -ne 0 ]]; then
  warn "Vulnerabilities found but pipeline is not configured to fail (TRIVY_EXIT_CODE=0)"
  warn "Set TRIVY_EXIT_CODE=1 or use 'strict' mode to enforce clean scans"
else
  success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  success "No ${SEVERITY} vulnerabilities found in ${IMAGE} ✅"
  success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit "$SCAN_EXIT_CODE"