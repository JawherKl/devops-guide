# 🛡️ Linux System Hardening

> A freshly installed Linux server is not secure by default — it has services enabled that you don't need, default configurations that favour convenience over security, and no audit trail. Hardening means systematically reducing the attack surface: removing what you don't need, tightening what remains, and ensuring every significant action is logged.

---

## The CIS Benchmark

The CIS (Center for Internet Security) Benchmark is the authoritative checklist for Linux hardening. It has two levels:

- **Level 1**: Practical, low-impact changes every system should have. Minimal performance effect.
- **Level 2**: Defense-in-depth additions. May affect functionality — evaluate before applying.

```bash
# Automated CIS audit tool
docker run --rm --pid=host --cap-add=SYS_PTRACE \
  -v /:/host:ro \
  -v /etc:/etc:ro \
  docker.io/cisecurity/cis-cat-lite:latest \
  --benchmark CIS_Ubuntu_Linux_22.04_LTS_Benchmark

# Alternative: Lynis (open-source hardening auditor)
apt install lynis
lynis audit system                    # full audit + hardening index score
lynis audit system --quick            # quick audit
lynis show details BOOT-5264          # detail on a specific check

# OpenSCAP
apt install libopenscap8 scap-security-guide
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results results.xml \
  --report report.html \
  /usr/share/xml/scap/ssg/content/ssg-ubuntu2204-ds.xml
```

---

## Filesystem Hardening

```bash
# ── /etc/fstab: mount options that remove capabilities ───────────────────────
# /tmp: no execution, no device files, no SUID
tmpfs  /tmp     tmpfs  defaults,nodev,nosuid,noexec,size=2g  0 0
# /dev/shm: shared memory — same restrictions
tmpfs  /dev/shm tmpfs  defaults,nodev,nosuid,noexec          0 0
# /home: no device files, no SUID
UUID=...  /home  ext4  defaults,nodev,nosuid                 0 2
# /var: no execution
UUID=...  /var   ext4  defaults,nodev,nosuid,noexec          0 2

# Remount if already mounted:
mount -o remount,noexec,nosuid,nodev /tmp

# ── Disable unused filesystems ────────────────────────────────────────────────
# /etc/modprobe.d/cis-hardening.conf
cat > /etc/modprobe.d/cis-hardening.conf << 'EOF'
install cramfs   /bin/false
install freevxfs /bin/false
install jffs2    /bin/false
install hfs      /bin/false
install hfsplus  /bin/false
install squashfs /bin/false
install udf      /bin/false
install vfat     /bin/false
EOF

# ── Sticky bit on world-writable directories ─────────────────────────────────
# Prevents users deleting each other's files:
chmod +t /tmp /var/tmp

# Find world-writable files and directories that shouldn't be:
find / -xdev -type d -perm -0002 -not -perm -1000 2>/dev/null   # world-writable dirs without sticky
find / -xdev -type f -perm -0002 2>/dev/null                     # world-writable files

# ── Remove SUID/SGID where not needed ────────────────────────────────────────
# List all SUID binaries (know exactly what's on your system):
find / -perm /4000 -type f 2>/dev/null | sort > /root/suid-audit-$(date +%Y%m%d).txt
# Remove SUID where not required:
chmod u-s /usr/bin/at        # Example: remove at SUID if not needed
```

---

## User & Account Hardening

