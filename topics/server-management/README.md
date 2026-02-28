# 🖥️ Server Management

<p align="center">
  <img src="https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white"/>
  <img src="https://img.shields.io/badge/Apache-D22128?style=for-the-badge&logo=apache&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/UFW-E95420?style=for-the-badge&logo=ubuntu&logoColor=white"/>
  <img src="https://img.shields.io/badge/Varnish-00B0D8?style=for-the-badge&logoColor=white"/>
</p>

> Before containers and Kubernetes, every application ran on a server. That server needed a web server to receive requests, a reverse proxy to route them, a firewall to protect it, and a cache to keep it fast. These fundamentals haven't changed — containers just add a layer on top. This topic covers the complete server stack from scratch.

---

## 💡 How the Pieces Fit Together

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  Firewall  (iptables / ufw / nftables)                  │
│  • Drop everything except ports 80, 443, 22             │
│  • Rate-limit SSH, block known bad IPs                  │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  Web Server  (Nginx / Apache)                           │
│  • Terminate TLS (HTTPS)                                │
│  • Serve static files directly                          │
│  • Handle HTTP/2, compression, headers                  │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  Reverse Proxy  (Nginx / Traefik / HAProxy)             │
│  • Route requests to backend services                   │
│  • Load balance across multiple app instances           │
│  • Health-check backends, circuit break on failure      │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  Caching Server  (Varnish / Redis / Nginx proxy_cache)  │
│  • Serve repeated requests from memory                  │
│  • Reduce load on application and database              │
│  • Cache-Control headers, cache invalidation            │
└─────────────────────────────────────────────────────────┘
    │
    ▼
  App Server (Node.js / Python / Go / PHP…)
```

---

## 📋 Files in This Topic

| File | What you'll learn |
|------|-------------------|
| [web-server.md](./web-server.md) | Install and configure Nginx & Apache — virtual hosts, TLS, compression, security headers |
| [reverse-proxy.md](./reverse-proxy.md) | Proxy to backends, load balancing algorithms, health checks, upstream pools |
| [firewall.md](./firewall.md) | UFW, iptables, nftables — rules, rate limiting, logging, hardening |
| [catching-server.md](./catching-server.md) | Varnish VCL, Nginx proxy_cache, Redis — TTL, purging, cache-control strategies |

---

## 🗺️ Learning Path

```
1. firewall.md          ← secure the server before opening any ports
        ↓
2. web-server.md        ← configure Nginx/Apache to receive HTTP/HTTPS
        ↓
3. reverse-proxy.md     ← route traffic to your application backends
        ↓
4. catching-server.md   ← cache responses to reduce load and latency
```

---

## ⚡ Quick Reference Commands

```bash
# ── Nginx ────────────────────────────────────────────────────────────────────
nginx -t                          # test config syntax
nginx -s reload                   # reload without downtime
systemctl status nginx
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# ── Apache ───────────────────────────────────────────────────────────────────
apachectl configtest              # test config syntax
systemctl reload apache2          # reload without downtime
a2ensite mysite.conf && a2dissite default
a2enmod ssl rewrite headers proxy proxy_http

# ── UFW (firewall) ────────────────────────────────────────────────────────────
ufw status verbose
ufw allow 'Nginx Full'
ufw deny from 198.51.100.0/24
ufw limit ssh

# ── SSL/TLS with Let's Encrypt ───────────────────────────────────────────────
certbot --nginx  -d example.com -d www.example.com
certbot renew --dry-run
openssl s_client -connect example.com:443 -servername example.com

# ── Varnish ───────────────────────────────────────────────────────────────────
varnishlog                        # live request log
varnishstat                       # real-time stats (hit rate, threads…)
varnishadm ban req.url ~ /api/    # purge all URLs matching /api/
```

---

## 🛠️ Prerequisites

| Tool | Install |
|------|---------|
| Nginx | `apt install nginx` / `yum install nginx` |
| Apache | `apt install apache2` / `yum install httpd` |
| Certbot | `apt install certbot python3-certbot-nginx` |
| UFW | `apt install ufw` (pre-installed on Ubuntu) |
| Varnish | `apt install varnish` |
| Redis | `apt install redis-server` |

---

## 🔗 Related Topics

- [Containers](../containers/) — run Nginx/Varnish as Docker containers
- [Orchestration](../orchestration/) — Nginx Ingress Controller, Kubernetes-native routing
- [CI/CD](../ci-cd/) — automate config deployment and cert renewal
- [Monitoring](../monitoring/) — Nginx metrics with Prometheus exporter, log shipping
- [DevSecOps](../devsecops/) — TLS hardening, CSP headers, mod_security