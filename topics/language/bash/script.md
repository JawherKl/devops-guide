# 🔧 Bash Scripting

> Bash is the universal glue of DevOps. It runs on every Linux server without installation, starts instantly, and can invoke any system tool. The difference between a throwaway one-liner and a production-quality script is error handling, testability, and clarity. This file covers writing Bash that is safe to run in CI pipelines and on production servers.

---

## Script Anatomy & Safety Flags

```bash
#!/usr/bin/env bash
# Use env bash for portability across different bash locations (/bin/bash vs /usr/local/bin/bash)
# Use #!/bin/sh for pure POSIX portability (no bash-specific features)

# ── The essential safety trio ─────────────────────────────────────────────────
set -e          # Exit immediately on any error (non-zero exit code)
set -u          # Treat unset variables as errors — catches typos ($DIRECOTRY vs $DIRECTORY)
set -o pipefail # Fail pipeline if ANY command fails, not just the last
# Combined shorthand:
set -euo pipefail

# ── Useful debugging flags ────────────────────────────────────────────────────
set -x          # Print every command before executing (trace mode) — great for debugging
set +x          # Turn off trace
bash -n script.sh  # Syntax check without executing
bash -x script.sh  # Run with tracing
```

---

## Variables, Quoting & Expansion

```bash
# ── Always quote variables ────────────────────────────────────────────────────
name="Alice Smith"
echo "$name"              # correct: "Alice Smith" as one token
echo $name                # WRONG: word-splits into "Alice" and "Smith"

# Rule: ALWAYS double-quote variable expansions: "$var", "${arr[@]}", "$@"
# Exception: arithmetic $(( )), [[ ]] test command (safe without quotes)

# ── Variable types ────────────────────────────────────────────────────────────
local_var="only in this scope"  # local (but Bash globals are default)
readonly CONST="immutable"       # read-only constant
export PATH_BIN="/usr/local/bin" # export to child processes
declare -i counter=0             # integer: arithmetic auto-applied
declare -a arr=("a" "b" "c")    # indexed array
declare -A map                   # associative array (hash map)
map["key"]="value"

# ── String expansion ──────────────────────────────────────────────────────────
str="hello world"
echo "${#str}"              # length: 11
echo "${str^^}"             # UPPER: HELLO WORLD
echo "${str,,}"             # lower: hello world
echo "${str^}"              # Capitalise first: Hello world
echo "${str/world/there}"   # replace first: hello there
echo "${str//l/L}"          # replace all: heLLo worLd
echo "${str#hello }"        # remove prefix: world
echo "${str%world}"         # remove suffix: hello 
echo "${str:6}"             # substring from pos 6: world
echo "${str:0:5}"           # substring 0–4: hello
echo "${str: -5}"           # last 5 chars: world

# ── Default values ────────────────────────────────────────────────────────────
echo "${PORT:-8080}"                  # use 8080 if PORT unset or empty
echo "${ENV:=production}"            # set ENV=production if unset, then use
echo "${REQUIRED:?Must be set}"      # error and exit if unset
echo "${OPTIONAL:+--flag=$OPTIONAL}" # expand only if OPTIONAL is set

# ── Arrays ────────────────────────────────────────────────────────────────────
hosts=("web1" "web2" "db1")
echo "${hosts[0]}"           # first element: web1
echo "${hosts[@]}"           # all elements: web1 web2 db1
echo "${#hosts[@]}"          # count: 3
hosts+=("cache1")            # append
unset "hosts[1]"             # remove element

for host in "${hosts[@]}"; do
    echo "Processing $host"
done

# Capture command output into array:
mapfile -t lines < file.txt           # read file lines into array
mapfile -t pids < <(pgrep nginx)      # read PIDs into array
readarray -t servers < servers.txt    # same as mapfile
```

---

## Control Flow

