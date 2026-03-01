# 🖥️ Shell Commands

> These are the commands you will use every single day as a DevOps engineer. Mastering them means spending less time fighting the terminal and more time solving real problems. Every example here uses concrete, real-world patterns — not toy examples.

---

## Navigation & Directory Operations

```bash
# ── Location ──────────────────────────────────────────────────────────────────
pwd                          # print working directory
cd /etc/nginx                # change to absolute path
cd ..                        # go up one level
cd ~                         # go to home directory
cd -                         # jump back to previous directory (very useful)
cd ~/projects/devops-guide   # home-relative path

# ── Listing ───────────────────────────────────────────────────────────────────
ls                           # basic list
ls -l                        # long format: permissions, owner, size, date
ls -lah                      # long + all (hidden) + human-readable sizes
ls -lt                       # sort by modification time (newest first)
ls -lS                       # sort by size (largest first)
ls -R                        # recursive list of all subdirectories
ls -1                        # one file per line (useful in scripts)

# ── Tree view ─────────────────────────────────────────────────────────────────
tree                         # graphical directory tree
tree -L 2                    # limit to 2 levels deep
tree -I "node_modules|.git"  # ignore patterns
```

---

## File Operations

```bash
# ── Create ────────────────────────────────────────────────────────────────────
touch file.txt               # create empty file (or update timestamp if exists)
touch -t 202401011200 file   # create with specific timestamp
mkdir new-dir                # create directory
mkdir -p path/to/deep/dir    # create with all parent dirs (no error if exists)

# ── Copy ──────────────────────────────────────────────────────────────────────
cp file.txt backup.txt       # copy a file
cp -r src/ dst/              # copy directory recursively
cp -p file.txt backup.txt    # preserve permissions, timestamps, ownership
cp -u src/* dst/             # only copy if source is newer than destination

# ── Move / Rename ─────────────────────────────────────────────────────────────
mv old.txt new.txt           # rename
mv file.txt /tmp/            # move to directory
mv -i file.txt dest/         # prompt before overwriting (interactive)
mv -n file.txt dest/         # never overwrite (no-clobber)

# ── Delete ────────────────────────────────────────────────────────────────────
rm file.txt                  # delete file
rm -i file.txt               # ask before deleting (interactive)
rm -r directory/             # delete directory recursively
rm -rf directory/            # force recursive delete (NO confirmation — dangerous)
rmdir empty-dir/             # delete only if empty (safer)

# ── View file contents ────────────────────────────────────────────────────────
cat file.txt                 # print entire file
cat -n file.txt              # with line numbers
less file.txt                # paginated view (q to quit, / to search, G for end)
head -20 file.txt            # first 20 lines
tail -20 file.txt            # last 20 lines
tail -f /var/log/nginx/access.log   # follow log in real time (Ctrl+C to stop)
tail -f /var/log/syslog | grep ERROR  # follow + filter

# ── File info ─────────────────────────────────────────────────────────────────
file unknown.bin             # detect file type from magic bytes
stat file.txt                # full metadata: size, inode, permissions, timestamps
wc -l file.txt               # count lines
wc -w file.txt               # count words
wc -c file.txt               # count bytes
```

---

## Searching & Finding

```bash
# ── find: search filesystem ───────────────────────────────────────────────────
find /etc -name "*.conf"                   # by name in /etc
find . -name "*.js" -not -path "*/node_modules/*"  # exclude node_modules
find /var/log -type f -mtime -1            # modified in last 24 hours
find /tmp -type f -mtime +7 -delete        # delete files older than 7 days
find . -type f -size +100M                 # files larger than 100MB
find / -perm /4000 -type f 2>/dev/null     # SUID files (security audit)
find . -user root -type f                  # files owned by root
find . -empty                             # empty files and directories

# Execute a command on each result:
find . -name "*.log" -exec rm {} \;        # delete each found file
find . -name "*.txt" -exec chmod 644 {} +  # set permissions (+ = batch, faster)

# ── grep: search content ──────────────────────────────────────────────────────
grep "error" app.log                       # case-sensitive match
grep -i "error" app.log                    # case-insensitive
grep -n "error" app.log                    # show line numbers
grep -c "error" app.log                    # count matching lines
grep -v "DEBUG" app.log                    # invert: lines NOT matching
grep -r "TODO" src/                        # recursive search in directory
grep -r "TODO" src/ --include="*.ts"       # only in TypeScript files
grep -l "api_key" /etc/                    # only filenames, not content
grep -A 3 "error" app.log                 # 3 lines After match (context)
grep -B 3 "error" app.log                 # 3 lines Before match
grep -E "error|warning|critical" app.log  # extended regex: multiple patterns
grep -P "\d{3}-\d{4}" contacts.txt        # Perl regex: phone numbers

# ── ripgrep (rg): faster grep, respects .gitignore ───────────────────────────
rg "TODO" src/                             # recursive search, fast
rg -i "error" --type ts                    # case-insensitive, TypeScript only

# ── locate: search indexed database (faster than find, not always current) ────
locate nginx.conf                          # find file by name instantly
updatedb                                   # rebuild the locate database
```

