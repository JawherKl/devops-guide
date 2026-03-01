# 📜 POSIX

> POSIX (Portable Operating System Interface) is the IEEE standard that defines how Unix-like systems behave: the process model, shell behaviour, file permissions, pipes, signals, and exit codes. Writing POSIX-compliant shell scripts means they run on any Linux distro, macOS, BSD, and any container — without modification.

---

## The Process Model

Every running program is a process. Processes form a tree rooted at PID 1.

```
PID 1 (systemd / init)
├── PID 123 (sshd)
│     └── PID 456 (bash)       ← your SSH session
│           ├── PID 789 (vim)
│           └── PID 790 (grep)
├── PID 200 (nginx master)
│     ├── PID 201 (nginx worker)
│     └── PID 202 (nginx worker)
└── PID 300 (dockerd)
      ├── PID 350 (containerd)
      └── PID 400 (container process)
```

```bash
# Every process has:
#   PID  — process ID (unique integer)
#   PPID — parent PID
#   UID  — user that owns the process
#   GID  — group that owns the process
#   CWD  — current working directory
#   ENV  — copy of environment variables
#   FDs  — set of open file descriptors

# View process tree
pstree                           # graphical tree
pstree -p                        # with PIDs
ps -ef --forest                  # tree in ps output

# A process is created by fork() then exec():
# fork()  — creates an identical copy of the parent (child gets same FDs, ENV, CWD)
# exec()  — replaces the child's memory with a new program
# This is why: environment variables are inherited (fork copies them)
#              cd in a subshell doesn't change parent's directory (fork = copy)
```

---

## Shell Scripting — POSIX Standard

```bash
#!/bin/sh
# Use #!/bin/sh for maximum portability (POSIX)
# Use #!/bin/bash only when you need bash-specific features (arrays, [[ ]])

# ── Variables ─────────────────────────────────────────────────────────────────
name="Alice"
echo "$name"              # ALWAYS quote variable expansions
echo "${name}"            # braces for clarity or when followed by more text
echo "${name}file"        # → Alicefile (without braces: $namefile = empty)
readonly CONST="fixed"    # read-only variable

# ── Command substitution ──────────────────────────────────────────────────────
date_str=$(date +%Y-%m-%d)        # modern POSIX syntax (preferred)
date_str=`date +%Y-%m-%d`         # legacy backtick syntax (avoid)
files=$(find . -name "*.log")     # capture output as variable

# ── Arithmetic ────────────────────────────────────────────────────────────────
n=5
result=$((n * 2 + 1))             # arithmetic expansion (POSIX)
result=$(expr $n \* 2 + 1)        # expr (older, avoid if possible)

# ── String operations ─────────────────────────────────────────────────────────
str="hello world"
echo ${#str}                      # length: 11
echo ${str#hello }                # remove prefix "hello ": → world
echo ${str%world}                 # remove suffix "world": → hello 
echo ${str/world/there}           # replace first: → hello there
echo ${str//l/L}                  # replace all: → heLLo worLd
echo ${str:0:5}                   # substring: chars 0–4 → hello

# ── Default values ────────────────────────────────────────────────────────────
echo ${VAR:-default}              # use default if VAR is unset or empty
echo ${VAR:=default}              # set VAR to default AND use it
echo ${VAR:?error message}        # exit with error if VAR is unset
echo ${VAR:+replacement}          # use replacement if VAR IS set
```

---

## Exit Codes

Exit codes are the primary mechanism for communicating success or failure between processes.

```bash
# ── Exit code rules ────────────────────────────────────────────────────────────
# 0    = success (everything is fine)
# 1    = general error
# 2    = misuse of shell built-in (wrong arguments)
# 126  = command found but not executable (permission denied)
# 127  = command not found
# 128  = invalid exit argument
# 128+N = killed by signal N (e.g. 130 = killed by SIGINT = Ctrl+C, 137 = SIGKILL)

# ── Checking exit codes ────────────────────────────────────────────────────────
ls /tmp
echo $?                           # 0 = success

ls /nonexistent
echo $?                           # 2 = no such file

# ── if statement: based on exit code ──────────────────────────────────────────
if command; then
    echo "command succeeded (exit 0)"
fi

if ! command; then
    echo "command failed (exit non-zero)"
fi

# The [ ] (test) command:
if [ "$name" = "Alice" ]; then    # string equality
if [ "$n" -eq 5 ]; then           # integer equality (-eq -ne -lt -le -gt -ge)
if [ -f "/etc/nginx.conf" ]; then # file exists and is regular file
if [ -d "/etc/nginx" ]; then      # directory exists
if [ -r "file.txt" ]; then        # file exists and is readable
if [ -z "$var" ]; then            # string is empty (zero length)
if [ -n "$var" ]; then            # string is non-empty

# Combined conditions:
if [ -f "$file" ] && [ -r "$file" ]; then  # AND
if [ "$a" = "x" ] || [ "$b" = "x" ]; then  # OR

# bash extension [[ ]] (not POSIX, but more powerful):
if [[ "$str" == *"pattern"* ]]; then  # glob pattern match
if [[ "$str" =~ ^[0-9]+$ ]]; then     # regex match
```

