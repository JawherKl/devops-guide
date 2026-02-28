# 🔥 Firewall

> A firewall is the first line of defense on any server. It controls which network traffic is allowed in and out based on rules — port, protocol, source IP, destination IP. Without it, every port your application opens is directly reachable by anyone on the internet.

---

## The Linux Firewall Stack

```
Application (Nginx, SSH, Node.js…)
        ↓
  nftables / iptables  ← kernel-level packet filtering
        ↓
  UFW (Uncomplicated Firewall) ← friendly CLI wrapper over iptables
        ↓
Network Interface (eth0, ens3…)
        ↓
Internet
```

**Which tool to use:**

| Tool | When to use |
|------|-------------|
| `ufw` | Ubuntu/Debian servers, simple rule sets, fast setup |
| `iptables` | Full control, scripting, legacy systems, all distros |
| `nftables` | Modern replacement for iptables (RHEL 8+, Debian 10+) |
| `firewalld` | RHEL/Fedora/CentOS, zone-based, dynamic rule changes |

---

## UFW — Uncomplicated Firewall

UFW is the recommended tool for Ubuntu servers. It wraps iptables with a human-readable interface.

### Initial Setup

```bash
# Install (pre-installed on Ubuntu)
apt install ufw

# Check current status
ufw status verbose

# IMPORTANT: set default policies BEFORE enabling
# Default deny all incoming, allow all outgoing
ufw default deny incoming
ufw default allow outgoing

# Allow SSH FIRST — otherwise you'll lock yourself out
ufw allow ssh          # same as: ufw allow 22/tcp
# Or restrict SSH to your IP only:
ufw allow from 203.0.113.10 to any port 22

# Enable the firewall
ufw enable             # activates immediately, persists across reboots

# Verify
ufw status numbered    # numbered list of all rules
```

### Common Rules

```bash
# ── Allow by service name (reads /etc/services) ───────────────────────────────
ufw allow ssh            # port 22/tcp
ufw allow http           # port 80/tcp
ufw allow https          # port 443/tcp
ufw allow smtp           # port 25/tcp
ufw allow "Nginx Full"   # ports 80 + 443 (from /etc/ufw/applications.d/)

# ── Allow by port ────────────────────────────────────────────────────────────
ufw allow 8080/tcp
ufw allow 5432/tcp       # PostgreSQL
ufw allow 6379/tcp       # Redis
ufw allow 3000:3010/tcp  # port range

# ── Allow by protocol ────────────────────────────────────────────────────────
ufw allow 53/udp         # DNS
ufw allow proto tcp from any to any port 80,443   # multiple ports in one rule

# ── Allow from specific IP ────────────────────────────────────────────────────
ufw allow from 203.0.113.10                        # all ports from this IP
ufw allow from 203.0.113.10 to any port 5432       # only PostgreSQL from this IP
ufw allow from 10.0.0.0/8 to any port 6379         # Redis from private network

# ── Deny rules ───────────────────────────────────────────────────────────────
ufw deny from 198.51.100.0/24                      # block entire CIDR
ufw deny 23/tcp                                    # deny telnet

# ── Rate limiting (basic brute-force protection) ──────────────────────────────
# Limit: deny if more than 6 connection attempts in 30 seconds from same IP
ufw limit ssh
ufw limit 22/tcp

# ── Delete rules ─────────────────────────────────────────────────────────────
ufw status numbered        # see rule numbers
ufw delete 5               # delete rule #5
ufw delete allow http      # delete by rule description

# ── Reset (remove all rules, disable) ────────────────────────────────────────
ufw reset
```

### UFW Application Profiles

```bash
# List available application profiles
ufw app list

# Show what ports a profile covers
ufw app info "Nginx Full"
# Nginx Full: ports 80,443/tcp

# Common profiles
ufw allow "Nginx HTTP"         # 80 only
ufw allow "Nginx HTTPS"        # 443 only
ufw allow "Nginx Full"         # 80 + 443
ufw allow "OpenSSH"            # 22

# Create a custom application profile:
# /etc/ufw/applications.d/myapp
# [MyApp API]
# title=My Application API
# description=Custom API server
# ports=3000/tcp
```

### UFW Logging

```bash
# Enable logging (levels: off, low, medium, high, full)
ufw logging medium

# Logs are written to /var/log/ufw.log and /var/log/kern.log
tail -f /var/log/ufw.log

# Sample log line:
# [UFW BLOCK] IN=eth0 OUT= SRC=203.0.113.5 DST=10.0.0.1 PROTO=TCP DPT=22
```

---

## iptables — Direct Kernel Firewall

iptables gives full control over the Linux netfilter packet filtering framework. Rules are evaluated top-to-bottom; first match wins.

### Core Concepts

```
Tables:   filter (default) | nat | mangle | raw
Chains:   INPUT (incoming) | OUTPUT (outgoing) | FORWARD (routed traffic)
Targets:  ACCEPT | DROP | REJECT | LOG | RETURN
```

### Essential Commands

