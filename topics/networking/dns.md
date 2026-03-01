# 🗂️ DNS

> DNS (Domain Name System) is the phonebook of the internet. It translates human-readable names like `api.example.com` into IP addresses like `93.184.216.34`. Every network connection starts with a DNS query. Understanding DNS means being able to diagnose outages, configure domains correctly, and understand the latency impact of resolution.

---

## How DNS Resolution Works

```
Browser asks: "What is the IP of api.example.com?"

Step 1: Check local cache (previously resolved? use cached answer)
Step 2: Check /etc/hosts (local overrides)
Step 3: Ask the configured resolver (e.g. 8.8.8.8)

     ┌─────────────────── Recursive Resolver (8.8.8.8) ──────────────────────┐
     │                                                                         │
     │  4. Ask a Root Nameserver (13 clusters: a.root-servers.net … m.)       │
     │     → "Who handles .com?" → "Ask 192.5.6.30 (a.gtld-servers.net)"      │
     │                                                                         │
     │  5. Ask the .com TLD Nameserver                                         │
     │     → "Who handles example.com?" → "Ask ns1.example.com (205.251.x.x)" │
     │                                                                         │
     │  6. Ask example.com's Authoritative Nameserver                          │
     │     → "What is api.example.com?" → "93.184.216.34 (TTL 300)"           │
     └─────────────────────────────────────────────────────────────────────────┘

Step 4: Return 93.184.216.34 to the browser (cache it for TTL seconds)
```

**Key terms:**
- **Recursive resolver**: does the work of querying multiple servers on your behalf (ISP resolver, 8.8.8.8, 1.1.1.1)
- **Authoritative nameserver**: the final authority for a domain's records (e.g. Route53, Cloudflare DNS)
- **Root servers**: 13 server clusters (`a.root-servers.net` … `m.root-servers.net`) that know who handles each TLD
- **TTL** (Time to Live): how many seconds resolvers should cache the answer

---

## DNS Record Types

| Type | Purpose | Example |
|------|---------|---------|
| **A** | IPv4 address | `api.example.com → 93.184.216.34` |
| **AAAA** | IPv6 address | `api.example.com → 2606:2800:220:1:248:1893:25c8:1946` |
| **CNAME** | Alias to another name | `www.example.com → example.com` |
| **MX** | Mail server for domain | `example.com → mail.example.com (priority 10)` |
| **TXT** | Text data | SPF, DKIM, domain verification |
| **NS** | Authoritative nameservers for a zone | `example.com → ns1.example.com` |
| **SOA** | Start of Authority (zone metadata) | Serial, refresh, retry, expire |
| **PTR** | Reverse DNS: IP → hostname | `34.216.184.93.in-addr.arpa → api.example.com` |
| **SRV** | Service location | `_http._tcp.example.com → host:port weight priority` |
| **CAA** | Allowed certificate authorities | `example.com → "letsencrypt.org"` |

```bash
# Query specific record types:
dig example.com A                  # IPv4 address
dig example.com AAAA               # IPv6 address
dig example.com MX                 # mail servers
dig example.com TXT                # text records (SPF, DKIM, etc.)
dig example.com NS                 # nameservers
dig example.com SOA                # zone metadata
dig example.com CAA                # allowed CAs
dig -x 93.184.216.34               # PTR record (reverse lookup)
dig _http._tcp.example.com SRV     # service record
```

---

## dig — The DNS Diagnostic Tool

```bash
# ── Basic lookup ───────────────────────────────────────────────────────────────
dig api.example.com
# Output sections:
# ;; QUESTION SECTION:   what we asked
# ;; ANSWER SECTION:     the answer(s)
# ;; AUTHORITY SECTION:  the authoritative NS that answered
# ;; ADDITIONAL SECTION: helpful extra records
# ;; Query time: 23 msec
# ;; SERVER: 8.8.8.8#53

dig +short api.example.com         # just the IP(s), no noise
dig +noall +answer api.example.com # only the ANSWER section

# ── Query a specific server ────────────────────────────────────────────────────
dig @8.8.8.8 api.example.com       # use Google's resolver
dig @1.1.1.1 api.example.com       # use Cloudflare's resolver
dig @ns1.example.com api.example.com  # ask the authoritative NS directly

# ── Trace full delegation chain (invaluable for debugging) ────────────────────
dig +trace api.example.com
# Shows every step:
# . → com. → example.com. → api.example.com
# Reveals: delegations, glue records, TTLs at every level

# ── Reverse DNS lookup ─────────────────────────────────────────────────────────
dig -x 93.184.216.34               # IP → hostname (PTR record)
dig -x 93.184.216.34 +short        # just the hostname

# ── Check all nameservers agree (consistency check) ───────────────────────────
for ns in $(dig +short example.com NS); do
    echo "=== $ns ==="
    dig @$ns api.example.com +short
done

# ── Check DNSSEC ──────────────────────────────────────────────────────────────
dig api.example.com +dnssec        # request DNSSEC records
dig api.example.com DNSKEY         # public key for the zone

# ── Measure DNS latency ───────────────────────────────────────────────────────
dig api.example.com | grep "Query time"
for server in 8.8.8.8 1.1.1.1 9.9.9.9; do
    echo -n "$server: "
    dig @$server api.example.com | grep "Query time"
done
```

