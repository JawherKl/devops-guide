# ⚙️ Bash Automation

> Real DevOps automation with Bash: deployment scripts, health checks, log management, Docker/Kubernetes helpers, and CI integration patterns. Every script here is production-ready — with error handling, logging, and retry logic built in.

---

## Deployment Script

```bash
#!/usr/bin/env bash
# deploy.sh — zero-downtime application deployment
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
APP_NAME="${APP_NAME:-myapp}"
REGISTRY="${REGISTRY:-registry.example.com}"
ENVIRONMENT="${1:?Usage: $0 <environment> <image_tag>}"
IMAGE_TAG="${2:?Usage: $0 <environment> <image_tag>}"
NAMESPACE="${NAMESPACE:-$APP_NAME}"
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-300}"

# ── Logging ───────────────────────────────────────────────────────────────────
log()  { printf '\033[0;32m[%s] INFO  %s\033[0m\n' "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '\033[1;33m[%s] WARN  %s\033[0m\n' "$(date '+%H:%M:%S')" "$*" >&2; }
die()  { printf '\033[0;31m[%s] ERROR %s\033[0m\n' "$(date '+%H:%M:%S')" "$*" >&2; exit 1; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────
require_commands() {
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || die "Required: $cmd not found"
    done
}
require_commands kubectl docker helm

# Verify image exists before deploying:
log "Verifying image: $REGISTRY/$APP_NAME:$IMAGE_TAG"
docker manifest inspect "$REGISTRY/$APP_NAME:$IMAGE_TAG" &>/dev/null \
    || die "Image not found: $REGISTRY/$APP_NAME:$IMAGE_TAG"

# Verify kubectl context:
CURRENT_CTX=$(kubectl config current-context)
log "Kubernetes context: $CURRENT_CTX"
[[ "$ENVIRONMENT" == "production" && "$CURRENT_CTX" != *"prod"* ]] \
    && die "Production deploy requires prod context, got: $CURRENT_CTX"

# ── Deploy ────────────────────────────────────────────────────────────────────
log "Deploying $APP_NAME:$IMAGE_TAG to $ENVIRONMENT ($NAMESPACE)"

kubectl set image deployment/"$APP_NAME" \
    "$APP_NAME=$REGISTRY/$APP_NAME:$IMAGE_TAG" \
    -n "$NAMESPACE"

# ── Wait for rollout ──────────────────────────────────────────────────────────
log "Waiting for rollout (timeout: ${DEPLOY_TIMEOUT}s)"
if ! kubectl rollout status deployment/"$APP_NAME" \
        -n "$NAMESPACE" \
        --timeout="${DEPLOY_TIMEOUT}s"; then
    warn "Rollout failed — initiating rollback"
    kubectl rollout undo deployment/"$APP_NAME" -n "$NAMESPACE"
    kubectl rollout status deployment/"$APP_NAME" -n "$NAMESPACE" --timeout=120s \
        || warn "Rollback also failed — manual intervention required"
    die "Deployment failed for $APP_NAME:$IMAGE_TAG"
fi

# ── Verify health ─────────────────────────────────────────────────────────────
log "Verifying deployment health"
READY=$(kubectl get deployment "$APP_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.status.readyReplicas}')
DESIRED=$(kubectl get deployment "$APP_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.spec.replicas}')

[[ "$READY" -eq "$DESIRED" ]] || die "Only $READY/$DESIRED replicas ready"

log "✓ Deployment complete: $APP_NAME:$IMAGE_TAG → $ENVIRONMENT ($READY/$DESIRED replicas)"
```

---

## Health Check Script