```bash
# ── View rules ───────────────────────────────────────────────────────────────
iptables -L -v -n          # list all rules with packet/byte counts
iptables -L -v -n --line-numbers   # with line numbers (for deletion)
iptables -S                         # dump rules as iptables commands

# ── Append rule to chain ─────────────────────────────────────────────────────
iptables -A INPUT -p tcp --dport 80  -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 22  -j ACCEPT

# ── Insert rule at specific position ─────────────────────────────────────────
iptables -I INPUT 1 -p tcp --dport 80 -j ACCEPT   # insert at position 1

# ── Delete rule ───────────────────────────────────────────────────────────────
iptables -D INPUT -p tcp --dport 8080 -j ACCEPT    # delete by spec
iptables -D INPUT 5                                 # delete line 5

# ── Flush all rules ───────────────────────────────────────────────────────────
iptables -F            # flush filter table (all rules gone!)
iptables -F INPUT      # flush only INPUT chain
```

### Production Ruleset Script

```bash
#!/usr/bin/env bash
# /etc/iptables/setup-rules.sh
# Apply on boot: ExecStart=/etc/iptables/setup-rules.sh
# Or via iptables-persistent: apt install iptables-persistent

set -euo pipefail

# ── Flush everything and start fresh ─────────────────────────────────────────
iptables -F
iptables -X
iptables -Z

# ── Default policies ──────────────────────────────────────────────────────────
iptables -P INPUT   DROP    # drop all incoming by default
iptables -P FORWARD DROP    # drop all forwarded traffic
iptables -P OUTPUT  ACCEPT  # allow all outgoing by default

# ── Loopback: always allow ─────────────────────────────────────────────────
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ── Stateful connection tracking ──────────────────────────────────────────────
# Allow traffic that is part of an already ESTABLISHED connection.
# This means: if your server initiates a connection (e.g. apt update),
# allow the response back in without an explicit rule.
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ── ICMP (ping) — allow but rate-limit to prevent ping floods ─────────────────
iptables -A INPUT -p icmp --icmp-type echo-request \
  -m limit --limit 10/second --limit-burst 30 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP  # drop above limit

# ── SSH: allow + rate-limit brute-force attempts ──────────────────────────────
# Allow up to 4 new SSH connections per minute from a single IP
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW \
  -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW \
  -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# ── Web traffic ───────────────────────────────────────────────────────────────
iptables -A INPUT -p tcp --dport 80  -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# ── Internal services: only from trusted network ──────────────────────────────
iptables -A INPUT -p tcp --dport 5432 -s 10.0.0.0/8 -j ACCEPT  # PostgreSQL
iptables -A INPUT -p tcp --dport 6379 -s 10.0.0.0/8 -j ACCEPT  # Redis
iptables -A INPUT -p tcp --dport 9090 -s 10.0.0.0/8 -j ACCEPT  # Prometheus

# ── Block known bad actor subnets ─────────────────────────────────────────────
# (update this list from threat intelligence feeds)
iptables -A INPUT -s 198.51.100.0/24 -j DROP
iptables -A INPUT -s 203.0.113.0/24  -j DROP

# ── Log dropped packets (rate-limited to prevent log flooding) ────────────────
iptables -A INPUT -m limit --limit 5/min -j LOG \
  --log-prefix "iptables-DROP: " --log-level 4
iptables -A INPUT -j DROP   # final catch-all drop

# ── Save rules (requires iptables-persistent) ─────────────────────────────────
iptables-save > /etc/iptables/rules.v4
echo "Firewall rules applied."
```

```bash
# Make rules survive reboots
apt install iptables-persistent
iptables-save > /etc/iptables/rules.v4    # IPv4
ip6tables-save > /etc/iptables/rules.v6   # IPv6
```

---

## nftables — Modern iptables Replacement

nftables is the successor to iptables, built into Linux since kernel 3.13. It uses a cleaner syntax and is the default on Debian 10+, RHEL 8+, Ubuntu 20.04+.

```bash
# Check if nftables is active
systemctl status nftables

# View current ruleset
nft list ruleset

# Interactive mode
nft -i
```

### Production nftables Ruleset

```
# /etc/nftables.conf
# Load: systemctl enable --now nftables  OR  nft -f /etc/nftables.conf

#!/usr/sbin/nft -f
flush ruleset

table inet filter {

    # ── Sets: reusable lists of IPs/ports ────────────────────────────────────
    set bad_ips {
        type ipv4_addr
        flags interval
        elements = {
            198.51.100.0/24,
            203.0.113.0/24
        }
    }

    set trusted_mgmt {
        type ipv4_addr
        elements = {
            10.0.0.0/8,
            172.16.0.0/12
        }
    }

    # ── Input chain ───────────────────────────────────────────────────────────
    chain input {
        type filter hook input priority 0
        policy drop           # default: drop all incoming

        # Loopback
        iif lo accept

        # Established/related connections
        ct state established,related accept

        # ICMP — allow ping, limit flood
        ip  protocol icmp  icmp  type echo-request  limit rate 10/second accept
        ip6 nexthdr  icmp6 icmpv6 type echo-request limit rate 10/second accept

        # Drop bad IPs early
        ip saddr @bad_ips drop

        # SSH from anywhere, rate-limited
        tcp dport 22 ct state new \
            meter ssh_ratelimit { ip saddr timeout 60s limit rate 4/minute } \
            accept

        # Web traffic
        tcp dport { 80, 443 } accept

        # Internal services: only from trusted management network
        ip saddr @trusted_mgmt tcp dport { 5432, 6379, 9090, 9100 } accept

        # Log and drop everything else
        limit rate 5/minute log prefix "nft-DROP: " level warn
        drop
    }

    # ── Output chain ──────────────────────────────────────────────────────────
    chain output {
        type filter hook output priority 0
        policy accept         # allow all outgoing
    }

    # ── Forward chain ─────────────────────────────────────────────────────────
    chain forward {
        type filter hook forward priority 0
        policy drop           # this is not a router
    }
}
```

