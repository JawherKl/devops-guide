# 👤 Identity & Access Management

> Identity and Access Management (IAM) answers two questions: **Who are you?** (authentication) and **What are you allowed to do?** (authorization). In infrastructure, this means Linux user/group management, SSH key governance, sudo policies, OIDC/SAML for cloud, PAM for authentication enforcement, and least-privilege as a design principle — not an afterthought.

---

## The Principle of Least Privilege

Every user, service, and process should have exactly the permissions it needs — and nothing more. In practice:

```
❌ The anti-patterns:
  • Running application servers as root
  • "Give them sudo ALL so it's easier"
  • One shared service account used by 10 teams
  • API keys with admin scope because the docs said so
  • SSH keys that never expire and are never audited

✅ Least-privilege implementation:
  • Application runs as dedicated non-root user (www-data, appuser)
  • Sudo rules grant only the specific commands needed
  • Each service has its own identity (user, key, role)
  • API keys are scoped to minimum required permissions
  • SSH certificates with 8-hour TTL + principal restrictions
  • All access is logged and reviewed
```

---

## Linux User & Group IAM

```bash
# ── Create service accounts ────────────────────────────────────────────────────
# Service accounts should:
#   - Have no login shell (nologin)
#   - Have no home directory (or a restricted one)
#   - Be used by exactly one service

useradd --system --shell /usr/sbin/nologin --no-create-home \
  --comment "Prometheus monitoring" prometheus

useradd --system --shell /usr/sbin/nologin --home /var/lib/postgres \
  --comment "PostgreSQL database" postgres

useradd --system --shell /usr/sbin/nologin --home /var/lib/vault \
  --comment "HashiCorp Vault" vault

# ── Group-based access control ────────────────────────────────────────────────
# Principle: users get access through group membership
# Makes auditing easy: "who has access to X" = "who is in group X"

groupadd docker           # Docker socket access
groupadd developers       # development team
groupadd ops              # operations team
groupadd readonly         # read-only access (monitoring, auditing)
groupadd sshusers         # who can SSH to this server

# Add user to groups:
usermod -aG docker,developers alice    # -a = APPEND (don't remove existing groups!)
usermod -aG ops,sshusers bob

# View user's groups:
groups alice
id alice

# View group members:
getent group docker

# ── Access matrix: who gets what ──────────────────────────────────────────────
# Document your intended access matrix:
# Group         | SSH | sudo | Docker | DB admin | App deploy
# --------------|-----|------|--------|----------|----------
# ops           |  ✅  |  ✅  |   ✅   |    ✅    |    ✅
# developers    |  ✅  |  ❌  |   ✅   |    ❌    |    ✅
# readonly      |  ✅  |  ❌  |   ❌   |    ❌    |    ❌
# deploy-bot    |  ✅  |  ❌  |   ✅   |    ❌    |    ✅

# Implement with /etc/ssh/sshd_config:
AllowGroups sshusers     # only sshusers group can SSH

# Implement with /etc/sudoers:
%ops ALL=(ALL:ALL) ALL
%developers ALL=(ALL) NOPASSWD: /bin/systemctl restart myapp, /bin/systemctl status myapp
```

---

## sudo Hardening & Audit

