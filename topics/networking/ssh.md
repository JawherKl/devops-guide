# 🔐 SSH

> SSH (Secure Shell) is the primary protocol for securely accessing and managing remote Linux servers. Every DevOps workflow touches SSH — from logging into a cloud VM, to authenticating Git pushes, to tunnelling traffic, to executing remote commands in CI pipelines. Understanding SSH deeply means faster debugging, better security, and fewer "permission denied" errors.

---

## How SSH Works

```
Client (your machine)                   Server (remote host)
────────────────────                    ──────────────────────────────
                                        sshd daemon listening on :22

1. TCP connection to port 22
   ─────────────────────────────────────────────────────────►

2. Server sends its host public key
   ◄─────────────────────────────────────────────────────────
   Client checks ~/.ssh/known_hosts:
   • First time: "The authenticity of host can't be established" → add it
   • Known host: verify signature matches → continue
   • MISMATCH: WARNING — possible MITM attack → abort

3. Key exchange (ECDH) → both sides derive the same session key
   ◄────────────────────────────────────────────────────────►
   All traffic from here is encrypted with AES/ChaCha20

4. Authentication (client proves identity)
   • Password: client sends password, encrypted in the session
   • Public key: server challenges with random data, client signs
     with private key → server verifies with stored public key
   ─────────────────────────────────────────────────────────►

5. Shell / command / port forward session
   ◄────────────────────────────────────────────────────────►
```

---

## Key Generation & Management

```bash
# ── Generate a key pair ───────────────────────────────────────────────────────
ssh-keygen -t ed25519 -C "jawher@example.com"
# -t ed25519    → Edwards-curve algorithm (modern, fast, secure — use this)
# -C "comment"  → embedded in the public key (identifies who owns it)
# Output:
#   ~/.ssh/id_ed25519       ← PRIVATE key — never share this
#   ~/.ssh/id_ed25519.pub   ← PUBLIC key  — safe to share

# Generate RSA (for legacy systems that don't support Ed25519):
ssh-keygen -t rsa -b 4096 -C "jawher@example.com"

# Generate with a specific filename (for multiple identities):
ssh-keygen -t ed25519 -f ~/.ssh/id_github -C "github-jawher"
ssh-keygen -t ed25519 -f ~/.ssh/id_work   -C "work-jawher"

# Set passphrase on existing key (protect private key if laptop is stolen):
ssh-keygen -p -f ~/.ssh/id_ed25519

# ── View key info ─────────────────────────────────────────────────────────────
cat ~/.ssh/id_ed25519.pub                    # view public key
ssh-keygen -l -f ~/.ssh/id_ed25519           # fingerprint (use to verify with server admin)
ssh-keygen -l -E md5 -f ~/.ssh/id_ed25519   # MD5 fingerprint (for older systems)

# ── SSH key permissions — CRITICAL ────────────────────────────────────────────
# SSH REFUSES to use keys with wrong permissions:
chmod 700 ~/.ssh                             # only owner can enter
chmod 600 ~/.ssh/id_ed25519                  # private key: owner read/write ONLY
chmod 644 ~/.ssh/id_ed25519.pub              # public key: readable by others is fine
chmod 600 ~/.ssh/authorized_keys            # server's allowed keys
chmod 600 ~/.ssh/config                      # client config
chmod 644 ~/.ssh/known_hosts                 # known hosts
```

---

## Connecting to Remote Servers

```bash
# ── Basic connection ───────────────────────────────────────────────────────────
ssh user@hostname                    # connect as user
ssh user@192.168.1.100              # connect by IP
ssh -p 2222 user@hostname           # non-standard port
ssh -i ~/.ssh/id_work user@hostname  # specify which private key to use
ssh -v user@hostname                 # verbose: debug connection issues
ssh -vvv user@hostname               # maximum verbosity

# ── First connection: verify host fingerprint ──────────────────────────────────
# You'll see:
# The authenticity of host 'example.com (93.184.216.34)' can't be established.
# ED25519 key fingerprint is SHA256:abc123...
# Are you sure you want to continue connecting (yes/no)?
#
# Verify the fingerprint matches what the server admin gave you, then type "yes"
# The host is added to ~/.ssh/known_hosts and won't be asked again

# ── Run a single command without interactive shell ─────────────────────────────
ssh user@host "df -h"
ssh user@host "systemctl status nginx"
ssh user@host "cd /app && git pull && npm run build"

# Run a local script on the remote host:
ssh user@host "bash -s" < local_script.sh

# ── Copy files to/from remote ─────────────────────────────────────────────────
scp file.txt user@host:/remote/path/          # upload file
scp user@host:/remote/file.txt ./             # download file
scp -r ./dir user@host:/remote/               # upload directory (-r recursive)
scp -P 2222 file.txt user@host:/path/         # non-standard port (-P not -p)

# rsync over SSH (more efficient than scp for large/many files):
rsync -avz ./local/ user@host:/remote/        # sync local → remote
rsync -avz user@host:/remote/ ./local/        # sync remote → local
rsync -avz --delete ./local/ user@host:/remote/  # mirror (delete extra remote files)
rsync -avz -e "ssh -p 2222" ./local/ user@host:/remote/  # non-standard port
```

