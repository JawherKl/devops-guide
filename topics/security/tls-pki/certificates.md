# 🔐 TLS & Certificates

> TLS (Transport Layer Security) encrypts traffic between two parties and authenticates the server's identity. Every HTTPS connection, every API call, every service-to-service communication in a secure infrastructure uses TLS. Understanding how certificates work — how they're issued, validated, rotated, and revoked — means you can debug TLS errors, set up your own CA, and implement mTLS for zero-trust architectures.

---

## How TLS Works

```
Client (browser/curl/service)           Server
──────────────────────────             ──────────────────────────────

1. ClientHello
   → TLS version, cipher suites supported, random bytes
   ─────────────────────────────────────────────────────►

2. ServerHello + Certificate + ServerHelloDone
   ← TLS version chosen, cipher chosen, random bytes
   ← Server certificate (contains public key + identity)
   ◄─────────────────────────────────────────────────────

3. Certificate validation (client-side):
   • Is the cert signed by a trusted CA?
   • Is the cert expired?
   • Does the hostname match (CN or SAN)?
   • Is the cert revoked (OCSP check)?

4. Key exchange (ECDH):
   Both sides compute the same session key independently
   ◄────────────────────────────────────────────────────►

5. Finished (both sides confirm the handshake)
   ◄────────────────────────────────────────────────────►

6. Encrypted application data
   ◄────────────────────────────────────────────────────►
   All traffic encrypted with AES-256-GCM or ChaCha20-Poly1305
```

---

## Certificate Anatomy

```bash
# View a certificate in human-readable form
openssl x509 -in cert.pem -text -noout

# Key fields to understand:
# Subject:          CN=api.example.com, O=Example Corp
# Issuer:           CN=Let's Encrypt R3
# Not Before:       Jan 1 00:00:00 2025 GMT
# Not After:        Apr 1 00:00:00 2025 GMT   ← expiry (90 days for LE)
# Subject Alt Names (SAN):
#   DNS:api.example.com
#   DNS:*.api.example.com
#   IP Address:10.0.0.5          ← SANs are what browsers actually check
# Key Usage:         Digital Signature, Key Encipherment
# Extended Key Usage: TLS Web Server Authentication
# Basic Constraints: CA:FALSE    ← this is not a CA certificate
# Authority Key Identifier: keyid:... (links to issuer's key)

# Quick info — just dates and names:
openssl x509 -in cert.pem -noout -subject -issuer -dates -ext subjectAltName

# Check a live server's certificate:
openssl s_client -connect api.example.com:443 -servername api.example.com </dev/null 2>/dev/null \
  | openssl x509 -text -noout

# Check certificate expiry for monitoring:
openssl x509 -in cert.pem -noout -enddate
# Output: notAfter=Apr  1 00:00:00 2026 GMT

# Check how many days until expiry:
openssl x509 -in cert.pem -noout -checkend $((30 * 86400))
# Returns 0 if cert is valid for 30+ days, 1 if expiring within 30 days
```

---

## Let's Encrypt with Certbot

```bash
# ── Install ───────────────────────────────────────────────────────────────────
apt install certbot python3-certbot-nginx   # nginx plugin
apt install certbot python3-certbot-apache  # apache plugin

# ── Issue a certificate ───────────────────────────────────────────────────────
# With Nginx (automatic nginx config update):
certbot --nginx -d example.com -d www.example.com

# Standalone (no web server running):
certbot certonly --standalone -d example.com

# Webroot (web server serves .well-known challenge):
certbot certonly --webroot -w /var/www/html -d example.com

# DNS challenge (for wildcard certs, internal servers):
certbot certonly --manual --preferred-challenges dns -d "*.example.com"
# Adds a _acme-challenge TXT record to your DNS zone

# ── Certificate locations ─────────────────────────────────────────────────────
# /etc/letsencrypt/live/example.com/
#   cert.pem       → server certificate only
#   chain.pem      → intermediate CA certificates
#   fullchain.pem  → cert.pem + chain.pem (use this for web servers)
#   privkey.pem    → private key (PROTECT THIS — chmod 600)

# Nginx config:
ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

# ── Renewal ───────────────────────────────────────────────────────────────────
# Test renewal (dry run — no changes made):
certbot renew --dry-run

# Manual renewal:
certbot renew

# Auto-renewal (certbot installs a systemd timer):
systemctl status certbot.timer
systemctl list-timers | grep certbot

# The timer runs twice daily and renews if < 30 days remain.
# Add a deploy hook to reload Nginx after renewal:
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh << 'EOF'
#!/bin/sh
nginx -t && systemctl reload nginx
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

# ── Monitor expiry ────────────────────────────────────────────────────────────
certbot certificates                # list all managed certs + expiry dates
```