```bash
# ── if / elif / else ──────────────────────────────────────────────────────────
if [[ "$1" == "start" ]]; then
    start_service
elif [[ "$1" == "stop" ]]; then
    stop_service
else
    die "Usage: $0 start|stop"
fi

# ── [[ ]] vs [ ] ──────────────────────────────────────────────────────────────
# Use [[ ]] in Bash — it's safer (no word-splitting, better operators)
[[ -f "/etc/nginx.conf" ]]   # file exists and is regular file
[[ -d "/etc/nginx" ]]        # directory exists
[[ -z "$var" ]]              # empty string
[[ -n "$var" ]]              # non-empty string
[[ "$a" == "$b" ]]           # string equality
[[ "$a" != "$b" ]]           # string inequality
[[ "$a" < "$b" ]]            # string comparison (lexicographic)
[[ "$n" -eq 5 ]]             # integer equal
[[ "$n" -gt 0 && "$n" -lt 10 ]] # integer range with &&
[[ "$str" == *"pattern"* ]]  # glob match (no quotes around pattern!)
[[ "$str" =~ ^[0-9]+$ ]]     # regex match (BASH_REMATCH captures groups)

# ── case statement ────────────────────────────────────────────────────────────
case "$ENVIRONMENT" in
    production|prod)
        REPLICAS=4
        LOG_LEVEL="warn"
        ;;
    staging)
        REPLICAS=2
        LOG_LEVEL="info"
        ;;
    dev|development)
        REPLICAS=1
        LOG_LEVEL="debug"
        ;;
    *)
        die "Unknown environment: $ENVIRONMENT"
        ;;
esac

# ── Loops ─────────────────────────────────────────────────────────────────────
# for over list:
for env in dev staging production; do
    deploy "$env"
done

# for over array (correct way — preserves spaces in elements):
for server in "${servers[@]}"; do
    echo "$server"
done

# for over file lines:
while IFS= read -r line; do
    echo "Processing: $line"
done < /etc/servers.txt

# for over command output:
while IFS= read -r container; do
    docker inspect "$container"
done < <(docker ps -q)       # process substitution (avoids subshell for while)

# C-style for loop:
for (( i=0; i<10; i++ )); do
    echo "$i"
done

# until (loop while condition is FALSE):
until curl -sf http://localhost:8080/health; do
    echo "Waiting for service..."
    sleep 2
done

# break and continue:
for file in /var/log/*.log; do
    [[ $(stat -c%s "$file") -gt 104857600 ]] && { rotate_log "$file"; continue; }
    process_log "$file"
done
```

---

## Functions

```bash
# ── Function definition ───────────────────────────────────────────────────────
# Style: declare before use; group related functions together

# Logging helpers (essential in any production script):
readonly SCRIPT_NAME="$(basename "$0")"
log()   { printf '%s [INFO]  %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*"; }
warn()  { printf '%s [WARN]  %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >&2; }
die()   { printf '%s [ERROR] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >&2; exit 1; }

# Function with local variables and default argument:
wait_for_port() {
    local host="${1:?host required}"
    local port="${2:?port required}"
    local timeout="${3:-30}"           # default 30 seconds
    local elapsed=0

    log "Waiting for $host:$port (timeout: ${timeout}s)"
    until nc -z "$host" "$port" 2>/dev/null; do
        (( elapsed++ ))
        (( elapsed >= timeout )) && die "Timeout waiting for $host:$port"
        sleep 1
    done
    log "$host:$port is ready (${elapsed}s)"
}

# Function that returns a value via stdout:
get_container_ip() {
    local container="${1:?container name required}"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container"
}

container_ip=$(get_container_ip "my-app")

# Function with multiple return paths:
check_dependency() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        log "✓ $cmd found: $(command -v "$cmd")"
        return 0
    else
        warn "✗ $cmd not found"
        return 1
    fi
}

# ── Argument parsing with getopts (POSIX) ────────────────────────────────────
parse_args() {
    local OPTIND opt

    while getopts ":e:p:vh" opt; do
        case $opt in
            e) ENVIRONMENT="$OPTARG" ;;
            p) PORT="$OPTARG" ;;
            v) VERBOSE=true ;;
            h) usage; exit 0 ;;
            :) die "Option -$OPTARG requires an argument" ;;
            ?) die "Unknown option: -$OPTARG" ;;
        esac
    done
    shift $(( OPTIND - 1 ))
    REMAINING_ARGS=("$@")
}

# ── Long options with manual parsing ──────────────────────────────────────────
ENVIRONMENT="dev"
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env|-e)       ENVIRONMENT="$2"; shift 2 ;;
        --env=*)        ENVIRONMENT="${1#*=}"; shift ;;
        --verbose|-v)   VERBOSE=true; shift ;;
        --dry-run|-n)   DRY_RUN=true; shift ;;
        --help|-h)      usage; exit 0 ;;
        --)             shift; break ;;
        -*)             die "Unknown option: $1" ;;
        *)              break ;;
    esac
done
```

