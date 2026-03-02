# 🔒 Security

<p align="center">
  <img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/OpenSSL-721412?style=for-the-badge&logo=openssl&logoColor=white"/>
  <img src="https://img.shields.io/badge/HashiCorp_Vault-FFEC6E?style=for-the-badge&logo=vault&logoColor=black"/>
  <img src="https://img.shields.io/badge/Fail2ban-E03B00?style=for-the-badge&logoColor=white"/>
  <img src="https://img.shields.io/badge/Let's_Encrypt-003A70?style=for-the-badge&logo=letsencrypt&logoColor=white"/>
</p>

> Security is not a product you buy or a step at the end of the pipeline. It is an engineering discipline applied continuously — in how you configure servers, how you issue certificates, how you manage identities, how you respond to incidents. This topic covers infrastructure and system security: hardening the OS, locking down the network, managing identities and access, operating TLS/PKI, triaging CVEs, and responding to incidents.

> **Relationship to DevSecOps**: The [DevSecOps](../devsecops/) topic covers pipeline security — SAST, dependency scanning, container image scanning, and policy-as-code. This topic covers the infrastructure layer underneath: the servers, networks, identities, and certificates that everything runs on.

---

## 🗺️ Security Domains

```
┌────────────────────────────────────────────────────────────────────┐
│                        SECURITY LAYERS                             │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Incident Response  ←  detect, contain, recover, learn       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│            ▲ feeds into                                            │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Vulnerability Management  ←  CVE triage, patching, tracking │  │
│  └──────────────────────────────────────────────────────────────┘  │
│            ▲ protects                                              │
│  ┌───────────────────────┐   ┌──────────────────────────────────┐  │
│  │  TLS / PKI            │   │  Identity & Access Management    │  │
│  │  certificates, CA,    │   │  users, roles, SSH keys, RBAC,   │  │
│  │  mTLS, rotation       │   │  MFA, least privilege            │  │
│  └───────────────────────┘   └──────────────────────────────────┘  │
│            ▲ secures traffic          ▲ controls who/what          │
│  ┌───────────────────────┐   ┌──────────────────────────────────┐  │
│  │  Network Security     │   │  System Hardening                │  │
│  │  firewall, segmentation│  │  kernel, OS, SSH, audit logs     │  │
│  │  IDS/IPS, VPN         │   │  AppArmor, SELinux, capabilities │  │
│  └───────────────────────┘   └──────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Contents

| Folder | Files | What you'll learn |
|--------|-------|-------------------|
| [hardening/](./hardening/) | `linux.md` · `ssh.md` · `kernel.md` | CIS Benchmark, sysctl hardening, AppArmor/SELinux, audit daemon, SSH lockdown |
| [network-security/](./network-security/) | `firewall.md` · `ids-ips.md` · `network-segmentation.md` | iptables/nftables, fail2ban, Suricata, VLANs, zero-trust networking |
| [identity-access/](./identity-access/) | `iam.md` · `rbac.md` · `mfa.md` | Linux RBAC, sudo hardening, SSH certificates, OIDC, PAM, MFA with TOTP |
| [tls-pki/](./tls-pki/) | `certificates.md` · `ca-setup.md` · `mtls.md` | TLS handshake, self-signed vs CA-signed, internal CA with cfssl/step-ca, mTLS |
| [vulnerability-management/](./vulnerability-management/) | `cve-triage.md` · `patch-management.md` | CVE scoring, patch SLAs, `unattended-upgrades`, kernel live-patching |
| [incident-response/](./incident-response/) | `playbooks.md` · `forensics.md` | IR phases, containment runbooks, Linux forensics, log preservation |

---

## 🗺️ Learning Path

```
1. hardening/           ← lock down the baseline before anything else
        ↓
2. network-security/    ← control what traffic can reach the system
        ↓
3. identity-access/     ← control who and what can operate the system
        ↓
4. tls-pki/             ← encrypt everything in transit
        ↓
5. vulnerability-management/  ← find and fix weaknesses continuously
        ↓
6. incident-response/   ← prepare to detect, respond, and recover
```

---

## ⚡ Security Quick Wins (Do These Today)

```bash
# 1. Disable root SSH login
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
systemctl reload sshd

# 2. Enable automatic security updates
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# 3. Enable firewall — deny by default
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# 4. Audit SUID binaries (should be a short, known list)
find / -perm /4000 -type f 2>/dev/null | sort

# 5. Check listening services (attack surface)
ss -tlnp

# 6. Ensure no empty passwords exist
awk -F: '($2 == "") {print $1}' /etc/shadow

# 7. Check for world-writable directories
find / -xdev -type d -perm -0002 -not -perm -1000 2>/dev/null

# 8. Verify auditd is running
systemctl status auditd
```

---

## 🔗 Related Topics

- [DevSecOps](../devsecops/) — pipeline security: SAST, dependency scanning, container scanning, policy-as-code
- [Linux](../linux/) — system fundamentals underpinning all security controls
- [Server Management](../server-management/) — firewall configuration, web server hardening
- [Networking](../networking/) — SSH, TLS in context of protocols
- [Orchestration](../orchestration/) — Kubernetes RBAC, network policies, pod security