---

## Creating Certificates with OpenSSL

```bash
# ── Generate a private key ────────────────────────────────────────────────────
openssl genpkey -algorithm ED25519 -out private.key               # Ed25519 (modern)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 \
  -out private.key                                                 # RSA 4096
openssl ecparam -name prime256v1 -genkey -noout -out private.key  # ECDSA P-256

# ── Generate a CSR (Certificate Signing Request) ──────────────────────────────
# CSR = request to a CA to issue a cert for your key
openssl req -new -key private.key -out server.csr \
  -subj "/C=US/ST=California/L=San Francisco/O=Example Corp/CN=api.example.com"

# CSR with Subject Alternative Names (required by modern browsers):
cat > san.conf << 'EOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C  = US
ST = California
L  = San Francisco
O  = Example Corp
CN = api.example.com

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = api.example.com
DNS.2 = *.api.example.com
IP.1  = 10.0.0.5
EOF

openssl req -new -key private.key -out server.csr -config san.conf

# Verify CSR content:
openssl req -in server.csr -text -noout -verify

# ── Self-signed certificate (for testing/internal) ───────────────────────────
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
  -days 365 -nodes \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

# One-liner for a self-signed cert with SAN:
openssl req -x509 -nodes -days 365 \
  -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout key.pem \
  -out cert.pem \
  -subj "/CN=dev.local" \
  -addext "subjectAltName=DNS:dev.local,DNS:*.dev.local,IP:127.0.0.1"
```

---

## Internal Certificate Authority (CA)

For service-to-service TLS inside a private network, you run your own CA. No public CA required.

```bash
# ── Option 1: cfssl (Cloudflare's PKI toolkit) ────────────────────────────────
apt install golang-cfssl  # or download from releases

# CA config and CSR:
cat > ca-csr.json << 'EOF'
{
  "CN": "Example Internal CA",
  "key": {"algo": "ecdsa", "size": 256},
  "names": [{"C": "US", "O": "Example Corp", "OU": "Internal CA"}],
  "ca": {"expiry": "87600h"}   # 10 years
}
EOF

cat > ca-config.json << 'EOF'
{
  "signing": {
    "default": {"expiry": "8760h"},
    "profiles": {
      "server": {
        "expiry": "8760h",
        "usages": ["signing","key encipherment","server auth"]
      },
      "client": {
        "expiry": "8760h",
        "usages": ["signing","key encipherment","client auth"]
      },
      "peer": {
        "expiry": "8760h",
        "usages": ["signing","key encipherment","server auth","client auth"]
      }
    }
  }
}
EOF

# Generate CA:
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
# Output: ca.pem (public cert), ca-key.pem (PROTECT THIS), ca.csr

# Issue a server certificate:
cat > api-csr.json << 'EOF'
{
  "CN": "api.example.internal",
  "hosts": ["api.example.internal","10.0.2.10"],
  "key": {"algo": "ecdsa", "size": 256}
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem \
  -config=ca-config.json -profile=server \
  api-csr.json | cfssljson -bare api

# Output: api.pem (cert), api-key.pem (key), api.csr

# ── Option 2: step-ca (ACME-compatible, automated rotation) ──────────────────
# Install step CLI + step-ca
curl -LO https://dl.smallstep.com/cli/docs-cli-install/latest/step_amd64.deb
dpkg -i step_amd64.deb

# Initialize CA:
step ca init \
  --name "Example Internal CA" \
  --dns "ca.internal.example.com" \
  --address ":9000" \
  --provisioner "admin@example.com"

# Start CA:
step-ca $(step path)/config/ca.json

# Issue a certificate (ACME protocol — same as Let's Encrypt, but internal):
step ca certificate api.example.internal api.pem api-key.pem

# Auto-renew in the background:
step ca renew --daemon api.pem api-key.pem
```