---

## Error Handling & Cleanup

```bash
# ── Trap: guaranteed cleanup ──────────────────────────────────────────────────
TMPDIR_WORK=""

cleanup() {
    local exit_code=$?
    [[ -n "$TMPDIR_WORK" ]] && rm -rf "$TMPDIR_WORK"
    (( exit_code != 0 )) && warn "Script failed with exit code $exit_code"
    exit "$exit_code"
}

trap cleanup EXIT
trap 'die "Interrupted"' INT TERM

TMPDIR_WORK=$(mktemp -d /tmp/deploy.XXXXXX)

# ── Retry logic ───────────────────────────────────────────────────────────────
retry() {
    local attempts="${1:?}"; shift
    local delay="${1:?}";    shift
    local cmd=("$@")
    local attempt=1

    until "${cmd[@]}"; do
        (( attempt++ ))
        (( attempt > attempts )) && { warn "Command failed after $attempts attempts"; return 1; }
        warn "Attempt $((attempt-1)) failed. Retrying in ${delay}s... ($attempt/$attempts)"
        sleep "$delay"
    done
}

# Usage:
retry 5 10 curl -sf https://api.example.com/health

# ── Check required tools at startup ──────────────────────────────────────────
require_commands() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    (( ${#missing[@]} > 0 )) && die "Missing required commands: ${missing[*]}"
}

require_commands docker kubectl helm curl jq

# ── Validate environment variables ───────────────────────────────────────────
validate_env() {
    local missing=()
    for var in "$@"; do
        [[ -z "${!var:-}" ]] && missing+=("$var")
    done
    (( ${#missing[@]} > 0 )) && die "Missing required environment variables: ${missing[*]}"
}

validate_env AWS_REGION KUBE_CONTEXT DB_PASSWORD

# ── Atomic file writes ────────────────────────────────────────────────────────
# Never write directly to the target — use a temp file + atomic rename
write_config() {
    local target="$1"
    local content="$2"
    local tmpfile
    tmpfile=$(mktemp "${target}.XXXXXX")
    printf '%s\n' "$content" > "$tmpfile"
    mv -f "$tmpfile" "$target"         # atomic: mv is a single syscall
}
```

---

## Process & Output Handling

```bash
# ── Capture stdout, stderr separately ────────────────────────────────────────
output=$(command 2>/dev/null)          # only stdout; discard stderr
error=$(command 2>&1 >/dev/null)       # only stderr; discard stdout
output=$(command 2>"$TMPDIR_WORK/err") # stdout to var; stderr to file

# ── Run in parallel and wait ──────────────────────────────────────────────────
pids=()
for server in web1 web2 web3; do
    ssh "deploy@$server" "cd /app && git pull && systemctl restart app" &
    pids+=($!)
done

# Wait for all and check exit codes:
failed=()
for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || failed+=("${servers[$i]}")
done
(( ${#failed[@]} > 0 )) && die "Deploy failed on: ${failed[*]}"

# ── Progress indicator ────────────────────────────────────────────────────────
show_progress() {
    local pid=$1
    local label="${2:-Working}"
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r%s %s' "${chars:$(( i % ${#chars} )):1}" "$label"
        (( i++ ))
        sleep 0.1
    done
    printf '\r✓ %s\n' "$label"
}

long_running_command &
show_progress $! "Deploying..."

# ── Here-string and here-doc ──────────────────────────────────────────────────
# Multiline config without a file:
cat > /etc/myapp/config.yaml << EOF
environment: ${ENVIRONMENT}
database:
  host: ${DB_HOST}
  port: ${DB_PORT:-5432}
EOF

# Run on remote without a script file:
ssh "ubuntu@${HOST}" << 'REMOTE'
set -euo pipefail
cd /app
git pull origin main
npm ci --production
pm2 restart app
REMOTE
# Note: quoted 'REMOTE' = no local variable expansion; unquoted = variables expand
```