# 🚨 Incident Response Playbooks

> An incident is any event that threatens the confidentiality, integrity, or availability of your systems. The difference between a minor event and a major breach often comes down to how fast you detect it and how effectively you contain it. Incident response is a practiced discipline — not something you improvise at 3 AM while under attack.

---

## IR Phases (NIST Framework)

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ 1. PREPARE   │   │ 2. DETECT &  │   │ 3. CONTAIN,  │   │ 4. POST-     │
│              │ → │ ANALYSE      │ → │ ERADICATE &  │ → │ INCIDENT     │
│ runbooks,    │   │              │   │ RECOVER      │   │ ACTIVITY     │
│ access,      │   │ alerts,      │   │              │   │              │
│ backups,     │   │ logs, triage │   │ isolate,     │   │ RCA,         │
│ contacts     │   │              │   │ fix, restore │   │ lessons,     │
└──────────────┘   └──────────────┘   └──────────────┘   │ update docs  │
                                                         └──────────────┘
```

---

## Preparation Checklist

Before an incident happens, have these in place:

```
Communication
  □ Incident Slack channel / war room (e.g. #incident-live)
  □ On-call rotation + escalation path documented
  □ Security team contact: security@example.com
  □ Legal / DPO contact for potential data breaches
  □ Cloud provider support numbers/portal access

Access
  □ All team members have MFA-protected access to:
    - Cloud console (AWS/GCP/Azure)
    - Kubernetes cluster (kubectl)
    - Log management (CloudWatch, Datadog, Grafana)
    - Secrets vault (Vault, AWS Secrets Manager)
  □ Break-glass procedure: emergency root/admin access documented
  □ Off-band communication method (if primary systems compromised)

Detection
  □ Centralised logging (ELK, Loki, CloudWatch Logs)
  □ SIEM or log alerting (failed logins, privilege escalation, outbound to unknown IPs)
  □ Uptime/health monitoring with PagerDuty / OpsGenie alerts
  □ CloudTrail / audit logs enabled and shipped to immutable storage

Response capability
  □ Incident runbooks for top 5 threat scenarios (this file)
  □ Network isolation capability: can isolate a host in < 5 min?
  □ Backup verification: tested restore within last 30 days?
  □ Forensics capability: can capture memory/disk image?
```

---

## Playbook 1: Compromised Server

```
SYMPTOMS: Unexpected process running, unusual outbound connections,
          privilege escalation in logs, cryptocurrency miner activity,
          unknown cron jobs, modified system binaries.

SEVERITY ASSESSMENT:
  P1 (immediate): root compromise, active exfiltration, ransomware
  P2 (hours):     user account compromise, persistence mechanism found
  P3 (days):      suspicious activity, unclear scope
```

### Immediate Steps (First 15 Minutes)

```bash
# ─ STEP 1: DO NOT reboot or shut down yet ───────────────────────────────────
# Evidence lives in RAM (processes, connections, bash history in memory).
# Rebooting destroys forensic evidence.

# ─ STEP 2: Preserve evidence BEFORE touching anything ────────────────────────
# Create a timestamped log of all your actions
script /tmp/ir-$(hostname)-$(date +%Y%m%d%H%M%S).log

# Capture volatile state NOW (this data is lost on reboot):
date > /tmp/ir-evidence.txt
uptime >> /tmp/ir-evidence.txt

# Running processes:
ps auxf >> /tmp/ir-evidence.txt        # all processes with tree
ps auxfe >> /tmp/ir-evidence.txt       # with environment variables

# Network connections:
ss -tlnp >> /tmp/ir-evidence.txt       # listening ports
ss -tnp state established >> /tmp/ir-evidence.txt  # active connections
netstat -tnp >> /tmp/ir-evidence.txt   # same (legacy)

# Open files and network sockets:
lsof -i >> /tmp/ir-evidence.txt        # all network file handles
lsof -n -P +L1 >> /tmp/ir-evidence.txt # deleted files still open (malware trick)

# Active users:
who >> /tmp/ir-evidence.txt
w >> /tmp/ir-evidence.txt
last | head -30 >> /tmp/ir-evidence.txt
lastb | head -30 >> /tmp/ir-evidence.txt  # failed logins

# Cron jobs (common persistence mechanism):
for user in $(cut -d: -f1 /etc/passwd); do
  crontab -l -u "$user" 2>/dev/null | sed "s/^/[$user] /" >> /tmp/ir-evidence.txt
done
ls -la /etc/cron* /var/spool/cron* 2>/dev/null >> /tmp/ir-evidence.txt

# Systemd units (check for malicious services):
systemctl list-units --type=service >> /tmp/ir-evidence.txt
systemctl list-unit-files --state=enabled >> /tmp/ir-evidence.txt

# ─ STEP 3: Identify the suspicious activity ───────────────────────────────────
# Look for unexpected outbound connections:
ss -tnp state established | grep -v "ESTABLISHED.*127.0.0.1\|ESTABLISHED.*10\."

# Find processes with unusual network activity:
lsof -i -n | grep ESTABLISHED | awk '{print $1, $2, $9}' | sort -u

# Check for crypto miners (high CPU, suspicious process names):
ps aux | sort -k3 -rn | head -10                   # top CPU consumers
find /tmp /dev/shm /var/tmp -type f -executable 2>/dev/null  # executables in temp dirs

# Check for rootkit indicators:
# Discrepancy between ps/ss output and /proc:
ls /proc | grep -E '^[0-9]+$' | wc -l             # count from /proc
ps aux | wc -l                                      # count from ps
# If different: ps may be hijacked

# Check for LD_PRELOAD rootkit:
cat /etc/ld.so.preload                              # should be empty
env | grep LD_PRELOAD                               # should be empty

# ─ STEP 4: Isolate the host ───────────────────────────────────────────────────
# Option A: Block all traffic except your current SSH (be careful not to lock yourself out):
iptables -I INPUT  1 -s YOUR_IP -j ACCEPT          # allow your IP first!
iptables -I OUTPUT 1 -d YOUR_IP -j ACCEPT
iptables -P INPUT  DROP                             # drop everything else in
iptables -P OUTPUT DROP                             # drop everything out
iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT  # keep existing SSH

# Option B: AWS — move to an isolation security group:
aws ec2 modify-instance-attribute \
  --instance-id i-1234567890 \
  --groups sg-isolation-no-traffic

# Option C: Full isolation (if you have another way to access):
# Cloud console → stop the instance (preserves disk for forensics)
# Or: unplug from switch (physical access)

# ─ STEP 5: Notify ─────────────────────────────────────────────────────────────
# Post to #incident-live immediately with:
# - Time detected
# - Host(s) affected
# - What was observed
# - Initial isolation steps taken
# - Who is leading the response
```

### Eradication & Recovery

```bash
# ─ STEP 6: Find the initial access vector ────────────────────────────────────
# Check logs around the estimated compromise time:
journalctl --since "2025-01-01 14:00:00" --until "2025-01-01 15:00:00" -u sshd
grep "Accepted\|Failed" /var/log/auth.log | grep "2025-01-01 14:"
ausearch --start "01/01/2025 14:00:00" --end "01/01/2025 15:00:00"

# Check for webshells (if web-accessible host):
find /var/www /opt /srv -name "*.php" -newer /var/www/html/index.php 2>/dev/null
find /var/www -type f -name "*.php" | xargs grep -l "eval\|base64_decode\|exec\|system" 2>/dev/null

# Check recently modified files (possible malware or config changes):
find / -xdev -newer /tmp/ir-evidence.txt -type f 2>/dev/null | grep -v "/proc\|/sys\|/run"
find /bin /sbin /usr/bin /usr/sbin -newer /var/lib/dpkg/info/base-files.list 2>/dev/null

# ─ STEP 7: Preserve forensic image (before wiping) ───────────────────────────
# Stop the instance (AWS/GCP) or snapshot the disk:
aws ec2 stop-instances --instance-ids i-1234567890
aws ec2 create-snapshot --volume-id vol-1234567890 \
  --description "IR-2025-01-01-forensics"

# Or on a running system, capture disk image:
dd if=/dev/sda of=/forensics/disk-image.img bs=4M status=progress

# ─ STEP 8: Rebuild from known-good ────────────────────────────────────────────
# For a confirmed compromise: NEVER trust a compromised system.
# Rebuild from:
# 1. Latest known-good AMI / golden image
# 2. Infrastructure as Code (Terraform, Ansible)
# 3. Container re-deploy from a known-good image

# Do NOT try to "clean" a compromised host — attackers leave multiple backdoors.

# ─ STEP 9: Reset all credentials ─────────────────────────────────────────────
# ALL credentials that could have been on the compromised host:
# □ API keys / cloud credentials
# □ Database passwords
# □ Service account tokens
# □ TLS private keys
# □ SSH private keys
# □ All user passwords on the system
# □ Secrets in environment variables / config files

# ─ STEP 10: Verify the fix ────────────────────────────────────────────────────
# After rebuild, scan the new instance:
trivy rootfs /                                       # check for known CVEs
nmap -sV your-new-instance                          # verify only expected ports open
# Re-run through your standard hardening checks
```

---

## Playbook 2: Credential Compromise

```
SYMPTOMS: Login from unexpected IP/country, impossible travel
          (login from US, then EU 5 min later), failed MFA attempts,
          new API keys created, permission escalation, unusual API calls.
```

```bash
# ─ STEP 1: Assess scope ───────────────────────────────────────────────────────
# AWS: review CloudTrail for actions by the compromised identity:
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=alice \
  --start-time "2025-01-01T00:00:00Z" \
  --output json | jq '.Events[] | {time: .EventTime, event: .EventName, ip: .SourceIPAddress}'

# Check what resources the identity has access to:
aws iam list-attached-user-policies --user-name alice
aws iam list-user-policies --user-name alice
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789:user/alice \
  --action-names "*"

# Linux: check what the user did:
ausearch -ua alice --start today -i     # audit log for alice
grep "alice" /var/log/auth.log          # auth events
last alice                              # login history

# ─ STEP 2: Immediately revoke access ─────────────────────────────────────────
# Disable the compromised account (not delete — preserve for forensics):

# Linux:
usermod -L alice                        # lock account
pkill -u alice                          # kill active sessions

# AWS: disable access keys and revoke sessions:
aws iam update-access-key \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --status Inactive \
  --user-name alice
aws iam delete-login-profile --user-name alice  # disable console login
# Invalidate active sessions (requires SCP or IAM deny policy):
aws iam put-user-policy --user-name alice \
  --policy-name DenyAll \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*"}]}'

# GitHub:
# Settings → Security → Active sessions → Revoke all
# Settings → Developer settings → Personal access tokens → Revoke

# ─ STEP 3: Determine what was accessed ───────────────────────────────────────
# AWS S3 access logs, CloudTrail data events:
aws s3api get-bucket-logging --bucket my-sensitive-bucket
# Check S3 access logs in the log bucket

# Git: check for unexpected commits or pushes:
git log --all --author="alice" --since="1 week ago"
git log --all --oneline | head -50

# ─ STEP 4: Assess data exposure ───────────────────────────────────────────────
# If secrets or PII may have been accessed:
# - Is there a legal obligation to notify affected parties?
# - GDPR: 72-hour notification window for personal data breaches
# - Contact Legal/DPO immediately

# ─ STEP 5: Re-issue credentials with MFA enforced ────────────────────────────
# Never re-enable the old credentials. Issue new ones with:
# □ MFA required (no exceptions)
# □ Least-privilege scope (review what they actually need)
# □ Short-lived tokens where possible (AWS STS, SSH certs)
```

---

## Playbook 3: Ransomware / Data Encryption

```
SYMPTOMS: Files renamed with unknown extension (.locked, .encrypted),
          ransom note files (README.txt, DECRYPT.html),
          high disk I/O with no corresponding process,
          backup systems or shadow copies being deleted.
```

```bash
# ─ IMMEDIATE: ISOLATE EVERYTHING ─────────────────────────────────────────────
# Speed matters: ransomware spreads laterally. Isolate fast.

# Isolate all hosts in the affected segment:
# Cloud: move ALL instances to isolation security group
# Physical: pull network cables or shut down switches

# DO NOT pay the ransom before:
# 1. Checking if free decryptors exist: https://www.nomoreransom.org
# 2. Consulting with law enforcement
# 3. Verifying attacker actually has decryption keys

# ─ ASSESS IMPACT ──────────────────────────────────────────────────────────────
# What is encrypted:
find / -name "*.locked" -o -name "*.encrypted" -o -name "*.crypto" 2>/dev/null | head -50
find / -name "README*.txt" -o -name "DECRYPT*" -o -name "HOW_TO*" 2>/dev/null

# Are backups intact?
# Check your backup system IMMEDIATELY — many ransomware operators delete backups first

# ─ BEGIN RECOVERY FROM BACKUP ─────────────────────────────────────────────────
# Your RTO (Recovery Time Objective) and RPO (Recovery Point Objective)
# determine which backup to restore from.

# Verify backup integrity before restoring:
aws s3 ls s3://backups/daily/ | tail -5   # list recent backups
# Test restore to isolated environment first

# Restore order of priority:
# 1. Authentication systems (LDAP/AD, SSO)
# 2. Core infrastructure (DNS, monitoring)
# 3. Data stores (databases, object storage)
# 4. Application servers
# 5. End-user systems
```

---

## Post-Incident Report Template

```markdown
# Incident Post-Mortem Report

**Incident ID**: INC-2025-001
**Date**: 2025-01-01
**Severity**: P1 — Critical
**Author**: [Lead Responder]
**Status**: Closed

---

## Executive Summary
[2–3 sentences: what happened, what was affected, what was the outcome]

## Timeline
| Time (UTC) | Event |
|------------|-------|
| 14:23 | First indicator: CloudWatch alert — unusual API calls |
| 14:31 | On-call engineer acknowledged alert |
| 14:45 | Scope confirmed: one EC2 instance compromised |
| 15:00 | Instance isolated |
| 17:30 | Forensic snapshot taken |
| 18:00 | Rebuild complete from golden AMI |
| 18:30 | All credentials rotated |
| 19:00 | Incident declared resolved |

## Root Cause
[What was the actual cause — be specific. "Human error" is not a root cause.]

## Impact
- **Systems affected**: prod-api-01 (one EC2 instance)
- **Data exposure**: No evidence of data exfiltration
- **Downtime**: 4h 7m for affected instance (non-critical — traffic failed over)
- **Users impacted**: None (load balancer redirected traffic)

## What Went Well
- Alert fired within 8 minutes of first malicious API call
- Isolation completed in < 15 minutes
- Backups were intact and tested

## What Could Have Been Better
- MFA was not enforced for the compromised IAM user
- Incident runbook didn't exist for this scenario (this document)
- CloudTrail was enabled but not alerted on (only archived)

## Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| Enforce MFA for all IAM users via SCP | Platform | 2025-01-08 | Open |
| Add CloudTrail alerts for privilege escalation | Security | 2025-01-05 | Open |
| Write runbook for credential compromise | Security | 2025-01-10 | Open |
| Rotate all long-lived API keys | All teams | 2025-01-15 | Open |
| Schedule quarterly IR drills | Security | 2025-02-01 | Open |

## Lessons Learned
[Systemic insights — not finger-pointing at individuals]
```