```bash
# ── /etc/sudoers: always edit with visudo ─────────────────────────────────────
# visudo validates syntax before saving — prevents locking yourself out

# ── Global defaults ────────────────────────────────────────────────────────────
Defaults  env_reset                        # reset environment to safe defaults
Defaults  env_keep += "LANG LC_ALL"        # preserve locale settings
Defaults  secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Defaults  requiretty                       # must have a real TTY (blocks cron sudo abuse)
Defaults  use_pty                          # allocate pty (prevents certain escalation tricks)
Defaults  logfile="/var/log/sudo.log"      # dedicated log file
Defaults  log_input, log_output            # log all input/output
Defaults  timestamp_timeout=5             # re-auth after 5 min idle
Defaults  passwd_timeout=0.5              # 30-second timeout for password entry
Defaults  badpass_message="Authentication failed."  # generic error (no info leakage)
Defaults  passprompt="[sudo] password for %u: "

# ── Grant specific commands: not ALL ──────────────────────────────────────────

# Operations team: full sudo
%ops ALL=(ALL:ALL) ALL

# Developers: restart/reload specific services only
%developers ALL=(ALL) NOPASSWD: \
    /bin/systemctl restart myapp, \
    /bin/systemctl reload myapp, \
    /bin/systemctl status myapp, \
    /bin/journalctl -u myapp

# CI/CD deploy user: restricted deployment commands
deploy ALL=(ALL) NOPASSWD: \
    /usr/local/bin/deploy.sh, \
    /bin/systemctl restart myapp, \
    /bin/systemctl reload nginx

# Monitoring user: read-only commands
prometheus ALL=(ALL) NOPASSWD: \
    /bin/cat /proc/*, \
    /usr/sbin/ss, \
    /bin/systemctl status *

# ── AVOID: these are common mistakes ──────────────────────────────────────────
# alice ALL=(ALL) NOPASSWD: /bin/bash    # ← full root shell!
# bob ALL=(ALL) NOPASSWD: /usr/bin/vi   # ← vi can spawn a shell: :!/bin/bash
# carol ALL=(ALL) NOPASSWD: /usr/bin/find  # ← find -exec /bin/bash can escalate
# Any interpreter (python, perl, ruby, node) as NOPASSWD sudo = root shell

# ── Monitor sudo usage ────────────────────────────────────────────────────────
tail -f /var/log/sudo.log                           # live sudo activity
grep "sudo.*COMMAND" /var/log/auth.log              # sudo commands from auth.log
ausearch -k privileged --start today               # auditd: today's sudo events
```

---

## PAM (Pluggable Authentication Modules)

PAM controls how authentication works on Linux — it's the layer between login/sudo/sshd and the actual credential check.

```bash
# ── PAM configuration files ───────────────────────────────────────────────────
# /etc/pam.d/common-auth     → used by most services
# /etc/pam.d/sshd            → SSH authentication
# /etc/pam.d/sudo            → sudo authentication
# /etc/pam.d/login           → console login

# Each line:  module_type  control_flag  module  [options]
# Types:      auth, account, password, session
# Flags:      required, requisite, sufficient, optional

# ── Enforce password quality with pam_pwquality ────────────────────────────────
apt install libpam-pwquality

# /etc/pam.d/common-password — add BEFORE the default pam_unix line:
password requisite pam_pwquality.so retry=3

# /etc/security/pwquality.conf:
minlen = 14           # minimum length
minclass = 3          # must include 3 of: uppercase, lowercase, digits, special
maxrepeat = 3         # no more than 3 identical consecutive characters
maxsequence = 4       # no sequences longer than 4 (abcd, 1234)
gecoscheck = 1        # reject passwords that contain username
dictcheck = 1         # reject dictionary words
enforce_for_root = 1  # enforce even for root

# ── Enforce login limits with pam_limits ──────────────────────────────────────
# /etc/security/limits.conf
# Control: max processes, open files, memory locking

# Prevent fork bombs (user process limit):
@developers soft nproc 5000
@developers hard nproc 10000
# Application user: set appropriate limits
myapp soft nofile 65535
myapp hard nofile 65535
myapp soft nproc  4096
# Root: protect kernel
root soft nproc unlimited

# ── Two-factor authentication for all SSH users ────────────────────────────────
apt install libpam-google-authenticator

# /etc/pam.d/sshd — at TOP, before other auth lines:
auth required pam_google_authenticator.so nullok echo_verification_code

# /etc/ssh/sshd_config:
AuthenticationMethods publickey,keyboard-interactive
ChallengeResponseAuthentication yes
UsePAM yes

# ── Account lockout after failed attempts ────────────────────────────────────
# /etc/pam.d/common-auth — add BEFORE pam_unix:
auth required pam_faillock.so preauth silent deny=5 unlock_time=900
auth [success=1 default=bad] pam_unix.so
auth [default=die] pam_faillock.so authfail deny=5 unlock_time=900
auth sufficient pam_faillock.so authsucc

# View locked accounts:
faillock --user alice                   # show alice's failed attempts
faillock --user alice --reset          # reset/unlock alice
```