---

## SSH Config File (~/.ssh/config)

The config file lets you define shortcuts for hosts, avoiding long command-line options every time.

```
# ~/.ssh/config
# SSH reads this file for options when connecting to any host

# ── Global defaults (apply to all connections) ────────────────────────────────
Host *
    ServerAliveInterval 60          # send keepalive every 60s (prevents timeout)
    ServerAliveCountMax 3           # disconnect after 3 missed keepalives
    AddKeysToAgent yes              # add key to ssh-agent on first use
    IdentityFile ~/.ssh/id_ed25519  # default private key
    HashKnownHosts yes              # obfuscate hostnames in known_hosts

# ── Specific host aliases ──────────────────────────────────────────────────────
Host prod-web
    HostName 203.0.113.10           # actual IP or FQDN
    User ubuntu                     # login as ubuntu
    IdentityFile ~/.ssh/id_prod     # use prod-specific key
    Port 2222                       # non-standard SSH port

Host staging
    HostName staging.example.com
    User deploy
    IdentityFile ~/.ssh/id_staging

# Usage: ssh prod-web  (instead of: ssh -p 2222 -i ~/.ssh/id_prod ubuntu@203.0.113.10)

# ── GitHub / GitLab aliases ───────────────────────────────────────────────────
Host github.com
    HostName github.com
    User git                        # GitHub always uses "git" as the user
    IdentityFile ~/.ssh/id_github
    AddKeysToAgent yes

Host gitlab.company.com
    HostName gitlab.company.com
    User git
    IdentityFile ~/.ssh/id_work

# ── Jump / bastion host ────────────────────────────────────────────────────────
# Reach internal-server via bastion (you can't reach internal-server directly)
Host bastion
    HostName bastion.example.com
    User ubuntu
    IdentityFile ~/.ssh/id_prod

Host internal-server
    HostName 10.0.1.50              # private IP, only reachable from bastion
    User ubuntu
    IdentityFile ~/.ssh/id_prod
    ProxyJump bastion               # automatically SSH through bastion first

# Usage: ssh internal-server  (SSH tunnels through bastion transparently)

# ── Multiple accounts on same host ────────────────────────────────────────────
Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_github_work

Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_github_personal

# Usage in a Git repo:
# git remote set-url origin git@github-work:company/repo.git
```

---

## Authorized Keys (Server-Side)

```bash
# ── How it works ──────────────────────────────────────────────────────────────
# Server stores allowed public keys in ~/.ssh/authorized_keys
# When client connects with a private key, server checks if matching public key is listed
# If yes → authenticated without password

# ── Add your key to a remote server ──────────────────────────────────────────
ssh-copy-id user@hostname                      # automatic (uses default key)
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host # specific key
ssh-copy-id -p 2222 user@hostname              # non-standard port

# Manual method (when ssh-copy-id isn't available):
cat ~/.ssh/id_ed25519.pub | ssh user@host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# ── authorized_keys format ────────────────────────────────────────────────────
# ~/.ssh/authorized_keys on the SERVER
# One public key per line. Optionally prefix with options:

# Simple (no restrictions):
ssh-ed25519 AAAA...key... comment

# Restrict to specific commands only (great for automated scripts):
command="/usr/local/bin/backup.sh",no-pty,no-agent-forwarding ssh-ed25519 AAAA...key... backup-bot

# Restrict to specific source IP:
from="203.0.113.0/24",no-pty ssh-ed25519 AAAA...key... office-only

# No port forwarding (for users who need shell but not tunnelling):
no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAA...key... limited-user

# Expire key after a date (OpenSSH 8.2+):
expiry-time="20261231",no-pty ssh-ed25519 AAAA...key... temp-contractor
```

---

## SSH Agent

The SSH agent holds decrypted private keys in memory, so you only type the passphrase once per session.