---

## Text Processing

```bash
# ── cut: extract columns ──────────────────────────────────────────────────────
cut -d: -f1 /etc/passwd                    # usernames (field 1, colon delimiter)
cut -d, -f2,4 data.csv                     # fields 2 and 4 from CSV
cut -c1-10 file.txt                        # first 10 characters of each line

# ── awk: column-based processing ──────────────────────────────────────────────
awk '{print $1}' file.txt                  # print first column
awk -F: '{print $1, $3}' /etc/passwd       # username and UID from /etc/passwd
awk '{print $NF}' file.txt                 # last field of each line
awk 'NR==5' file.txt                       # print line 5
awk '/error/{print NR": "$0}' app.log      # print line number + content for errors
awk '{sum += $3} END {print sum}' data.txt # sum of column 3
awk '$3 > 100 {print $1}' data.txt         # conditional: field 3 > 100
df -h | awk 'NR>1 {print $5, $6}'          # disk usage: % and mount point

# ── sed: stream editor (find and replace, transform) ──────────────────────────
sed 's/foo/bar/' file.txt                  # replace first occurrence per line
sed 's/foo/bar/g' file.txt                 # replace ALL occurrences
sed -i 's/foo/bar/g' file.txt              # in-place edit (modifies the file)
sed -i.bak 's/foo/bar/g' file.txt          # in-place with backup (file.txt.bak)
sed -n '10,20p' file.txt                   # print lines 10–20 only
sed '/^#/d' config.conf                    # delete comment lines
sed '/^$/d' file.txt                       # delete empty lines
sed 's/^/    /' file.txt                   # indent every line by 4 spaces

# ── sort & uniq ───────────────────────────────────────────────────────────────
sort file.txt                              # alphabetical sort
sort -n numbers.txt                        # numeric sort
sort -rn numbers.txt                       # reverse numeric sort
sort -t: -k3 -n /etc/passwd               # sort by UID (field 3, colon delimiter)
sort file.txt | uniq                       # remove duplicate lines (needs sorted input)
sort file.txt | uniq -c                    # count occurrences of each line
sort file.txt | uniq -d                    # show only duplicate lines

# Common pattern: count and rank log entries
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20
# → shows top 20 most-requested URLs

# ── tr: translate or delete characters ────────────────────────────────────────
echo "Hello World" | tr '[:upper:]' '[:lower:]'   # lowercase
echo "a:b:c" | tr ':' '\n'                         # replace colon with newline
echo "  spaces  " | tr -s ' '                      # squeeze multiple spaces to one
cat file.txt | tr -d '\r'                           # remove Windows carriage returns

# ── xargs: build command lines from stdin ─────────────────────────────────────
find . -name "*.log" | xargs rm            # delete all found .log files
cat urls.txt | xargs -I{} curl -O {}       # download each URL from file
echo "file1 file2 file3" | xargs -n1 echo # one argument per execution
find . -name "*.py" | xargs wc -l          # count lines in all Python files
cat pids.txt | xargs kill                  # kill a list of PIDs
```

---

## Process Management