```bash
# Apply and validate
nft -c -f /etc/nftables.conf    # check syntax (dry-run)
nft -f /etc/nftables.conf       # apply
systemctl enable nftables        # persist across reboots

# Live management
nft add element inet filter bad_ips { 192.0.2.1 }     # add IP to block list
nft delete element inet filter bad_ips { 192.0.2.1 }  # remove IP
nft list table inet filter                             # view current state
```

---

## firewalld (RHEL / CentOS / Fedora)

firewalld uses zones to group interfaces and assign trust levels. Good for systems where interfaces change dynamically (VPNs, cloud NICs).

```bash
# Enable and start
systemctl enable --now firewalld

# Check status
firewall-cmd --state
firewall-cmd --list-all              # current zone's rules

# ── Zones ────────────────────────────────────────────────────────────────────
firewall-cmd --get-zones             # list available zones
firewall-cmd --get-active-zones      # see which zones are active
firewall-cmd --get-default-zone      # current default zone

# ── Add rules to default zone ────────────────────────────────────────────────
firewall-cmd --add-service=ssh       # temporary (lost on reload)
firewall-cmd --add-service=http  --permanent
firewall-cmd --add-service=https --permanent
firewall-cmd --add-port=8080/tcp --permanent

# Rich rules (equivalent to iptables source-IP restrictions)
firewall-cmd --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" port port="5432" protocol="tcp" accept' --permanent

# Rate-limit SSH (requires firewalld ≥ 0.9.3)
firewall-cmd --add-rich-rule='rule service name="ssh" limit value="4/m" accept' --permanent

# Block an IP
firewall-cmd --add-rich-rule='rule family="ipv4" source address="198.51.100.5" drop' --permanent

# Apply permanent rules
firewall-cmd --reload
```

---

## 🔒 Server Hardening Checklist

```bash
# 1. Disable root login over SSH
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# 2. Disable password authentication (use SSH keys only)
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
systemctl reload sshd

# 3. Change SSH to a non-standard port (reduces automated scan noise)
sed -i 's/^#Port 22/Port 2222/' /etc/ssh/sshd_config
ufw allow 2222/tcp
ufw delete allow ssh
systemctl reload sshd

# 4. Enable automatic security updates
apt install unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# 5. Disable unused services
systemctl disable --now bluetooth avahi-daemon cups 2>/dev/null || true

# 6. Fail2Ban — auto-ban IPs with too many failed logins
apt install fail2ban
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600       # ban for 1 hour
findtime = 600        # window to count failures
maxretry = 5          # ban after 5 failures

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = %(sshd_log)s
maxretry = 3
EOF
systemctl enable --now fail2ban

# 7. Verify no unexpected open ports
ss -tlnp      # list listening TCP sockets
ss -ulnp      # list listening UDP sockets
netstat -tlnp  # alternative (requires net-tools)

# 8. Check for SUID binaries (privilege escalation risk)
find / -perm /4000 -type f 2>/dev/null | sort

# 9. Audit cron jobs
crontab -l                       # current user's cron
cat /etc/cron.d/*                # system-wide crons
ls /etc/cron.{daily,weekly,monthly}/
```

---

## 🔍 Debugging Firewall Issues

```bash
# ── Connection refused vs connection timeout ──────────────────────────────────
# "Connection refused" = port is open but nothing is listening (app issue)
# "Connection timed out" = firewall is dropping packets (firewall issue)

# Test from outside the server
nc -zv example.com 443        # test if TCP port 443 is reachable
telnet example.com 80          # simple TCP check

# From inside the server — is the app actually listening?
ss -tlnp | grep :3000
netstat -tlnp | grep :3000

# Watch packets hitting iptables rules (add LOG target before DROP)
iptables -I INPUT 1 -j LOG --log-prefix "DEBUG-IN: "
tail -f /var/log/kern.log | grep DEBUG-IN
iptables -D INPUT 1    # remove debug rule when done

# Trace a packet through nftables
nft monitor trace      # live trace all packets (verbose!)

# Check UFW logs
tail -f /var/log/ufw.log | grep -E "BLOCK|ALLOW"

# Verify firewall rules aren't blocking loopback
curl -v http://127.0.0.1:3000/health   # test app locally, bypasses external firewall
```