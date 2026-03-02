# 🔑 SSH Hardening

> SSH is usually the only door into your server. Hardening it means eliminating weak authentication methods, restricting who can connect, controlling what they can do once connected, and logging everything. A misconfigured SSH daemon is responsible for a huge fraction of real-world server compromises.

---

## sshd_config — The Complete Hardened Configuration

```bash
# /etc/ssh/sshd_config
# After editing: sshd -t && systemctl reload sshd

# ── Protocol and listening ────────────────────────────────────────────────────
Port 22                         # consider 2222 or another port to reduce log noise
#                               # (obscurity, not security — but cuts 99% of brute-force noise)
AddressFamily inet              # inet = IPv4 only; inet6 = IPv6; any = both
ListenAddress 0.0.0.0           # restrict to management interface IP if possible

# ── Authentication: disable everything weak ───────────────────────────────────
PermitRootLogin no                       # NEVER allow direct root login
PasswordAuthentication no                # DISABLE password auth — keys only
PubkeyAuthentication yes                 # enable public key auth
AuthorizedKeysFile .ssh/authorized_keys  # where to find public keys

ChallengeResponseAuthentication no       # disable PAM keyboard-interactive
KerberosAuthentication no
GSSAPIAuthentication no
UsePAM yes                               # keep PAM for account/session management

# For certificate-based auth (recommended at scale):
TrustedUserCAKeys /etc/ssh/ca_user_key.pub

# ── Connection limits ─────────────────────────────────────────────────────────
MaxAuthTries 3                  # disconnect after 3 failed attempts
MaxSessions 10                  # max multiplexed sessions per connection
LoginGraceTime 20               # seconds to authenticate before disconnect
MaxStartups 10:30:60            # rate-limit unauthenticated connections
#   10 = start dropping at 10 pending connections
#   30 = 30% drop rate
#   60 = reject all above 60 pending connections

# ── Access control ────────────────────────────────────────────────────────────
AllowUsers alice bob deploy           # WHITELIST: only these users can SSH
# AllowGroups sshusers              # or: only members of this group
# DenyUsers guest tempuser          # blacklist (prefer AllowUsers)

# ── Session security ──────────────────────────────────────────────────────────
ClientAliveInterval 300         # send keepalive every 5 min
ClientAliveCountMax 2           # disconnect after 2 missed keepalives (10 min total)
TCPKeepAlive no                 # use SSH-level keepalive, not TCP-level

# ── Disable unused features ────────────────────────────────────────────────────
X11Forwarding no                # disable X11 GUI forwarding (attack surface)
AllowTcpForwarding no           # disable port forwarding (enable only when needed)
AllowAgentForwarding no         # disable agent forwarding (security risk on untrusted hosts)
PermitTunnel no                 # disable tun device tunnelling
PrintMotd no                    # suppress message-of-the-day
Banner /etc/ssh/banner.txt      # show legal warning before auth (for compliance)
PrintLastLog yes                # show last login info (helps detect unauthorized access)

# ── Cryptographic algorithms: restrict to modern only ─────────────────────────
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256

# Remove weak host keys if present:
# (ed25519 and rsa 4096 only)
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
# Do NOT include: ssh_host_dsa_key, ssh_host_ecdsa_key (weak)

# ── Logging ───────────────────────────────────────────────────────────────────
SyslogFacility AUTH
LogLevel VERBOSE                # logs fingerprint of key used for auth (useful for audits)
# VERBOSE: "Accepted publickey for alice: ED25519 SHA256:abc123..."
```

---

## SSH Banner (Legal Warning)

```bash
# /etc/ssh/banner.txt
# Shown to connecting users BEFORE authentication
cat > /etc/ssh/banner.txt << 'EOF'
*******************************************************************************
  WARNING: Unauthorized access to this system is prohibited.
  All connections are monitored and logged.
  Disconnect immediately if you are not an authorized user.
*******************************************************************************
EOF

# Enable in sshd_config:
# Banner /etc/ssh/banner.txt
```

---

## SSH Key Hardening