---

## mTLS — Mutual TLS

In standard TLS, only the server authenticates with a certificate. In mTLS, **both sides** present certificates — the server verifies the client's identity, and vice versa. This is the foundation of zero-trust networking.

```bash
# ── Issue client certificate ──────────────────────────────────────────────────
cat > client-csr.json << 'EOF'
{
  "CN": "api-gateway",
  "key": {"algo": "ecdsa", "size": 256}
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem \
  -config=ca-config.json -profile=client \
  client-csr.json | cfssljson -bare client

# ── Nginx: require client certificate ─────────────────────────────────────────
server {
    listen 443 ssl;
    server_name api.example.internal;

    ssl_certificate     /etc/nginx/certs/server.pem;
    ssl_certificate_key /etc/nginx/certs/server-key.pem;
    ssl_client_certificate /etc/nginx/certs/ca.pem;    # CA that signed clients
    ssl_verify_client   on;                             # require valid client cert
    ssl_verify_depth    2;

    # Downstream can see client cert info in headers:
    proxy_set_header X-Client-CN  $ssl_client_s_dn_cn;
    proxy_set_header X-Client-Verify $ssl_client_verify;
}

# ── Test with curl ────────────────────────────────────────────────────────────
curl --cert client.pem --key client-key.pem \
     --cacert ca.pem \
     https://api.example.internal/health

# Without a certificate (should be rejected):
curl --cacert ca.pem https://api.example.internal/health
# 400 Bad Request: No required SSL certificate was sent

# ── Python service with mTLS ──────────────────────────────────────────────────
import ssl
import httpx

ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile="ca.pem")
ctx.load_cert_chain(certfile="client.pem", keyfile="client-key.pem")

client = httpx.Client(ssl_context=ctx)
response = client.get("https://api.example.internal/v1/data")
```

---

## TLS Hardening for Nginx

```nginx
# /etc/nginx/conf.d/tls-hardening.conf
# Include in every HTTPS server block

ssl_protocols TLSv1.2 TLSv1.3;                   # disable TLS 1.0 and 1.1
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256;
ssl_prefer_server_ciphers off;                     # let client choose (TLS 1.3)

# Session tickets (performance vs security tradeoff)
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;                 # 10MB shared cache
ssl_session_tickets off;                           # disable for perfect forward secrecy

# OCSP Stapling (server caches revocation status — faster for clients)
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Security headers
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header Referrer-Policy no-referrer-when-downgrade always;
add_header Content-Security-Policy "default-src 'self'" always;

# DH parameters (for DHE ciphers)
ssl_dhparam /etc/nginx/dhparam.pem;                # generate: openssl dhparam -out /etc/nginx/dhparam.pem 4096
```

---

## Certificate Monitoring & Rotation

```bash
# ── Check expiry of all certs on a host ───────────────────────────────────────
find /etc/ssl /etc/nginx/certs /etc/letsencrypt/live \
  -name "*.pem" -o -name "*.crt" 2>/dev/null | \
  while read cert; do
    expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)
    days=$(( ( $(date -d "$expiry" +%s) - $(date +%s) ) / 86400 ))
    echo "$days days: $cert ($expiry)"
  done | sort -n

# ── Alert when cert expires within 30 days ───────────────────────────────────
check_cert() {
  local domain="$1"
  local port="${2:-443}"
  local warn_days=30
  local expiry
  expiry=$(echo | openssl s_client -connect "${domain}:${port}" \
    -servername "$domain" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null \
    | cut -d= -f2)
  local days=$(( ( $(date -d "$expiry" +%s) - $(date +%s) ) / 86400 ))
  if [ "$days" -lt "$warn_days" ]; then
    echo "WARNING: $domain expires in $days days ($expiry)"
  else
    echo "OK: $domain expires in $days days"
  fi
}

check_cert api.example.com
check_cert example.com 443

# ── Prometheus + Blackbox Exporter for cert monitoring ───────────────────────
# prometheus.yml scrape config:
scrape_configs:
  - job_name: ssl_expiry
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://api.example.com
          - https://example.com
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - target_label: __address__
        replacement: blackbox-exporter:9115

# Alertmanager rule:
# alert: SSLCertExpiringSoon
# expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 30
# labels: severity: warning
```