```bash
# ── View processes ────────────────────────────────────────────────────────────
ps aux                       # all processes: user, PID, CPU%, MEM%, command
ps aux | grep nginx          # filter for nginx processes
ps -ef                       # full format with PPID (parent PID)
ps -p 1234 -o pid,ppid,cmd  # info about specific PID
pgrep nginx                  # get PIDs of processes named nginx
pgrep -u www-data            # all PIDs owned by www-data

# ── Real-time monitoring ──────────────────────────────────────────────────────
top                          # interactive process monitor (q to quit)
top -b -n 1                  # batch mode: one snapshot (good for scripts)
htop                         # improved top with mouse support (apt install htop)

# Sort in top: P=CPU, M=memory, T=running time, N=PID, k=kill
# In htop: F6=sort column, F5=tree view, F9=kill

# ── Signals & killing ─────────────────────────────────────────────────────────
kill 1234                    # send SIGTERM (15): graceful shutdown request
kill -9 1234                 # send SIGKILL: immediate, cannot be caught or ignored
kill -HUP 1234               # send SIGHUP: reload config (Nginx, sshd respond to this)
kill -0 1234                 # test if process exists (no signal sent)
killall nginx                # kill all processes named nginx
pkill -f "node app.js"       # kill by full command match

# ── Background jobs ───────────────────────────────────────────────────────────
long-command &               # run in background
jobs                         # list background jobs in current shell
fg %1                        # bring job 1 to foreground
bg %1                        # resume stopped job in background
Ctrl+Z                       # suspend foreground job (sends SIGSTOP)
nohup command &              # run immune to hangup (survives terminal close)
command > /dev/null 2>&1 &   # run in background, discard all output

# ── Process priority (nice) ───────────────────────────────────────────────────
nice -n 10 make              # start at lower priority (-20 highest, 19 lowest)
renice 10 -p 1234            # change running process priority
ionice -c 3 rsync ...        # give rsync idle I/O priority

# ── Who is using a port / file? ───────────────────────────────────────────────
lsof -i :3000                # what process is using port 3000
lsof -u www-data             # all files opened by www-data user
lsof /var/log/nginx/error.log  # which process has this file open
fuser 3000/tcp               # PID using port 3000 (simpler than lsof)
kill -9 $(lsof -ti :3000)    # kill whatever is using port 3000
```

---

## Permissions & Ownership

```bash
# ── Understanding permission notation ─────────────────────────────────────────
# ls -l output:   -rwxr-xr--  1  alice  developers  1024  Jan 1  file.sh
#                 │└──┬──┘└──┬──┘
#                 │   │      └── others: r--  = 4 (read only)
#                 │   └──────── group:   r-x  = 5 (read + execute)
#                 └──────────── owner:   rwx  = 7 (read + write + execute)
#                 type: - = file, d = directory, l = symlink

# Octal:  r=4  w=2  x=1    rwx=7  rw-=6  r-x=5  r--=4  ---=0

# ── chmod: change permissions ─────────────────────────────────────────────────
chmod 644 file.txt           # owner rw, group r, others r  (standard for files)
chmod 755 script.sh          # owner rwx, group rx, others rx (standard for dirs/scripts)
chmod 600 ~/.ssh/id_rsa      # owner rw only (SSH keys MUST be this)
chmod 700 ~/.ssh/            # owner rwx only
chmod +x script.sh           # add execute for everyone
chmod -x script.sh           # remove execute for everyone
chmod u+x,g-w file           # symbolic: add exec for user, remove write for group
chmod -R 755 /var/www/       # recursive: apply to dir and all contents

# ── chown: change ownership ───────────────────────────────────────────────────
chown alice file.txt         # change owner to alice
chown alice:developers file  # change owner + group
chown -R www-data:www-data /var/www/html/  # recursive ownership change
chown --reference=ref.txt target.txt  # copy ownership from another file

# ── chgrp: change group ────────────────────────────────────────────────────────
chgrp developers project/
chgrp -R developers project/

# ── Special permissions ───────────────────────────────────────────────────────
# SUID (4): execute as file owner, not as the user running it
# find / -perm /4000 = find all SUID files (security audit)
chmod 4755 program           # SUID: runs as owner (e.g. sudo, passwd)

# SGID (2): new files in directory inherit the directory's group
chmod 2775 shared-dir/       # SGID on directory: good for shared team folders

# Sticky bit (1): only file owner can delete files in directory
chmod 1777 /tmp              # sticky: everyone can write, only owner can delete own files

# ── umask: default permission mask ───────────────────────────────────────────
umask                        # show current mask (e.g. 0022)
# New files:      666 - 022 = 644   (rw-r--r--)
# New directories: 777 - 022 = 755  (rwxr-xr-x)
umask 027                    # tighter: files=640, dirs=750 (nothing for others)
```

---

## Archiving & Compression