```bash
#!/usr/bin/env bash
# healthcheck.sh — multi-endpoint health verification with alerting
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
ENDPOINTS=(
    "https://api.example.com/health"
    "https://api.example.com/ready"
    "https://www.example.com/"
)
TIMEOUT=10
MAX_RETRIES=3
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
alert() {
    local msg="$1"
    log "ALERT: $msg"
    [[ -n "$SLACK_WEBHOOK" ]] && \
        curl -sf -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 $msg\"}" "$SLACK_WEBHOOK" || true
    [[ -n "$ALERT_EMAIL" ]] && \
        echo "$msg" | mail -s "Health Check Alert" "$ALERT_EMAIL" || true
}

# ── HTTP health check ─────────────────────────────────────────────────────────
check_endpoint() {
    local url="$1"
    local attempt=1
    local http_code
    local response_time

    while (( attempt <= MAX_RETRIES )); do
        read -r http_code response_time < <(
            curl -sf -o /dev/null \
                -w "%{http_code} %{time_total}" \
                --connect-timeout "$TIMEOUT" \
                --max-time "$TIMEOUT" \
                "$url" 2>/dev/null || echo "000 0"
        )

        if [[ "$http_code" =~ ^2 ]]; then
            printf '  ✓ %-50s %s ms\n' "$url" "$(echo "$response_time * 1000" | bc | cut -d. -f1)"
            return 0
        fi

        warn "  ✗ $url → HTTP $http_code (attempt $attempt/$MAX_RETRIES)"
        (( attempt++ ))
        sleep 2
    done

    alert "Endpoint DOWN: $url (HTTP $http_code after $MAX_RETRIES attempts)"
    return 1
}

# ── Port check ────────────────────────────────────────────────────────────────
check_port() {
    local host="$1" port="$2"
    if nc -z -w "$TIMEOUT" "$host" "$port" 2>/dev/null; then
        printf '  ✓ %s:%s\n' "$host" "$port"
        return 0
    else
        alert "Port unreachable: $host:$port"
        return 1
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
log "Starting health checks"
failed=0

for url in "${ENDPOINTS[@]}"; do
    check_endpoint "$url" || (( failed++ ))
done

# Check critical ports:
for host_port in "db.internal:5432" "redis.internal:6379" "kafka.internal:9092"; do
    IFS=: read -r host port <<< "$host_port"
    check_port "$host" "$port" || (( failed++ ))
done

if (( failed > 0 )); then
    log "❌ $failed check(s) failed"
    exit 1
else
    log "✓ All checks passed"
fi
```

---

## Log Rotation & Archiving

```bash
#!/usr/bin/env bash
# log-rotate.sh — custom log rotation for applications without logrotate
set -euo pipefail

LOG_DIR="${LOG_DIR:-/var/log/myapp}"
ARCHIVE_DIR="${ARCHIVE_DIR:-/var/log/myapp/archive}"
MAX_SIZE_MB="${MAX_SIZE_MB:-100}"
KEEP_DAYS="${KEEP_DAYS:-30}"
APP_PIDFILE="${APP_PIDFILE:-/run/myapp.pid}"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

mkdir -p "$ARCHIVE_DIR"

rotate_log() {
    local logfile="$1"
    local basename size_mb timestamp archive_name

    basename="$(basename "$logfile" .log)"
    size_mb=$(( $(stat -c%s "$logfile") / 1048576 ))

    [[ $size_mb -lt $MAX_SIZE_MB ]] && return 0   # under limit, skip

    timestamp=$(date '+%Y%m%d-%H%M%S')
    archive_name="${ARCHIVE_DIR}/${basename}-${timestamp}.log.gz"

    log "Rotating $logfile ($size_mb MB) → $archive_name"

    # Copy + compress (not move — avoids brief gap in app logging)
    gzip -c "$logfile" > "$archive_name"

    # Signal app to reopen log file (SIGUSR1 = reopen logs for most apps)
    if [[ -f "$APP_PIDFILE" ]]; then
        local pid
        pid=$(cat "$APP_PIDFILE")
        kill -USR1 "$pid" 2>/dev/null && log "Signalled PID $pid to reopen logs"
        sleep 1
    fi

    # Truncate the live log (preserves file descriptor open by app)
    : > "$logfile"
    log "Truncated $logfile"
}

# Rotate oversized logs:
while IFS= read -r logfile; do
    rotate_log "$logfile"
done < <(find "$LOG_DIR" -maxdepth 1 -name "*.log" -type f)

# Delete archives older than KEEP_DAYS:
old_count=$(find "$ARCHIVE_DIR" -name "*.log.gz" -mtime +"$KEEP_DAYS" | wc -l)
if (( old_count > 0 )); then
    log "Deleting $old_count archives older than ${KEEP_DAYS} days"
    find "$ARCHIVE_DIR" -name "*.log.gz" -mtime +"$KEEP_DAYS" -delete
fi

log "Log rotation complete"
```

---

## Docker & Kubernetes Helpers

