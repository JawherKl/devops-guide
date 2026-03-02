# 🔥 Firewall & Network Hardening

> A firewall is the first line of defence: everything that doesn't need to be reachable from the network shouldn't be. The default stance is **deny everything, allow only what is explicitly required**. This file covers UFW for simple cases, nftables for production, network segmentation principles, and monitoring for suspicious traffic.

---

## UFW — Simple Firewall (Ubuntu/Debian)

```bash
# ── Default policy: deny everything inbound, allow outbound ──────────────────
ufw default deny incoming
ufw default allow outgoing
ufw default deny forward       # disable forwarding (unless this is a router)

# ── Allow required services ───────────────────────────────────────────────────
ufw allow 22/tcp                # SSH
ufw allow 80/tcp                # HTTP
ufw allow 443/tcp               # HTTPS
ufw allow 8080/tcp              # Application port

# Rate-limit SSH to prevent brute-force (max 6 connections/30s from same IP):
ufw limit 22/tcp

# Allow from specific IP or network only:
ufw allow from 10.0.0.0/8 to any port 5432    # PostgreSQL: private network only
ufw allow from 192.168.1.0/24 to any port 6379 # Redis: management VLAN only
ufw allow from 10.10.0.5 to any port 22        # SSH: bastion host only

# Allow specific service + IP combination:
ufw allow proto tcp from 203.0.113.10 to any port 443

# ── Enable ────────────────────────────────────────────────────────────────────
ufw enable                      # enable (persists across reboots)
ufw status verbose              # view all rules
ufw status numbered             # view with rule numbers (needed for deletion)

# ── Manage rules ──────────────────────────────────────────────────────────────
ufw delete 3                    # delete rule number 3
ufw delete allow 80/tcp         # delete by rule specification
ufw reload                      # reload without disabling
ufw reset                       # reset to defaults (removes all rules)
ufw disable                     # disable (firewall down — be careful!)

# ── Logging ───────────────────────────────────────────────────────────────────
ufw logging on                  # enable logging
ufw logging medium              # low/medium/high/full
# Logs go to /var/log/ufw.log
tail -f /var/log/ufw.log | grep BLOCK  # watch blocked traffic
```

---

## nftables — Production Firewall

nftables is the modern Linux packet filtering framework, replacing iptables. It has a cleaner syntax and better performance.

```bash
# ── Install and enable ────────────────────────────────────────────────────────
apt install nftables
systemctl enable --now nftables

# ── Complete production ruleset ───────────────────────────────────────────────
# /etc/nftables.conf

#!/usr/sbin/nft -f

# Flush all existing rules
flush ruleset

# Define variables
define MGMT_NET = { 10.0.0.0/8, 192.168.0.0/16 }
define BASTION_IP = 10.0.0.5
define TRUSTED_DNS = { 8.8.8.8, 8.8.4.4, 1.1.1.1 }

table inet filter {

  # ── Sets for dynamic IP blocking ─────────────────────────────────────────
  set blocklist {
    type ipv4_addr
    flags timeout
    # Entries time out automatically
  }

  set brute_force_candidates {
    type ipv4_addr
    flags dynamic, timeout
    timeout 60s
  }

  # ── Input chain: traffic TO this machine ─────────────────────────────────
  chain input {
    type filter hook input priority filter; policy drop;

    # Established/related: allow responses to our outbound connections
    ct state established,related accept

    # Reject invalid packets (not just drop)
    ct state invalid drop

    # Loopback: always allow
    iif lo accept

    # ICMP: allow (needed for MTU discovery, ping, etc.)
    ip protocol icmp icmp type {
      echo-reply,
      destination-unreachable,
      time-exceeded,
      parameter-problem,
      echo-request
    } accept

    ip6 nexthdr icmpv6 icmpv6 type {
      echo-request,
      echo-reply,
      nd-neighbor-solicit,
      nd-neighbor-advert,
      nd-router-advert
    } accept

    # Dynamic blocklist (manual bans + auto-populated by brute force rules)
    ip saddr @blocklist drop

    # SSH: from bastion only + rate limiting
    tcp dport 22 ip saddr != $BASTION_IP drop
    tcp dport 22 ct state new \
      add @brute_force_candidates { ip saddr limit rate 3/minute burst 5 packets } \
      accept
    tcp dport 22 ip saddr @brute_force_candidates drop

    # HTTP/HTTPS: open to world
    tcp dport { 80, 443 } accept

    # Application port: private network only
    tcp dport 8080 ip saddr $MGMT_NET accept
    tcp dport 8080 drop

    # PostgreSQL: private network only
    tcp dport 5432 ip saddr $MGMT_NET accept
    tcp dport 5432 drop

    # Redis: management hosts only
    tcp dport 6379 ip saddr $MGMT_NET accept
    tcp dport 6379 drop

    # Log and drop everything else
    limit rate 5/second burst 10 packets \
      log prefix "[NFT DROP IN] " flags all
    drop
  }

  # ── Output chain: traffic FROM this machine ───────────────────────────────
  chain output {
    type filter hook output priority filter; policy accept;

    # Allow established connections out
    ct state established,related accept

    # DNS: only to trusted servers
    udp dport 53 ip daddr != $TRUSTED_DNS drop
    tcp dport 53 ip daddr != $TRUSTED_DNS drop

    # NTP: allowed to any server
    udp dport 123 accept

    # HTTP/HTTPS: needed for package updates, API calls
    tcp dport { 80, 443 } accept

    # Prevent outbound SMTP (stops this server from being used for spam)
    tcp dport 25 drop
  }

  # ── Forward chain: routed traffic ─────────────────────────────────────────
  chain forward {
    type filter hook forward priority filter; policy drop;
    # This server is not a router. Drop all forwarded packets.
  }
}

# Apply:
nft -f /etc/nftables.conf
nft list ruleset                # verify rules loaded

# Live management:
nft add element inet filter blocklist { 1.2.3.4 timeout 1h }  # block IP for 1 hour
nft list set inet filter blocklist                              # view blocklist
nft delete element inet filter blocklist { 1.2.3.4 }          # unblock IP
```