---

## DNS Record Configuration Examples

```bash
# Example zone file / DNS provider settings for example.com

# ── Apex domain → IP (A record) ───────────────────────────────────────────────
example.com.     300  IN  A     93.184.216.34
www.example.com. 300  IN  CNAME example.com.

# ── Subdomains ────────────────────────────────────────────────────────────────
api.example.com. 300  IN  A     93.184.216.35
cdn.example.com. 3600 IN  CNAME d1234.cloudfront.net.

# ── Mail (MX) ─────────────────────────────────────────────────────────────────
# Lower priority number = preferred
example.com.  3600  IN  MX  10  mail1.example.com.
example.com.  3600  IN  MX  20  mail2.example.com.    # backup

# ── SPF (who can send email for this domain) ──────────────────────────────────
example.com.  3600  IN  TXT  "v=spf1 include:_spf.google.com include:sendgrid.net ~all"
# ~all = softfail (suspicious), -all = hardfail (reject)

# ── DKIM (email signature verification) ──────────────────────────────────────
selector._domainkey.example.com.  3600  IN  TXT  "v=DKIM1; k=rsa; p=MIGfMA0G..."

# ── DMARC (email authentication policy) ──────────────────────────────────────
_dmarc.example.com.  3600  IN  TXT  "v=DMARC1; p=quarantine; pct=100; rua=mailto:dmarc@example.com"

# ── CAA (restrict which CAs can issue certificates) ───────────────────────────
example.com.  3600  IN  CAA  0 issue "letsencrypt.org"
example.com.  3600  IN  CAA  0 issue "digicert.com"
example.com.  3600  IN  CAA  0 issuewild ";"    # disallow wildcard certs from all CAs

# ── SRV (service discovery) ───────────────────────────────────────────────────
# _service._protocol.name TTL IN SRV priority weight port target
_sip._tcp.example.com.  3600  IN  SRV  10 20 5060 sip1.example.com.
_sip._tcp.example.com.  3600  IN  SRV  10 80 5060 sip2.example.com.
```

---

## TTL Strategy

```bash
# TTL (seconds) controls how long resolvers cache your records.

# Low TTL tradeoffs:
# ✅ Faster propagation of changes (failover works in minutes)
# ❌ More queries to authoritative NS (cost + latency for users)
# Use: during planned migrations, A/B testing, failover scenarios

# High TTL tradeoffs:
# ✅ Fewer queries (better latency, lower cost)
# ❌ Changes are slow to propagate (hours to days)
# Use: stable records that never change

# Recommended TTL by record stability:
# Stable A records:       3600–86400   (1 hour – 1 day)
# Active failover:        60–300       (1–5 minutes)
# Before planned change:  300          (drop TTL 24h before migration)
# MX records:             3600         (mail routing rarely changes)
# NS records:             86400        (nameservers almost never change)
# TXT (SPF/DKIM):         3600         (email config, changes are rare)

# ── Pre-migration TTL reduction workflow ──────────────────────────────────────
# Day -1: Reduce TTL to 300 seconds
# Migration day: Change IP; within 5 minutes, all resolvers pick up the new IP
# Day +1: Raise TTL back to 3600+ for performance
```

---

## DNS in Linux

```bash
# ── /etc/hosts: local override (checked first, before DNS) ────────────────────
# /etc/hosts
127.0.0.1       localhost
127.0.1.1       my-machine
192.168.1.50    db.internal db
192.168.1.60    redis.internal redis

# Test that /etc/hosts is working:
getent hosts db.internal     # uses system resolution (hosts + DNS)
# vs:
dig db.internal              # bypasses /etc/hosts, queries DNS directly

# ── /etc/resolv.conf ──────────────────────────────────────────────────────────
cat /etc/resolv.conf
# nameserver 8.8.8.8     ← primary resolver
# nameserver 8.8.4.4     ← secondary resolver
# search example.com     ← append to bare names: "db" → "db.example.com"
# options ndots:5        ← use search list if name has < 5 dots

# On Ubuntu with systemd-resolved:
resolvectl status            # DNS config per interface, stats
resolvectl query example.com # resolve via systemd-resolved
resolvectl flush-caches      # flush DNS cache

# ── nsswitch.conf: resolution order ───────────────────────────────────────────
grep "^hosts" /etc/nsswitch.conf
# hosts: files dns        ← check /etc/hosts first, then DNS
# hosts: files mdns4_minimal [NOTFOUND=return] dns  ← with mDNS (Avahi)

# ── Test the full resolution chain ────────────────────────────────────────────
strace -e trace=network getent hosts example.com 2>&1 | grep connect
# Shows exact socket calls made during resolution
```