```bash
# ── Remove weak host keys ─────────────────────────────────────────────────────
rm -f /etc/ssh/ssh_host_dsa_key*      # DSA is broken
rm -f /etc/ssh/ssh_host_ecdsa_key*    # ECDSA has known issues with bad RNG
# Keep only:
ls /etc/ssh/ssh_host_*
# ssh_host_ed25519_key
# ssh_host_ed25519_key.pub
# ssh_host_rsa_key           (4096-bit RSA for legacy compatibility)
# ssh_host_rsa_key.pub

# Regenerate host keys with strong parameters:
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" < /dev/null
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N "" < /dev/null

# Fix permissions:
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

# ── Strengthen Diffie-Hellman moduli ──────────────────────────────────────────
# Remove short DH moduli (< 3072 bits) from /etc/ssh/moduli
# These are used for DH group exchange
awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.tmp
mv /etc/ssh/moduli.tmp /etc/ssh/moduli

# ── Per-key restrictions in authorized_keys ───────────────────────────────────
# /root/.ssh/authorized_keys or /home/alice/.ssh/authorized_keys

# Restrict a key to a specific command only (for automation):
command="/usr/local/bin/deploy.sh",no-pty,no-agent-forwarding,no-port-forwarding ssh-ed25519 AAAA... deploy-bot

# Restrict to a source IP range:
from="10.0.0.0/8,192.168.1.0/24",no-pty ssh-ed25519 AAAA... office-vpn-only

# Expiry date (OpenSSH 8.2+):
expiry-time="20261231",no-pty ssh-ed25519 AAAA... temp-contractor-dec2026

# Environment restriction:
environment="ROLE=readonly",no-pty ssh-ed25519 AAAA... readonly-access
```

---

## Fail2ban for SSH Brute-Force Protection

```bash
# ── Install ───────────────────────────────────────────────────────────────────
apt install fail2ban

# ── Configure SSH jail ────────────────────────────────────────────────────────
# /etc/fail2ban/jail.d/ssh-hardened.conf
[sshd]
enabled   = true
port      = ssh
logpath   = %(sshd_log)s
backend   = %(sshd_backend)s
maxretry  = 3              # ban after 3 failures
findtime  = 300            # within a 5-minute window
bantime   = 3600           # ban for 1 hour
banaction = iptables-multiport
ignoreip  = 127.0.0.1/8 10.0.0.0/8 192.168.0.0/16  # never ban these IPs

# Aggressive: permanent ban after repeated offences
[sshd-aggressive]
enabled   = true
port      = ssh
logpath   = %(sshd_log)s
filter    = sshd
maxretry  = 10             # if 10 attempts in 1 hour:
findtime  = 3600
bantime   = -1             # ban permanently (-1 = infinite)

# ── Manage bans ───────────────────────────────────────────────────────────────
fail2ban-client status                    # overview of all jails
fail2ban-client status sshd               # SSH jail: banned IPs, total bans
fail2ban-client set sshd banip 1.2.3.4   # manually ban an IP
fail2ban-client set sshd unbanip 1.2.3.4  # unban an IP
fail2ban-client reload                    # reload config

# View banned IPs:
iptables -n -L f2b-sshd                  # iptables chain for fail2ban

# ── Test your config ──────────────────────────────────────────────────────────
fail2ban-client -d                        # dump config (check it's loading correctly)
fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf  # test regex on logs
```

---

## Two-Factor Authentication for SSH

```bash
# ── Install Google Authenticator PAM module ───────────────────────────────────
apt install libpam-google-authenticator

# ── Set up for a user ─────────────────────────────────────────────────────────
google-authenticator
# → y: time-based tokens
# → Save the QR code / secret key
# → y: update .google_authenticator file
# → y: disallow reuse
# → n: don't increase window (more security, tighter window)
# → y: enable rate limiting (max 3 attempts per 30s)

# ── PAM configuration ─────────────────────────────────────────────────────────
# /etc/pam.d/sshd
# Add at the TOP of the file:
auth required pam_google_authenticator.so nullok
# nullok = users without .google_authenticator set up can still login with key only
# Remove nullok after all users have enrolled

# ── sshd_config: require both key AND TOTP ────────────────────────────────────
# /etc/ssh/sshd_config
AuthenticationMethods publickey,keyboard-interactive
# Requires: 1. valid SSH public key, 2. TOTP code
ChallengeResponseAuthentication yes    # needed for keyboard-interactive
UsePAM yes

systemctl reload sshd

# ── Testing ───────────────────────────────────────────────────────────────────
ssh alice@server
# Authenticated with partial success.
# Verification code: [enter TOTP code from authenticator app]
```