```bash
# ── tar: archive files ────────────────────────────────────────────────────────
tar -czf archive.tar.gz dir/         # create gzip-compressed archive
tar -cjf archive.tar.bz2 dir/        # create bzip2-compressed archive (smaller)
tar -cJf archive.tar.xz dir/         # create xz-compressed archive (smallest)
tar -xzf archive.tar.gz              # extract gzip archive here
tar -xzf archive.tar.gz -C /tmp/     # extract to specific directory
tar -tzf archive.tar.gz              # list contents without extracting
tar -xzf archive.tar.gz specific/file.txt  # extract single file

# ── gzip / gunzip ─────────────────────────────────────────────────────────────
gzip file.txt                # compress → file.txt.gz (removes original)
gzip -k file.txt             # compress but keep original
gzip -9 file.txt             # maximum compression
gunzip file.txt.gz           # decompress

# ── zip ───────────────────────────────────────────────────────────────────────
zip -r archive.zip dir/      # zip directory
unzip archive.zip            # extract
unzip -l archive.zip         # list contents

# ── rsync: efficient file sync ────────────────────────────────────────────────
rsync -avz src/ dst/                            # local sync: verbose, archive, compress
rsync -avz src/ user@host:/remote/path/        # sync to remote server
rsync -avz --delete src/ dst/                  # mirror: delete files not in source
rsync -avz --exclude="node_modules" src/ dst/  # exclude pattern
rsync -avzn src/ dst/                          # dry-run: show what would change
```

---

## Environment & Variables

```bash
# ── Environment variables ─────────────────────────────────────────────────────
env                          # print all environment variables
printenv PATH                # print a specific variable
echo $HOME                   # expand variable inline

export MY_VAR="hello"        # set + export to child processes
MY_VAR="hello"               # set only in current shell (not exported)
unset MY_VAR                 # delete variable

# ── PATH management ───────────────────────────────────────────────────────────
echo $PATH                   # current search path for executables
export PATH="$HOME/.local/bin:$PATH"   # prepend to PATH
which nginx                  # find location of executable in PATH
type nginx                   # like which, but also shows aliases/functions
command -v node              # POSIX-portable way to check if command exists

# ── Shell config files ────────────────────────────────────────────────────────
# ~/.bashrc         → sourced for every interactive non-login shell
# ~/.bash_profile   → sourced for login shells (SSH, TTY login)
# ~/.profile        → POSIX fallback, sourced by bash if .bash_profile missing
# /etc/environment  → system-wide variables (not a shell script, just KEY=VALUE)
# /etc/profile      → system-wide login shell config
# /etc/profile.d/   → drop-in files sourced by /etc/profile

source ~/.bashrc             # reload config without opening new terminal
. ~/.bashrc                  # same (POSIX syntax)
```

---

## Disk & System Information

```bash
# ── Disk usage ────────────────────────────────────────────────────────────────
df -h                        # filesystem disk usage (human-readable)
df -hT                       # include filesystem type
du -sh /var/log/             # total size of a directory
du -sh /var/log/*            # size of each item in /var/log/
du -sh * | sort -rh | head -10  # top 10 largest items in current dir
ncdu /                       # interactive disk usage browser (apt install ncdu)

# ── Memory ────────────────────────────────────────────────────────────────────
free -h                      # RAM and swap usage
free -h -s 2                 # update every 2 seconds
cat /proc/meminfo            # detailed memory statistics

# ── System info ───────────────────────────────────────────────────────────────
uname -a                     # kernel version, arch, hostname
uname -r                     # kernel version only
cat /etc/os-release          # distro and version
lscpu                        # CPU info: cores, threads, architecture
lsmem                        # memory info
lsblk                        # block devices (disks, partitions)
lsblk -f                     # with filesystem types and mount points
lspci                        # PCI devices (GPUs, network cards)
lsusb                        # USB devices
dmidecode -t memory          # physical RAM slots (requires root)

# ── Uptime & load ─────────────────────────────────────────────────────────────
uptime                       # uptime + load average (1, 5, 15 min)
# Load average: number of processes waiting for CPU
# Load 1.0 on a 4-core machine = 25% utilised. Load 4.0 = 100%.
w                            # who is logged in + their activity
last                         # login history
```

---

## Output Redirection & Pipes