---

## DNS in Containers & Kubernetes

```bash
# ── Docker DNS ────────────────────────────────────────────────────────────────
# Docker's embedded DNS server: 127.0.0.11 (in containers)
# Containers can resolve each other by container name on the same network

docker run --dns 8.8.8.8 ubuntu        # custom DNS server
docker run --add-host db:192.168.1.50 ubuntu  # add /etc/hosts entry

# Inspect container's /etc/resolv.conf:
docker exec my-container cat /etc/resolv.conf
# nameserver 127.0.0.11  ← Docker's DNS
# options ndots:0

# ── Kubernetes DNS (CoreDNS) ───────────────────────────────────────────────────
# CoreDNS runs as a pod in kube-system, handles all in-cluster resolution

# Service DNS format:
# <service>.<namespace>.svc.cluster.local
# e.g.: my-api.production.svc.cluster.local → ClusterIP

# Pod DNS format:
# <pod-ip-dashes>.<namespace>.pod.cluster.local
# e.g.: 10-0-0-5.default.pod.cluster.local

kubectl get configmap coredns -n kube-system -o yaml   # view CoreDNS config
kubectl run -it debug --image=busybox --rm -- nslookup kubernetes.default
kubectl exec -it my-pod -- cat /etc/resolv.conf

# Debug DNS issues in Kubernetes:
kubectl run dnsutils --image=gcr.io/kubernetes-e2e-test-images/dnsutils:1.3 \
  --restart=Never -it -- /bin/sh
# Inside: nslookup my-service.my-namespace, dig kubernetes.default
```

---

## DNS Security

```bash
# ── DNSSEC: cryptographic signing of DNS records ──────────────────────────────
# Prevents cache poisoning (Kaminsky attack)
# Records are signed with zone's private key; resolvers verify with public key

dig example.com +dnssec           # request DNSSEC records
dig example.com DNSKEY            # zone's public signing key
dig example.com DS                # delegation signer (chain of trust)

# Check if a domain has DNSSEC enabled:
dig +short example.com DNSKEY | wc -l   # > 0 means DNSSEC enabled

# ── DoT and DoH: encrypted DNS ────────────────────────────────────────────────
# DNS-over-TLS (DoT): DNS over TCP port 853 (encrypted, standard protocol)
# DNS-over-HTTPS (DoH): DNS inside HTTPS (port 443, harder to block)

# Configure DoT in systemd-resolved:
# /etc/systemd/resolved.conf
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
DNSOverTLS=yes

# Test DoT with kdig (from knot-dnsutils):
kdig -d @1.1.1.1 +tls example.com

# Test DoH with curl:
curl -H "accept: application/dns-json" \
     "https://cloudflare-dns.com/dns-query?name=example.com&type=A"

# ── Common DNS attacks ────────────────────────────────────────────────────────
# Cache poisoning: attacker injects fake records into resolver cache → DNSSEC mitigates
# DNS amplification DDoS: attacker spoofs source, floods victim with DNS responses
# DNS hijacking: ISP or attacker redirects queries to malicious server
# Subdomain takeover: dangling CNAME points to unclaimed service
```

---

## Troubleshooting DNS

```bash
# Problem: "hostname resolves to wrong IP"
dig api.example.com @8.8.8.8 +short          # what does Google's resolver say?
dig api.example.com @ns1.example.com +short  # what does authoritative NS say?
# If authoritative is correct but public resolver is wrong → wait for TTL, or flush cache
# If authoritative is wrong → fix the DNS record at your registrar

# Problem: "DNS resolution is slow"
dig api.example.com | grep "Query time"
# High query time from 8.8.8.8 but low from local resolver → network routing issue
# High from all resolvers → authoritative NS is slow

# Problem: "works from one server, not another"
# Different /etc/resolv.conf?
diff <(ssh server1 cat /etc/resolv.conf) <(ssh server2 cat /etc/resolv.conf)
# Different /etc/hosts?
diff <(ssh server1 getent hosts api.example.com) <(ssh server2 getent hosts api.example.com)

# Problem: "Docker container can't resolve host"
docker exec container cat /etc/resolv.conf
docker exec container nslookup api.example.com
# Check if DNS port 53 is blocked by host firewall
iptables -L OUTPUT -n | grep 53

# Problem: "Kubernetes pod can't resolve service"
kubectl exec -it pod -- nslookup my-service
kubectl exec -it pod -- nslookup my-service.my-namespace.svc.cluster.local
kubectl get endpoints my-service -n my-namespace  # are there any endpoints?
kubectl logs -n kube-system -l k8s-app=kube-dns   # CoreDNS logs
```