---

## Signals

Signals are asynchronous notifications sent to processes. They are how the OS and users communicate with running programs.

```bash
# ── Common signals ────────────────────────────────────────────────────────────
# SIGHUP  (1)  — terminal closed, or: "reload config" (nginx, sshd handle this)
# SIGINT  (2)  — Ctrl+C: interrupt (polite stop request, can be caught)
# SIGQUIT (3)  — Ctrl+\: quit + core dump
# SIGKILL (9)  — unconditional kill (CANNOT be caught, blocked, or ignored)
# SIGTERM (15) — polite termination request (CAN be caught — default for kill)
# SIGUSR1 (10) — user-defined (app-specific: Nginx uses it to reopen log files)
# SIGUSR2 (12) — user-defined
# SIGCHLD (17) — child process has stopped or exited
# SIGSTOP (19) — pause process (like Ctrl+Z — cannot be caught or ignored)
# SIGCONT (18) — resume paused process

# ── Sending signals ───────────────────────────────────────────────────────────
kill 1234                     # SIGTERM (15) to PID 1234 — graceful shutdown
kill -15 1234                 # same
kill -TERM 1234               # same, using name
kill -9 1234                  # SIGKILL — immediate, no cleanup
kill -HUP $(cat /run/nginx.pid)  # reload nginx config
kill -USR1 $(cat /run/nginx.pid) # reopen nginx log files

pkill nginx                   # SIGTERM all processes named nginx
pkill -9 nginx                # SIGKILL all processes named nginx
pkill -HUP -f "nginx: master" # signal matching full command

# ── Trapping signals in scripts ───────────────────────────────────────────────
#!/bin/sh
# Clean up temp files when script is interrupted or exits

TMPFILE=$(mktemp /tmp/myapp.XXXXXX)

cleanup() {
    echo "Cleaning up..."
    rm -f "$TMPFILE"
    exit 0
}

# Register signal handlers:
trap cleanup EXIT       # run cleanup when script exits for ANY reason
trap cleanup INT        # run cleanup on Ctrl+C (SIGINT)
trap cleanup TERM       # run cleanup on SIGTERM (kill)

# A script without trap:
#   Ctrl+C → script dies → tmpfile left on disk
# A script with trap EXIT:
#   Any exit → cleanup runs → tmpfile removed
```

---

## Pipes & Redirection (In Depth)

```bash
# ── How pipes work ────────────────────────────────────────────────────────────
# cmd1 | cmd2 creates a pipe (kernel buffer):
#   cmd1's stdout → pipe buffer → cmd2's stdin
# Both commands run CONCURRENTLY in separate subshells
# The pipe is closed when cmd1 exits → cmd2 gets EOF

# ── Exit code of a pipeline ───────────────────────────────────────────────────
false | true
echo $?        # 0 — exit code of LAST command in pipe (bash default)

set -o pipefail   # IMPORTANT: return exit code of FIRST failing command
false | true
echo $?        # 1 — false failed, pipefail reports it

# Always set -o pipefail in scripts where pipeline errors matter:
# set -euo pipefail

# ── Redirections ──────────────────────────────────────────────────────────────
cmd > file           # stdout → file (create/overwrite)
cmd >> file          # stdout → file (append)
cmd 2> file          # stderr → file
cmd 2>&1             # stderr → same as stdout
cmd > file 2>&1      # both to file (order matters! 2>&1 after >)
cmd &> file          # bash shorthand: both to file

# ── /dev/fd and process substitution ──────────────────────────────────────────
# Send stderr to one file and stdout to another:
cmd > stdout.txt 2> stderr.txt

# Use process substitution to pass command output as a file argument:
diff <(ls dir1/ | sort) <(ls dir2/ | sort)   # compare directory listings
wc -l <(find . -name "*.py")                 # count Python files without temp file

# ── Here-doc ──────────────────────────────────────────────────────────────────
# Multi-line string without creating a file:
cat << 'EOF'                 # quoted EOF: NO variable expansion inside
Hello $USER
This is literal text.
EOF

cat << EOF                   # unquoted EOF: variables ARE expanded
Hello $USER
Today is $(date).
EOF

# Pass here-doc as stdin to command:
ssh user@host << 'EOF'
  cd /app
  git pull
  systemctl restart myapp
EOF
```

---

## Writing Robust Shell Scripts