```bash
# ── Redirection ───────────────────────────────────────────────────────────────
command > file.txt           # stdout to file (overwrite)
command >> file.txt          # stdout to file (append)
command 2> errors.txt        # stderr to file
command 2>&1                 # redirect stderr to same destination as stdout
command > out.txt 2>&1       # stdout + stderr to same file
command &> file.txt          # bash shorthand for stdout + stderr to file
command > /dev/null          # discard stdout (null device)
command > /dev/null 2>&1     # discard all output

# ── Pipes: chain commands ─────────────────────────────────────────────────────
cmd1 | cmd2                  # stdout of cmd1 → stdin of cmd2
cmd1 | cmd2 | cmd3           # chain multiple commands

# Real examples:
cat /etc/passwd | grep bash | awk -F: '{print $1}'  # users with bash shell
ps aux | sort -k3 -rn | head -10   # top 10 processes by CPU
journalctl -u nginx | grep error | tail -50   # last 50 nginx errors

# ── tee: write to file AND pass to next command ───────────────────────────────
command | tee output.txt             # write to file AND display in terminal
command | tee -a output.txt          # append (don't overwrite)
command | tee output.txt | grep err  # write all, filter for display

# ── Process substitution ──────────────────────────────────────────────────────
diff <(ls dir1/) <(ls dir2/)         # diff output of two commands
comm <(sort a.txt) <(sort b.txt)     # compare sorted files

# ── Here-doc: multi-line input ────────────────────────────────────────────────
cat << 'EOF' > config.txt
server {
    listen 80;
}
EOF

# ── xargs vs pipes ────────────────────────────────────────────────────────────
# Some commands don't accept stdin — use xargs to convert stdin to arguments
echo "file1 file2" | xargs rm       # rm doesn't read stdin, xargs converts it
find . -name "*.log" | xargs gzip   # gzip all found log files
```

---

## User & Group Management

```bash
# ── Users ─────────────────────────────────────────────────────────────────────
whoami                       # current username
id                           # UID, GID, and group memberships
id alice                     # same for another user
who                          # who is currently logged in
w                            # logged-in users + what they're running

# Adding and managing users:
useradd -m -s /bin/bash alice        # create user with home dir + bash shell
useradd -m -G sudo,docker alice      # add to groups at creation
usermod -aG docker alice             # add existing user to docker group (-a = append!)
passwd alice                         # set password
userdel alice                        # delete user (keeps home dir)
userdel -r alice                     # delete user + home dir + mail spool

# ── Groups ────────────────────────────────────────────────────────────────────
groupadd developers          # create group
groups alice                 # list alice's groups
gpasswd -a alice developers  # add alice to developers group
gpasswd -d alice developers  # remove alice from developers group

# ── sudo ──────────────────────────────────────────────────────────────────────
sudo command                 # run as root
sudo -u alice command        # run as another user
sudo su -                    # switch to root shell (full environment)
sudo -l                      # list what current user can sudo
visudo                       # safely edit /etc/sudoers

# /etc/sudoers examples (edit with visudo):
# alice ALL=(ALL:ALL) ALL              → alice can run any command as root
# %developers ALL=(ALL) NOPASSWD:ALL  → developers group, no password
# alice ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx  → specific command only
```

---

## Package Management

```bash
# ── Ubuntu / Debian (apt) ─────────────────────────────────────────────────────
apt update                   # refresh package index
apt upgrade                  # upgrade installed packages
apt full-upgrade             # upgrade + remove obsolete packages
apt install nginx            # install
apt install -y nginx         # install without prompt (for scripts)
apt remove nginx             # remove (keep config files)
apt purge nginx              # remove + delete config files
apt autoremove               # remove unused dependencies
apt search "text editor"     # search available packages
apt show nginx               # package details
dpkg -l | grep nginx         # check if installed
dpkg -L nginx                # list files installed by package

# ── RHEL / CentOS / Fedora (dnf / yum) ───────────────────────────────────────
dnf install nginx            # install
dnf update                   # update all packages
dnf remove nginx             # remove
dnf search nginx             # search
dnf info nginx               # package details
rpm -qa | grep nginx         # list installed packages matching nginx
rpm -ql nginx                # list files installed by package

# ── systemd: manage services ──────────────────────────────────────────────────
systemctl start nginx        # start service
systemctl stop nginx         # stop service
systemctl restart nginx      # stop + start
systemctl reload nginx       # reload config without stopping (if supported)
systemctl enable nginx       # auto-start on boot
systemctl disable nginx      # remove auto-start
systemctl status nginx       # current status + last log lines
systemctl is-active nginx    # returns 0 if active (useful in scripts)
systemctl list-units --type=service --state=running  # all running services
journalctl -u nginx          # logs for nginx service
journalctl -u nginx -f       # follow logs
journalctl -u nginx --since "1 hour ago"
journalctl -p err            # only error-level messages
```