```bash
# ── Start agent ───────────────────────────────────────────────────────────────
eval "$(ssh-agent -s)"               # start agent + set environment variables
# Output: SSH_AUTH_SOCK=/tmp/ssh-.../agent.xxx; export SSH_AUTH_SOCK; SSH_AGENT_PID=...

# Most desktop environments and terminals start the agent automatically.
# Add to ~/.bashrc or ~/.bash_profile if not:
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)"
fi

# ── Manage keys in agent ──────────────────────────────────────────────────────
ssh-add ~/.ssh/id_ed25519            # add key (prompts for passphrase once)
ssh-add ~/.ssh/id_github             # add another key
ssh-add -l                           # list keys currently in agent
ssh-add -L                           # list public keys in agent
ssh-add -d ~/.ssh/id_ed25519         # remove key from agent
ssh-add -D                           # remove ALL keys from agent
ssh-add -t 3600 ~/.ssh/id_ed25519    # add with 1-hour expiry

# ── Agent forwarding ──────────────────────────────────────────────────────────
# Forward your local agent to the remote server.
# Allows: ssh from remote server → other hosts, using your LOCAL keys.
# Use case: ssh into a bastion, then ssh from bastion to internal servers,
#           without copying private keys to the bastion.

ssh -A user@bastion                  # -A enables agent forwarding
# Or in ~/.ssh/config:
# Host bastion
#     ForwardAgent yes

# ⚠️  Security note: only forward agent to servers you FULLY trust.
#     The server admin can use your agent (while connected) to auth as you.
#     Never use ForwardAgent yes in the global Host * block.

# ── Keychain (persist agent across logins on Linux) ───────────────────────────
# apt install keychain
# Add to ~/.bash_profile:
eval "$(keychain --eval --quiet ~/.ssh/id_ed25519)"
```

---

## Port Forwarding & Tunnels

SSH can tunnel TCP traffic through encrypted connections — useful for accessing internal services without VPN.

```bash
# ── Local port forward: access a REMOTE service on your LOCAL machine ─────────
# Scenario: PostgreSQL on 10.0.0.5:5432 is not exposed to internet.
#           You can SSH to bastion.example.com.

ssh -L 5432:10.0.0.5:5432 user@bastion.example.com
# Now:  psql -h localhost -p 5432  connects to 10.0.0.5:5432 via bastion

# Syntax: -L [local_bind:]local_port:remote_host:remote_port
ssh -L 8080:localhost:80 user@remote     # access remote's port 80 on local 8080
ssh -L 0.0.0.0:8080:10.0.0.5:80 user@bastion  # bind on all local interfaces

# Keep-alive tunnel (no interactive shell, background):
ssh -fNL 5432:db.internal:5432 user@bastion
# -f = go to background
# -N = don't execute a command (tunnel only)

# ── Remote port forward: expose a LOCAL service on the REMOTE machine ─────────
# Scenario: your local dev server runs on :3000.
#           You want to demo it to someone via the remote server.

ssh -R 8080:localhost:3000 user@remote
# Now: visiting http://remote:8080 reaches your local :3000

# Make it accessible to the world (GatewayPorts):
# Server /etc/ssh/sshd_config: GatewayPorts yes
ssh -R 0.0.0.0:8080:localhost:3000 user@remote

# ── Dynamic port forward: SOCKS5 proxy ───────────────────────────────────────
# Route ALL traffic through the remote server (like a VPN).
# Useful for: access internal services, test from a different geographic location.

ssh -D 1080 user@remote              # create SOCKS5 proxy on localhost:1080
# -f -N for background:
ssh -fND 1080 user@remote

# Configure browser / curl to use SOCKS5 proxy:
curl --socks5 localhost:1080 http://internal-service/
curl --proxy socks5h://localhost:1080 https://example.com  # socks5h = remote DNS

# ── SSH over HTTPS port (for firewalls that block port 22) ───────────────────
# Server must have sshd also listening on port 443 (or use ProxyCommand).
# ~/.ssh/config:
Host example.com
    Hostname example.com
    Port 443
    # If using a standard HTTPS proxy:
    ProxyCommand openssl s_client -connect %h:443 -quiet 2>/dev/null
```

---

## Server Configuration (/etc/ssh/sshd_config)