```bash
#!/bin/sh
# ── The essential safety trio ──────────────────────────────────────────────────
set -e          # exit immediately on any error (non-zero exit code)
set -u          # treat unset variables as errors (catches typos like $DIRECORY)
set -o pipefail # pipe fails if any command in it fails (not just the last)
# Or combined:
set -euo pipefail

# ── Full production-quality script template ───────────────────────────────────
#!/bin/sh
set -euo pipefail

# Script metadata
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)  # absolute path, follows symlinks
LOG_FILE="/var/log/${SCRIPT_NAME}.log"

# Colours (only when stdout is a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

log()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]  $*" | tee -a "$LOG_FILE"; }
warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN]  $*" | tee -a "$LOG_FILE" >&2; }
die()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOG_FILE" >&2; exit 1; }

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <argument>

Options:
  -h, --help      Show this help
  -v, --verbose   Verbose output
  -n, --dry-run   Show what would be done, but don't do it

Example:
  $SCRIPT_NAME -v /path/to/config
EOF
    exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
VERBOSE=false
DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)    usage ;;
        -v|--verbose) VERBOSE=true ;;
        -n|--dry-run) DRY_RUN=true ;;
        --)           shift; break ;;
        -*)           die "Unknown option: $1" ;;
        *)            break ;;
    esac
    shift
done

[ $# -lt 1 ] && die "Missing required argument. See $SCRIPT_NAME --help"
TARGET="$1"

# ── Dependency check ──────────────────────────────────────────────────────────
for cmd in curl jq git; do
    command -v "$cmd" > /dev/null 2>&1 || die "Required command not found: $cmd"
done

# ── Root check ────────────────────────────────────────────────────────────────
[ "$(id -u)" -ne 0 ] && die "This script must be run as root"

# ── Cleanup on exit ───────────────────────────────────────────────────────────
TMPDIR=$(mktemp -d /tmp/${SCRIPT_NAME}.XXXXXX)
cleanup() {
    rm -rf "$TMPDIR"
    log "Cleaned up temporary files"
}
trap cleanup EXIT

# ── Main logic ────────────────────────────────────────────────────────────────
log "Starting $SCRIPT_NAME for target: $TARGET"

if [ "$DRY_RUN" = "true" ]; then
    log "DRY RUN: would process $TARGET"
    exit 0
fi

# ... actual work here ...

log "Done."
```

---

## Functions

```bash
# ── Defining and calling functions ────────────────────────────────────────────
# POSIX syntax:
greet() {
    local name="$1"         # local: variable scoped to function (not global)
    local greeting="${2:-Hello}"  # default if $2 not provided
    echo "$greeting, $name!"
}

greet "Alice"               # → Hello, Alice!
greet "Bob" "Hi"            # → Hi, Bob!

# ── Return values ─────────────────────────────────────────────────────────────
# Functions return exit codes (0–255), not values.
# To "return" a string, echo it and capture with $()

get_config_value() {
    local key="$1"
    grep "^${key}=" /etc/myapp.conf | cut -d= -f2
}

db_host=$(get_config_value "DB_HOST")

# Return true/false:
is_port_open() {
    nc -z "$1" "$2" 2>/dev/null
    # returns 0 (true) if open, 1 (false) if not
}

if is_port_open localhost 5432; then
    echo "PostgreSQL is up"
fi
```

---

## Cron Jobs

```bash
# crontab syntax:
# ┌───────── minute (0–59)
# │ ┌─────── hour (0–23)
# │ │ ┌───── day of month (1–31)
# │ │ │ ┌─── month (1–12)
# │ │ │ │ ┌─ day of week (0–7, 0 and 7 = Sunday)
# │ │ │ │ │
# * * * * * command

crontab -l                                  # list current user's cron jobs
crontab -e                                  # edit current user's cron jobs
crontab -u alice -l                         # list alice's cron jobs (root only)

# Examples:
# Run every minute:
* * * * * /path/to/script.sh

# Every hour at minute 0:
0 * * * * /path/to/backup.sh

# Every day at 2:30 AM:
30 2 * * * /path/to/cleanup.sh

# Every Sunday at midnight:
0 0 * * 0 /path/to/weekly.sh

# Every 5 minutes:
*/5 * * * * /path/to/healthcheck.sh

# First day of every month at 6 AM:
0 6 1 * * /path/to/monthly-report.sh

# Always use full paths in cron (no $PATH):
0 2 * * * /usr/bin/find /tmp -mtime +7 -delete >> /var/log/cleanup.log 2>&1

# Suppress email on success (cron sends email if output is produced):
*/5 * * * * /path/to/script.sh > /dev/null 2>&1

# System-wide cron:
# /etc/cron.d/myapp   (cron files with user field)
# 0 2 * * * root /path/to/script.sh
```