---

## OIDC & Service Account Tokens

For services that need to authenticate to APIs (cloud providers, Vault, GitHub Actions), use OIDC identity tokens — not static credentials.

```bash
# ── AWS IAM Roles for EC2 (no long-term credentials on instances) ──────────────
# Attach an IAM role to the EC2 instance at launch time.
# The SDK automatically fetches rotating credentials from the metadata service.

# Verify the instance has a role:
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
# Response: my-ec2-role

curl http://169.254.169.254/latest/meta-data/iam/security-credentials/my-ec2-role
# Returns temporary credentials (AccessKeyId, SecretAccessKey, Token, Expiration)
# AWS SDK fetches these automatically — no credentials in code or env vars

# ── AWS IAM Roles for Kubernetes (IRSA) ──────────────────────────────────────
# Create IAM role with trust policy allowing EKS service account:
aws iam create-role \
  --role-name my-app-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:my-namespace:my-app"
        }
      }
    }]
  }'

# Kubernetes ServiceAccount annotation:
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/my-app-role

# ── GitHub Actions OIDC (no secrets stored in repo) ──────────────────────────
# .github/workflows/deploy.yml
jobs:
  deploy:
    permissions:
      id-token: write      # allow requesting OIDC token
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions-deploy
          aws-region: us-east-1
          # No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY needed!
          # GitHub gets a JWT from GitHub's OIDC endpoint
          # AWS exchanges JWT for temporary STS credentials
```

---

## Access Review & Audit

```bash
# ── List all users with login shells ─────────────────────────────────────────
awk -F: '$7 !~ /nologin|false/ {print $1, $3, $7}' /etc/passwd
# Should be: only real users and root. Service accounts should have /nologin.

# ── List all sudo-capable users ───────────────────────────────────────────────
# Users in sudo group:
getent group sudo

# Users with direct sudo rules (across /etc/sudoers and /etc/sudoers.d/):
grep -r "^[^#]" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | \
  grep -v "^Defaults\|^User_Alias\|^Cmnd_Alias\|^Host_Alias" | \
  awk '{print $1}' | sort -u

# ── Audit SSH authorized_keys ─────────────────────────────────────────────────
# Find ALL authorized_keys files on the system:
find / -name "authorized_keys" 2>/dev/null

# Count keys per user:
for user in $(awk -F: '$7 !~ /nologin|false/ {print $1}' /etc/passwd); do
  home=$(eval echo ~$user)
  keyfile="$home/.ssh/authorized_keys"
  if [ -f "$keyfile" ]; then
    count=$(grep -c "^ssh-" "$keyfile" 2>/dev/null || echo 0)
    echo "$user: $count key(s) in $keyfile"
    cat "$keyfile" 2>/dev/null | grep "^ssh-" | awk '{print "  →", $NF}'
  fi
done

# ── Last login report ─────────────────────────────────────────────────────────
lastlog                              # last login for every account
lastlog -b 90                        # accounts not logged in for 90+ days (stale!)
last | head -30                      # recent successful logins
lastb | head -20                     # recent FAILED logins

# ── Accounts with UID 0 (root equivalents) ───────────────────────────────────
awk -F: '$3 == 0 {print "UID 0: " $1}' /etc/passwd
# Should only ever list: root

# ── Lock stale accounts ───────────────────────────────────────────────────────
usermod -L alice                     # lock account (prepends ! to password hash)
usermod -e 1 alice                   # set expiry to past (1970-01-01) = expired

# Bulk-lock accounts not logged in for 90 days:
lastlog -b 90 | awk 'NR>1 && $1 != "root" {print $1}' | \
  while read user; do
    echo "Locking stale account: $user"
    usermod -L "$user"
  done
```