```bash
# /etc/ssh/sshd_config — primary server hardening settings

# ── Core settings ─────────────────────────────────────────────────────────────
Port 22                            # change to non-standard (e.g. 2222) to reduce noise
ListenAddress 0.0.0.0              # listen on all interfaces; restrict to specific IP if possible
AddressFamily inet                 # inet = IPv4 only; inet6 = IPv6 only; any = both

# ── Authentication ─────────────────────────────────────────────────────────────
PermitRootLogin no                 # NEVER allow root login directly
PasswordAuthentication no          # DISABLE password auth — key-only
PubkeyAuthentication yes           # enable public key auth
AuthorizedKeysFile .ssh/authorized_keys  # location of authorized keys

ChallengeResponseAuthentication no # disable PAM keyboard-interactive
UsePAM yes                         # keep PAM for account/session management

# For 2FA (TOTP with Google Authenticator):
# AuthenticationMethods publickey,keyboard-interactive
# ChallengeResponseAuthentication yes

# ── Access control ────────────────────────────────────────────────────────────
AllowUsers alice bob deploy        # whitelist specific users (OR use AllowGroups)
AllowGroups sshusers               # only members of this group can SSH
DenyUsers guest nobody             # blacklist (prefer AllowUsers)
AllowGroups sshusers               # only group members can connect

# ── Security hardening ────────────────────────────────────────────────────────
Protocol 2                         # SSHv1 is broken — always use v2 (default now)
MaxAuthTries 3                     # disconnect after 3 failed attempts
MaxSessions 10                     # max multiplexed sessions per connection
LoginGraceTime 30                  # seconds to authenticate before disconnect
ClientAliveInterval 300            # send keepalive every 5 min (detect dead connections)
ClientAliveCountMax 2              # disconnect after 2 missed keepalives
TCPKeepAlive no                    # use SSH-level keepalive instead (more reliable)

# ── Disable unused features ────────────────────────────────────────────────────
X11Forwarding no                   # disable X11 (GUI forwarding) — reduces attack surface
AllowTcpForwarding no              # disable port forwarding (unless you need it)
AllowAgentForwarding no            # disable agent forwarding (unless you need it)
PermitTunnel no                    # disable tun device tunnelling
PrintMotd no                       # suppress message-of-the-day (reduces info leakage)
Banner none                        # suppress pre-auth banner

# ── Algorithms (restrict to modern only) ──────────────────────────────────────
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com

# ── Apply changes ──────────────────────────────────────────────────────────────
sshd -t                            # test config syntax before reloading
systemctl reload sshd              # reload (keeps existing sessions alive)
# OR:
kill -HUP $(cat /run/sshd.pid)     # same as reload via signal
```

---

## SSH Certificates (Advanced)

SSH certificates solve the key distribution problem at scale. Instead of copying public keys to every server, you sign user keys with a CA — servers trust the CA.

```bash
# ── Create a Certificate Authority (CA) ───────────────────────────────────────
# Do this once, keep the CA private key in a secrets vault (Vault, KMS)
ssh-keygen -t ed25519 -f /etc/ssh/ca_user_key -C "User CA"     # signs user keys
ssh-keygen -t ed25519 -f /etc/ssh/ca_host_key -C "Host CA"     # signs host keys

# ── Sign a user's public key ──────────────────────────────────────────────────
ssh-keygen -s /etc/ssh/ca_user_key \       # CA private key to sign with
  -I "alice@example.com" \                 # certificate identity (audit log)
  -n "ubuntu,ec2-user" \                  # valid principals (usernames on servers)
  -V +52w \                               # valid for 52 weeks
  -z 42 \                                 # serial number (for revocation)
  ~/.ssh/id_ed25519.pub                   # key to sign
# Output: ~/.ssh/id_ed25519-cert.pub

# Inspect the certificate:
ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub

# ── Configure server to trust the CA ─────────────────────────────────────────
# /etc/ssh/sshd_config:
TrustedUserCAKeys /etc/ssh/ca_user_key.pub  # trust keys signed by this CA
# No need to copy individual authorized_keys — ANY key signed by the CA works

# ── Revoke a certificate ──────────────────────────────────────────────────────
# Create a KRL (Key Revocation List):
ssh-keygen -k -f /etc/ssh/revoked-keys -z 42   # revoke certificate serial 42
# /etc/ssh/sshd_config:
RevokedKeys /etc/ssh/revoked-keys
```

---

## Multiplexing (Speed Up Repeated Connections)