---

## SSH Certificate Authority (Scalable Key Management)

For fleets of servers, SSH certificates eliminate the need to copy `authorized_keys` to every server.

```bash
# ── Create a User CA ──────────────────────────────────────────────────────────
# Keep this key in a secrets vault (Vault, HSM, or encrypted offline storage)
ssh-keygen -t ed25519 -f /etc/ssh/ca_user_key -C "Production User CA"
ssh-keygen -t ed25519 -f /etc/ssh/ca_host_key -C "Production Host CA"

# ── Configure servers to trust the CA ─────────────────────────────────────────
# /etc/ssh/sshd_config on EVERY server:
TrustedUserCAKeys /etc/ssh/ca_user_key.pub
# No need to manage authorized_keys files on individual servers

# ── Sign a user's public key ──────────────────────────────────────────────────
ssh-keygen -s /etc/ssh/ca_user_key \
  -I "alice@company.com" \          # identity (audit trail)
  -n "ubuntu,ec2-user,deploy" \    # valid principals (login names)
  -V +8h \                         # valid for 8 hours (short-lived!)
  -z $(date +%s) \                 # unique serial number
  ~/.ssh/id_ed25519.pub
# Output: ~/.ssh/id_ed25519-cert.pub

# Inspect:
ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub

# ── Host certificates (client verifies server, not just known_hosts) ──────────
ssh-keygen -s /etc/ssh/ca_host_key \
  -I "prod-web-01.example.com" \
  -h \                             # -h = host certificate
  -n "prod-web-01.example.com,prod-web-01,10.0.1.10" \
  -V +365d \
  /etc/ssh/ssh_host_ed25519_key.pub

# /etc/ssh/sshd_config on the server:
HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub

# Client ~/.ssh/known_hosts (trusts the Host CA instead of individual host keys):
@cert-authority *.example.com ssh-ed25519 AAAA...host-ca-pub-key...

# ── Revocation ────────────────────────────────────────────────────────────────
# Create/update Key Revocation List:
ssh-keygen -k -f /etc/ssh/revoked-keys         # create new KRL
ssh-keygen -k -f /etc/ssh/revoked-keys \
  -u -z 1234 /dev/null                         # add serial 1234 to KRL

# /etc/ssh/sshd_config:
RevokedKeys /etc/ssh/revoked-keys
```

---

## SSH Audit & Monitoring

```bash
# ── Monitor live SSH connections ──────────────────────────────────────────────
who                             # currently logged-in users
w                               # logged-in users + what they're doing
last | head -20                 # recent logins
lastb | head -20                # recent FAILED logins
ss -tnp | grep ':22'            # active SSH connections (+ PIDs)

# ── Parse auth logs for anomalies ────────────────────────────────────────────
# Failed attempts by IP (brute-force detection):
grep "Failed password\|Invalid user" /var/log/auth.log | \
  awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -20

# Successful logins (for unexpected access detection):
grep "Accepted" /var/log/auth.log | \
  awk '{print $1,$2,$3,$9,$11}' | tail -20

# Logins outside business hours (7pm–7am and weekends):
grep "Accepted" /var/log/auth.log | \
  awk '{
    split($3, t, ":");
    if (t[1] < 7 || t[1] >= 19) print "AFTER_HOURS:", $0
  }'

# ── ssh-audit: comprehensive SSH server audit tool ────────────────────────────
pip install ssh-audit
ssh-audit localhost              # or
docker run -it positronsecurity/ssh-audit:latest localhost

# Reports: weak algorithms, missing options, scoring
# Fix issues reported and re-run until score is A+

# ── Regular audit checklist ───────────────────────────────────────────────────
# □ Run ssh-audit — no warnings
# □ No password authentication in logs (should only see publickey)
# □ No root logins in auth.log
# □ All authorized_keys reviewed — no unknown keys
# □ fail2ban is running: fail2ban-client status sshd
# □ Only expected users in AllowUsers list
# □ All SSH host keys are ed25519 or RSA 4096
```