```bash
# ── Password policy ───────────────────────────────────────────────────────────
# /etc/login.defs
PASS_MAX_DAYS   90      # maximum password age
PASS_MIN_DAYS   7       # minimum days before change
PASS_WARN_AGE   14      # warn this many days before expiry
PASS_MIN_LEN    14      # minimum password length (libpam-pwquality enforces this)

# PAM password quality: /etc/security/pwquality.conf
minlen  = 14
minclass = 3            # require at least 3 of: uppercase, lowercase, digit, special
maxrepeat = 3           # no more than 3 consecutive same characters
gecoscheck = 1          # don't allow username in password

# ── Lock inactive accounts ────────────────────────────────────────────────────
useradd -D -f 30        # lock accounts inactive for 30 days after password expiry

# Apply to existing user:
chage -I 30 alice       # lock after 30 days of inactivity
chage -l alice          # view account aging info

# ── Disable root account (use sudo instead) ───────────────────────────────────
passwd -l root           # lock root password (disables password login)
# SSH: PermitRootLogin no in /etc/ssh/sshd_config
# Still accessible via: sudo su - (if your user has full sudo)

# ── Remove unused default accounts ───────────────────────────────────────────
# Check for accounts with shells that shouldn't have them:
awk -F: '$7 !~ /nologin|false|sync|halt|shutdown/ {print $1, $7}' /etc/passwd
# Lock service accounts:
usermod -s /usr/sbin/nologin www-data
usermod -s /usr/sbin/nologin nobody

# ── /etc/sudoers hardening ────────────────────────────────────────────────────
# /etc/sudoers (always edit with: visudo)
Defaults  env_reset
Defaults  mail_badpass
Defaults  secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Defaults  logfile="/var/log/sudo.log"   # log all sudo commands
Defaults  log_input                      # log stdin (captures commands in shells)
Defaults  log_output                     # log stdout (captures output)
Defaults  use_pty                        # prevent sudo escalation tricks
Defaults  timestamp_timeout=5           # require re-auth after 5 min inactivity
Defaults  !visiblepw                     # never echo password

# Grant specific commands only (not ALL):
deploy  ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx, /bin/systemctl reload nginx
# Never: deploy ALL=(ALL) NOPASSWD: ALL

# ── Empty password audit ──────────────────────────────────────────────────────
awk -F: '($2 == "" || $2 == "!") {print "WARNING empty/locked: " $1}' /etc/shadow
```

---

## Service & Package Hardening

```bash
# ── List and disable unused services ─────────────────────────────────────────
systemctl list-units --type=service --state=running    # see what's running
systemctl list-unit-files --type=service --state=enabled  # see what starts on boot

# Disable common services that are usually unnecessary on servers:
systemctl disable --now avahi-daemon   # mDNS/Zeroconf discovery
systemctl disable --now cups           # printing
systemctl disable --now rpcbind        # NFS prerequisite (if no NFS)
systemctl disable --now nfs-server     # NFS server
systemctl disable --now bluetooth      # Bluetooth
systemctl disable --now iscsid         # iSCSI (unless using SAN)

# ── Remove unused packages ────────────────────────────────────────────────────
apt purge telnet                       # replace with SSH
apt purge rsh-client rsh-server        # obsolete remote shell
apt purge ftp                          # replace with sftp/scp
apt purge talk ntalk                   # obsolete chat
apt autoremove                         # remove orphaned packages

# ── Minimal package principle ─────────────────────────────────────────────────
# Every installed package is an attack surface. Install only what you need.
apt list --installed 2>/dev/null | wc -l   # count installed packages
dpkg -l | awk '{print $2}' | xargs apt-mark showauto  # auto-installed packages

# ── Check for listening services (attack surface audit) ───────────────────────
ss -tlnp                    # TCP listening
ss -ulnp                    # UDP listening
# Investigate anything unexpected — every listener is an exposure
```

---

## Kernel Hardening (sysctl)

```bash
# /etc/sysctl.d/99-hardening.conf
# Apply with: sysctl --system

# ── Network: disable dangerous features ──────────────────────────────────────
# IP source routing: allows packets to dictate their route (used in attacks)
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Redirect acceptance: prevents MITM by ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Send redirects only if acting as a router:
net.ipv4.conf.all.send_redirects = 0

# Log suspicious packets (martian packets: packets with impossible source addresses)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Disable ICMP broadcast (Smurf amplification attack mitigation)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable reverse path filtering (prevents IP spoofing)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# TCP SYN flood protection (SYN cookies)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2

# Disable IP forwarding (unless this is a router/container host)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# ── Memory: exploit mitigations ───────────────────────────────────────────────
# Restrict access to kernel pointers in /proc (prevents ASLR bypass)
kernel.kptr_restrict = 2

# Disable dmesg for unprivileged users (kernel info leakage)
kernel.dmesg_restrict = 1

# Restrict ptrace: only parent process can trace child (default=0=any process)
kernel.yama.ptrace_scope = 1

# Disable core dumps for SUID programs
fs.suid_dumpable = 0

# Randomise memory layout (ASLR: Address Space Layout Randomization)
# 0=disabled, 1=conservative, 2=full
kernel.randomize_va_space = 2

# ── Filesystem ─────────────────────────────────────────────────────────────────
# Restrict hardlinks and symlinks (prevent certain privilege escalation attacks)
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 1
fs.protected_regular = 2

# Apply immediately:
sysctl --system
sysctl -p /etc/sysctl.d/99-hardening.conf
```