```bash
# SSH multiplexing reuses an existing connection for new sessions.
# Result: subsequent connections to the same host are nearly instant.

# ~/.ssh/config:
Host *
    ControlMaster auto              # create master connection if none exists
    ControlPath ~/.ssh/sockets/%r@%h:%p   # socket location (%r=user %h=host %p=port)
    ControlPersist 10m              # keep master open 10 min after last session

# Create the socket directory:
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets

# Usage:
ssh user@host                       # first connection: creates master (slight delay)
ssh user@host                       # subsequent: reuses socket (nearly instant)
scp file.txt user@host:/path/       # also reuses socket (fast)

# Check if multiplexed connection is active:
ssh -O check user@host

# Close the master connection:
ssh -O exit user@host
```

---

## Debugging SSH

```bash
# ── Client-side debugging ─────────────────────────────────────────────────────
ssh -v user@host                    # verbose: shows each step
ssh -vv user@host                   # more verbose
ssh -vvv user@host                  # maximum: all debug messages

# Common messages and what they mean:
# "debug1: Offering public key: ~/.ssh/id_ed25519"  → trying this key
# "debug1: Server accepts key"                       → server accepted
# "Permission denied (publickey)"                    → no accepted key found
# "Permissions ... are too open"                     → fix: chmod 600 ~/.ssh/id_ed25519
# "Host key verification failed"                     → known_hosts mismatch
# "Connection refused"                               → sshd not running or port blocked
# "Connection timed out"                             → firewall blocking, wrong IP

# ── Fix known_hosts mismatch (server rebuilt/IP changed) ─────────────────────
ssh-keygen -R hostname              # remove old entry for hostname
ssh-keygen -R 192.168.1.100        # remove by IP
# Then reconnect — you'll be prompted to verify the new fingerprint

# ── Server-side debugging ──────────────────────────────────────────────────────
# View sshd logs:
journalctl -u sshd -f              # follow live
journalctl -u sshd --since "5 min ago"
grep "sshd" /var/log/auth.log      # Ubuntu
grep "sshd" /var/log/secure        # RHEL/CentOS

# Common log messages:
# "Accepted publickey for alice"           → successful login
# "Failed password for alice"              → failed password attempt
# "Invalid user nobody from 1.2.3.4"      → login attempt for nonexistent user
# "Connection closed by 1.2.3.4 [preauth]" → disconnected before authenticating
# "Did not receive identification string"  → non-SSH traffic on port 22

# Test sshd config:
sshd -t                             # test syntax (exit 0 = OK)
sshd -T                             # dump full effective config

# ── Brute-force and fail2ban ──────────────────────────────────────────────────
# Count failed attempts by IP:
grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn

# fail2ban status:
fail2ban-client status sshd
fail2ban-client set sshd unbanip 1.2.3.4   # manually unban an IP
```

---

## Practical Recipes

```bash
# ── Copy your public key to a new server (if ssh-copy-id unavailable) ─────────
cat ~/.ssh/id_ed25519.pub | ssh user@host \
  "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# ── Batch execute a command across many servers ─────────────────────────────
for host in web1 web2 web3 db1 db2; do
    echo "=== $host ==="
    ssh -o ConnectTimeout=5 user@$host "uptime; df -h | grep '/$'"
done

# ── Parallel execution with xargs ─────────────────────────────────────────────
echo "web1 web2 web3" | tr ' ' '\n' | \
  xargs -P3 -I{} ssh user@{} "systemctl restart myapp"
# -P3 = 3 parallel connections

# ── Sync a file to many servers ───────────────────────────────────────────────
for host in web1 web2 web3; do
    rsync -avz nginx.conf user@$host:/etc/nginx/nginx.conf
    ssh user@$host "nginx -t && systemctl reload nginx"
done

# ── SSH escape sequences (when connected to a remote) ─────────────────────────
# Type these during an active SSH session:
# ~.   → terminate connection (useful when session hangs)
# ~C   → open command prompt for port forwarding (add -L/-R tunnel without reconnecting)
# ~#   → list forwarded connections
# ~?   → list all escape sequences

# ── Generate SSH host key (on a new server) ───────────────────────────────────
# Normally done automatically, but if you need to regenerate:
ssh-keygen -A                      # regenerate all missing host keys
ls /etc/ssh/ssh_host_*             # view all host keys

# ── SFTP: secure file transfer ────────────────────────────────────────────────
sftp user@host                     # interactive SFTP session
# Inside sftp:
# ls, cd, pwd            → remote navigation
# lls, lcd, lpwd         → local navigation (l prefix = local)
# get remote_file        → download
# put local_file         → upload
# mget *.log             → download multiple files
# mput *.conf            → upload multiple files
# quit / exit            → disconnect
```