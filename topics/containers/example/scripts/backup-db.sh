#!/usr/bin/env bash
# =============================================================================
# scripts/backup-db.sh — PostgreSQL backup and restore for the example stack
# =============================================================================
#
# Usage:
#   ./scripts/backup-db.sh backup           # create timestamped backup
#   ./scripts/backup-db.sh restore <file>   # restore from a backup file
#   ./scripts/backup-db.sh list             # list available backups
#   ./scripts/backup-db.sh clean            # remove backups older than 7 days
#
# Backups are saved to: ./backups/
# File format:          taskapp-YYYYMMDD-HHMMSS.sql.gz
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'
BLUE='\033[0;34m';  YELLOW='\033[1;33m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Config (read from .env if present) ───────────────────────────────────────
if [[ -f .env ]]; then
  # shellcheck source=/dev/null
  set -a; source .env; set +a
fi

POSTGRES_DB="${POSTGRES_DB:-taskdb}"
POSTGRES_USER="${POSTGRES_USER:-appuser}"
CONTAINER="${BACKUP_CONTAINER:-taskapp-postgres}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

mkdir -p "$BACKUP_DIR"

CMD="${1:-help}"
shift || true

# ── backup ────────────────────────────────────────────────────────────────────
do_backup() {
  # Verify container is running
  docker inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null | \
    grep -q "running" || error "Container '$CONTAINER' is not running. Is the stack up?"

  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  FILENAME="${POSTGRES_DB}-${TIMESTAMP}.sql.gz"
  FILEPATH="${BACKUP_DIR}/${FILENAME}"

  info "Starting backup of '$POSTGRES_DB' from container '$CONTAINER'..."
  info "Output: $FILEPATH"

  docker exec "$CONTAINER" \
    pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    --no-owner \
    --no-acl \
    --format=plain \
    --encoding=UTF8 \
    | gzip > "$FILEPATH"

  SIZE=$(du -sh "$FILEPATH" | cut -f1)
  success "Backup complete: $FILENAME ($SIZE)"

  # Verify the backup is a valid gzip file
  if gzip -t "$FILEPATH" 2>/dev/null; then
    success "Backup integrity verified (gzip checksum ok)"
  else
    error "Backup file appears corrupted — verify manually: $FILEPATH"
  fi

  echo ""
  echo "  To restore this backup:"
  echo "  ./scripts/backup-db.sh restore $FILENAME"
}

# ── restore ───────────────────────────────────────────────────────────────────
do_restore() {
  local file="${1:-}"
  [[ -z "$file" ]] && error "Usage: $0 restore <filename.sql.gz>"

  # Accept filename only or full path
  [[ "$file" == */* ]] || file="${BACKUP_DIR}/${file}"
  [[ -f "$file" ]]     || error "Backup file not found: $file"

  warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  warn "  ⚠  This will OVERWRITE all data in '$POSTGRES_DB'."
  warn "     File: $file"
  warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -r -p "  Type 'yes' to confirm: " confirm
  [[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 0; }

  info "Restoring '$POSTGRES_DB' from $file..."

  # Drop and recreate the database
  docker exec "$CONTAINER" \
    psql -U "$POSTGRES_USER" -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${POSTGRES_DB}' AND pid <> pg_backend_pid();" \
    > /dev/null 2>&1 || true

  docker exec "$CONTAINER" \
    psql -U "$POSTGRES_USER" -d postgres \
    -c "DROP DATABASE IF EXISTS ${POSTGRES_DB}; CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER};" \
    > /dev/null

  # Restore from backup
  gunzip -c "$file" | \
    docker exec -i "$CONTAINER" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" --quiet

  success "Restore complete from: $(basename "$file")"
}

# ── list ──────────────────────────────────────────────────────────────────────
do_list() {
  info "Available backups in $BACKUP_DIR/:"
  echo ""
  if ls "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1 &>/dev/null; then
    printf "  %-45s %s\n" "FILE" "SIZE"
    printf "  %-45s %s\n" "────────────────────────────────────────────" "────────"
    ls -lt "$BACKUP_DIR"/*.sql.gz | awk '{printf "  %-45s %s\n", $9, $5}' | \
      sed "s|${BACKUP_DIR}/||"
  else
    warn "No backups found in $BACKUP_DIR"
  fi
  echo ""
}

# ── clean ─────────────────────────────────────────────────────────────────────
do_clean() {
  info "Removing backups older than ${RETENTION_DAYS} days from $BACKUP_DIR/..."
  REMOVED=$(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -print -delete | wc -l)
  success "Removed $REMOVED old backup(s)"
}

# ── help ──────────────────────────────────────────────────────────────────────
do_help() {
  echo ""
  echo "  Usage: $0 <command> [options]"
  echo ""
  echo "  Commands:"
  echo "    backup              Create a timestamped compressed backup"
  echo "    restore <file>      Restore from a backup file (DESTRUCTIVE)"
  echo "    list                List available backup files"
  echo "    clean               Remove backups older than ${RETENTION_DAYS} days"
  echo ""
  echo "  Environment variables (or set in .env):"
  echo "    POSTGRES_DB         Database name (default: taskdb)"
  echo "    POSTGRES_USER       Database user (default: appuser)"
  echo "    BACKUP_CONTAINER    Container name (default: taskapp-postgres)"
  echo "    BACKUP_DIR          Backup directory (default: ./backups)"
  echo "    RETENTION_DAYS      Days to keep backups (default: 7)"
  echo ""
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "$CMD" in
  backup)  do_backup ;;
  restore) do_restore "$@" ;;
  list)    do_list ;;
  clean)   do_clean ;;
  *)       do_help ;;
esac