---

## Mandatory Access Control — AppArmor

AppArmor confines programs to a set of permitted operations defined in a profile. Even if a process is compromised, it cannot exceed its profile.

```bash
# ── Status ────────────────────────────────────────────────────────────────────
aa-status                              # list profiles and their modes
apparmor_status                        # same

# ── Modes ─────────────────────────────────────────────────────────────────────
# enforce: policy violations are BLOCKED and logged
# complain: violations are LOGGED but allowed (use for testing profiles)
# disabled: profile loaded but not enforced

# ── Manage profiles ──────────────────────────────────────────────────────────
aa-enforce /etc/apparmor.d/usr.sbin.nginx    # switch to enforce
aa-complain /etc/apparmor.d/usr.sbin.nginx   # switch to complain (test mode)
aa-disable /etc/apparmor.d/usr.sbin.nginx    # disable profile

# ── Generate a profile for a new program ─────────────────────────────────────
aa-genprof /usr/local/bin/myapp        # interactive profile generator
# Run the app through its normal use cases, then:
# S = save, F = finish

# ── Update an existing profile (after new behaviour is observed) ─────────────
aa-logprof                             # scan logs for denials, suggest rule additions

# ── Writing a profile ─────────────────────────────────────────────────────────
# /etc/apparmor.d/usr.local.bin.myapp
#include <tunables/global>

/usr/local/bin/myapp {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  # Allow reading config files
  /etc/myapp/config.yaml  r,
  /etc/myapp/**           r,

  # Allow writing to log directory only
  /var/log/myapp/         rw,
  /var/log/myapp/**       rw,

  # Allow network connections (outbound TCP)
  network tcp,

  # Allow specific syscalls
  capability net_bind_service,   # bind ports < 1024

  # Deny everything else implicitly
}

# Load and enforce:
apparmor_parser -r /etc/apparmor.d/usr.local.bin.myapp
aa-enforce /etc/apparmor.d/usr.local.bin.myapp

# View AppArmor denials in logs:
journalctl | grep apparmor | grep DENIED | tail -20
grep DENIED /var/log/audit/audit.log | grep apparmor
```

---

## Audit Daemon (auditd)

`auditd` records security-relevant events to a tamper-evident log. It's your CCTV for the filesystem and system calls.

```bash
# ── Install and enable ────────────────────────────────────────────────────────
apt install auditd audispd-plugins
systemctl enable --now auditd

# ── Audit rules ──────────────────────────────────────────────────────────────
# /etc/audit/rules.d/hardening.rules

# Delete existing rules and set buffers
-D
-b 8192
-f 1          # 0=silent, 1=printk on failure, 2=panic on failure (use 1 in prod)

# Monitor identity-affecting files (account changes)
-w /etc/passwd  -p wa -k identity
-w /etc/shadow  -p wa -k identity
-w /etc/group   -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k privileged

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd-config

# Monitor privileged commands
-a always,exit -F path=/usr/bin/sudo    -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/su      -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/newgrp  -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/bin/umount      -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged

# Monitor network config changes
-w /etc/network/   -p wa -k network-config
-w /etc/sysctl.conf -p wa -k sysctl
-w /etc/sysctl.d/  -p wa -k sysctl

# Monitor mount operations
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts

# Monitor file deletion by users
-a always,exit -F arch=b64 -S unlinkat -S rename -S rmdir -F auid>=1000 -F auid!=4294967295 -k delete

# Monitor kernel module loading
-w /sbin/insmod  -p x -k modules
-w /sbin/rmmod   -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# Make rules immutable until reboot (prevents tampering):
-e 2

# ── Apply rules ───────────────────────────────────────────────────────────────
augenrules --load
systemctl restart auditd
auditctl -l                            # list active rules

# ── Searching audit logs ──────────────────────────────────────────────────────
ausearch -k identity                   # events tagged with "identity" key
ausearch -k privileged --start today   # today's sudo/su events
ausearch -k identity -ts yesterday -te today  # date range
ausearch -m USER_LOGIN -ts recent      # recent login events
ausearch -f /etc/passwd                # events touching /etc/passwd
ausearch -ua alice                     # all events for user alice

# Generate readable report:
aureport                               # summary of all event types
aureport -au                           # authentication report
aureport -x --failed                   # failed executable events
aureport --login -i                    # login report (human-readable)
```