---

## iptables — Legacy (Still Common)

```bash
# ── Flush and set defaults ────────────────────────────────────────────────────
iptables -F                    # flush all rules
iptables -X                    # delete custom chains
iptables -Z                    # zero counters

# Default policy: drop everything
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT

# ── Stateful rules ────────────────────────────────────────────────────────────
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A INPUT -i lo -j ACCEPT

# ── ICMP ──────────────────────────────────────────────────────────────────────
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT
iptables -A INPUT -p icmp -j DROP   # drop excess ICMP (flood protection)

# ── SSH rate limiting ─────────────────────────────────────────────────────────
iptables -N SSH_BRUTE
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j SSH_BRUTE
iptables -A SSH_BRUTE -m recent --set --name SSH --rsource
iptables -A SSH_BRUTE -m recent --update --seconds 60 --hitcount 4 \
         --rttl --name SSH --rsource -j DROP
iptables -A SSH_BRUTE -j ACCEPT

# ── Services ──────────────────────────────────────────────────────────────────
iptables -A INPUT -p tcp --dport 80  -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 5432 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 5432 -j DROP

# ── Logging ───────────────────────────────────────────────────────────────────
iptables -A INPUT -m limit --limit 5/min \
         -j LOG --log-prefix "[IPTABLES DROP] " --log-level 4
iptables -A INPUT -j DROP

# ── Persist across reboots ────────────────────────────────────────────────────
apt install iptables-persistent
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
```

---

## Network Segmentation

Segmentation limits the blast radius of a compromise — even if an attacker gets into one zone, they can't move laterally.

```
┌─────────────────────────────────────────────────────────────────┐
│  Internet / Public Zone                                         │
│  Traffic: HTTP/HTTPS from anywhere                              │
└───────────────────────────────┬─────────────────────────────────┘
                                │ 80, 443 only
┌───────────────────────────────▼─────────────────────────────────┐
│  DMZ (Demilitarized Zone)                                       │
│  Load balancer, Nginx reverse proxy, WAF                        │
│  Network: 10.0.1.0/24                                           │
└───────────────────────────────┬─────────────────────────────────┘
                                │ 8080 only
┌───────────────────────────────▼─────────────────────────────────┐
│  Application Zone                                               │
│  API servers, background workers                                │
│  Network: 10.0.2.0/24                                           │
└───────────────────────────────┬─────────────────────────────────┘
                                │ 5432/6379 only
┌───────────────────────────────▼─────────────────────────────────┐
│  Data Zone                                                      │
│  PostgreSQL, Redis, object storage                              │
│  Network: 10.0.3.0/24                                           │
│  No direct internet access                                      │
└─────────────────────────────────────────────────────────────────┘
                                ┌──────────────────────┐
                                │  Management Zone     │
                                │  Bastion, monitoring │
                                │  Network: 10.0.0.0/24│
                                │  SSH only from VPN   │
                                └──────────────────────┘
```

```bash
# Implement segmentation with firewall rules on each host:

# Data zone host (PostgreSQL server): deny all inbound except from app zone
nft add rule inet filter input \
  tcp dport 5432 ip saddr != 10.0.2.0/24 drop

# App zone host: deny inbound except from DMZ
nft add rule inet filter input \
  tcp dport 8080 ip saddr != 10.0.1.0/24 drop

# In Kubernetes: NetworkPolicy enforces segmentation
# (see orchestration/kubernetes/network-policy.md)
```

---

## Monitoring Suspicious Traffic

```bash
# ── Live traffic analysis ─────────────────────────────────────────────────────
tcpdump -i eth0 -n 'not port 22'         # all traffic except SSH (our terminal)
tcpdump -i eth0 -n port 443              # HTTPS traffic
tcpdump -i eth0 -n 'tcp[tcpflags] & (tcp-syn|tcp-fin) != 0'  # new connections
tcpdump -i eth0 -n -c 1000 -w capture.pcap  # capture 1000 packets to file

# ── Check for unexpected outbound connections ─────────────────────────────────
ss -tnp | grep ESTABLISHED               # established connections + PIDs
netstat -tnp | grep ESTABLISHED          # same (legacy)
lsof -i -n -P | grep ESTABLISHED        # same with more detail

# Detect unexpected outbound connections to internet:
ss -tnp | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort -u
# Compare against your known external endpoints

# ── Watch for port scans in firewall logs ─────────────────────────────────────
tail -f /var/log/ufw.log | grep "DPT=22"           # SSH probe attempts
grep "NFT DROP" /var/log/syslog | \
  awk '{print $10}' | cut -d= -f2 | \
  sort | uniq -c | sort -rn | head -20             # top attacking IPs

# ── Detect ARP spoofing ───────────────────────────────────────────────────────
arp -n                                  # view ARP table
# Duplicate MAC addresses for different IPs = potential ARP spoofing
arp -n | awk '{print $3}' | sort | uniq -d

# ── Check for DNS exfiltration indicators ────────────────────────────────────
# Unusually long DNS queries or high DNS volume can indicate data exfiltration
tcpdump -i eth0 -n 'udp port 53' -A | grep -E '[a-z0-9]{30,}\.'
```