```bash
#!/usr/bin/env bash
# k8s-helpers.sh — reusable functions for Kubernetes automation

# ── Wait for deployment ready ─────────────────────────────────────────────────
k8s_wait_ready() {
    local namespace="$1" deployment="$2" timeout="${3:-120}"
    kubectl rollout status deployment/"$deployment" \
        -n "$namespace" --timeout="${timeout}s"
}

# ── Get all pod logs from a deployment (all replicas) ────────────────────────
k8s_logs_all() {
    local namespace="$1" deployment="$2"
    kubectl get pods -n "$namespace" \
        -l "app=$deployment" \
        -o jsonpath='{.items[*].metadata.name}' \
    | tr ' ' '\n' \
    | xargs -I{} kubectl logs {} -n "$namespace" --tail=100
}

# ── Scale deployment and wait ─────────────────────────────────────────────────
k8s_scale() {
    local namespace="$1" deployment="$2" replicas="$3"
    kubectl scale deployment/"$deployment" \
        --replicas="$replicas" \
        -n "$namespace"
    k8s_wait_ready "$namespace" "$deployment"
}

# ── Execute a command in the first pod of a deployment ────────────────────────
k8s_exec() {
    local namespace="$1" deployment="$2"
    shift 2
    local pod
    pod=$(kubectl get pods -n "$namespace" \
        -l "app=$deployment" \
        -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -it "$pod" -n "$namespace" -- "$@"
}

# ── Docker cleanup ────────────────────────────────────────────────────────────
docker_cleanup() {
    log "Cleaning Docker resources"
    docker system prune -f --volumes               # remove stopped containers, unused images
    docker image prune -a -f --filter "until=720h" # remove images not used in 30 days
    docker volume prune -f                          # remove unused volumes
    log "Docker cleanup complete. Disk: $(df -h /var/lib/docker | tail -1 | awk '{print $5}')"
}

# ── Build, tag, push ──────────────────────────────────────────────────────────
docker_build_push() {
    local image_name="$1"
    local registry="$2"
    local tag="${3:-latest}"
    local git_sha
    git_sha=$(git rev-parse --short HEAD)

    log "Building $image_name:$tag"
    docker build \
        --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --build-arg GIT_SHA="$git_sha" \
        --cache-from "$registry/$image_name:latest" \
        -t "$registry/$image_name:$tag" \
        -t "$registry/$image_name:$git_sha" \
        .

    log "Pushing $registry/$image_name:$tag"
    docker push "$registry/$image_name:$tag"
    docker push "$registry/$image_name:$git_sha"
}
```

---

## Backup Script

```bash
#!/usr/bin/env bash
# backup.sh — database and file backup with S3 upload
set -euo pipefail

DB_HOST="${DB_HOST:?}"
DB_NAME="${DB_NAME:?}"
DB_USER="${DB_USER:?}"
DB_PASSWORD="${DB_PASSWORD:?}"
S3_BUCKET="${S3_BUCKET:?}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die()  { log "ERROR: $*" >&2; exit 1; }

mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
DUMP_FILE="$BACKUP_DIR/${DB_NAME}-${TIMESTAMP}.sql.gz"

# ── Dump database ─────────────────────────────────────────────────────────────
log "Dumping $DB_NAME from $DB_HOST"
PGPASSWORD="$DB_PASSWORD" pg_dump \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --no-password \
    --verbose \
    2>"$BACKUP_DIR/dump.log" \
| gzip > "$DUMP_FILE"

DUMP_SIZE=$(du -sh "$DUMP_FILE" | cut -f1)
log "Dump complete: $DUMP_FILE ($DUMP_SIZE)"

# ── Verify integrity ─────────────────────────────────────────────────────────
log "Verifying dump integrity"
gunzip -t "$DUMP_FILE" || die "Dump file corrupted"

# ── Upload to S3 ──────────────────────────────────────────────────────────────
S3_KEY="backups/postgres/${DB_NAME}/${TIMESTAMP}.sql.gz"
log "Uploading to s3://$S3_BUCKET/$S3_KEY"
aws s3 cp "$DUMP_FILE" "s3://$S3_BUCKET/$S3_KEY" \
    --storage-class STANDARD_IA \
    --sse AES256

# ── Clean up old local backups ────────────────────────────────────────────────
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -delete
log "Removed local backups older than $RETENTION_DAYS days"

# ── Clean up old S3 backups (lifecycle policy preferred, but this works too) ──
log "Cleaning S3 backups older than $RETENTION_DAYS days"
aws s3 ls "s3://$S3_BUCKET/backups/postgres/${DB_NAME}/" \
| awk '{print $4}' \
| while IFS= read -r key; do
    file_date=$(echo "$key" | grep -oP '\d{8}')
    [[ -z "$file_date" ]] && continue
    cutoff=$(date -d "-${RETENTION_DAYS} days" '+%Y%m%d')
    [[ "$file_date" -lt "$cutoff" ]] && \
        aws s3 rm "s3://$S3_BUCKET/backups/postgres/${DB_NAME}/$key"
done

log "✓ Backup complete: s3://$S3_BUCKET/$S3_KEY"
```