# 🌐 Web Server

> A web server listens for HTTP/HTTPS requests, terminates TLS, serves static files, and hands dynamic requests off to an application server or reverse proxy. **Nginx** (event-driven, high-concurrency) and **Apache** (process-based, rich module ecosystem) are the two dominant choices.

---

## Nginx vs Apache — When to Choose Which

| | Nginx | Apache |
|--|-------|--------|
| Architecture | Event-driven, async | Process/thread per connection |
| Static file speed | Excellent | Good |
| High concurrency | Excellent (10k+ conn) | Good with mpm_event |
| Dynamic content | Via upstream proxy | Native modules (mod_php) |
| `.htaccess` support | No | Yes |
| Config style | Blocks (`server {}`) | Directives + `.htaccess` |
| Memory footprint | Low | Higher |
| Best for | Reverse proxy, static, high traffic | Shared hosting, legacy PHP, `.htaccess` |

---

## 📦 Installation

```bash
# ── Ubuntu / Debian ───────────────────────────────────────────────────────────
apt update
apt install -y nginx          # Nginx
apt install -y apache2        # Apache

# ── RHEL / CentOS / Fedora ────────────────────────────────────────────────────
dnf install -y nginx
dnf install -y httpd          # Apache on RHEL is called httpd

# ── macOS (Homebrew) ──────────────────────────────────────────────────────────
brew install nginx

# ── Enable and start ─────────────────────────────────────────────────────────
systemctl enable --now nginx
systemctl enable --now apache2   # or httpd on RHEL
```

---

## 🔧 Nginx Configuration

### File Layout

```
/etc/nginx/
├── nginx.conf                 ← main config (http block, global settings)
├── sites-available/           ← all virtual host definitions
│   ├── default
│   └── example.com.conf
├── sites-enabled/             ← symlinks to sites-available/ (active sites)
│   └── example.com.conf -> ../sites-available/example.com.conf
├── conf.d/                    ← drop-in config files (auto-included)
│   ├── gzip.conf
│   └── security-headers.conf
├── snippets/                  ← reusable config fragments
│   ├── ssl-params.conf
│   └── fastcgi-php.conf
└── modules-enabled/           ← loaded modules (Debian/Ubuntu)
```

### nginx.conf — Main Config

```nginx
# /etc/nginx/nginx.conf

user  www-data;

# worker_processes: set to number of CPU cores
# auto = Nginx detects and uses all available cores
worker_processes  auto;

# Maximum open file descriptors per worker
# Must be >= worker_connections
worker_rlimit_nofile  65535;

error_log  /var/log/nginx/error.log  warn;
pid        /run/nginx.pid;

events {
    # Maximum simultaneous connections per worker
    # Total capacity = worker_processes × worker_connections
    worker_connections  4096;

    # accept_mutex: serialize accept() to avoid thundering herd
    # Set off on Linux (epoll handles this natively)
    accept_mutex  off;

    # Use epoll on Linux — most efficient event model
    use  epoll;

    # Allow each worker to accept multiple connections at once
    multi_accept  on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # ── Logging format ────────────────────────────────────────────────────────
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    # JSON log format (easier to parse in log aggregators)
    log_format  json escape=json
        '{'
            '"time":"$time_iso8601",'
            '"remote_addr":"$remote_addr",'
            '"method":"$request_method",'
            '"uri":"$request_uri",'
            '"status":$status,'
            '"bytes_sent":$body_bytes_sent,'
            '"request_time":$request_time,'
            '"upstream_time":"$upstream_response_time",'
            '"user_agent":"$http_user_agent"'
        '}';

    access_log  /var/log/nginx/access.log  json;

    # ── Performance ───────────────────────────────────────────────────────────
    sendfile        on;    # zero-copy file transfer (kernel handles it)
    tcp_nopush      on;    # batch TCP packets (improves throughput)
    tcp_nodelay     on;    # disable Nagle algorithm (reduces latency)
    keepalive_timeout  65; # keep connections open for 65s
    keepalive_requests 1000; # max requests per keepalive connection

    # ── Buffers ───────────────────────────────────────────────────────────────
    client_body_buffer_size     128k;
    client_max_body_size        10m;   # max upload size
    client_header_buffer_size   1k;
    large_client_header_buffers 4 16k;

    # ── Gzip compression ──────────────────────────────────────────────────────
    gzip              on;
    gzip_vary         on;
    gzip_comp_level   5;        # 1 (fast) to 9 (best); 5 is a good balance
    gzip_min_length   1000;     # don't compress files smaller than 1KB
    gzip_proxied      any;
    gzip_types
        text/plain
        text/css
        text/javascript
        application/javascript
        application/json
        application/xml
        image/svg+xml
        font/woff2;

    # ── Security: hide Nginx version in error pages and headers ───────────────
    server_tokens  off;

    # ── Rate limiting zones ────────────────────────────────────────────────────
    # Shared memory zone "api_limit": 10MB, max 10 req/s per IP
    limit_req_zone  $binary_remote_addr  zone=api_limit:10m  rate=10r/s;
    # Login endpoint: stricter, 3 req/min per IP
    limit_req_zone  $binary_remote_addr  zone=login_limit:10m  rate=3r/m;

    # ── Include virtual host configs ──────────────────────────────────────────
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

---

### Virtual Host — HTTP to HTTPS redirect

```nginx
# /etc/nginx/sites-available/example.com.conf

# ── HTTP: redirect all traffic to HTTPS ──────────────────────────────────────
server {
    listen       80;
    listen       [::]:80;          # IPv6
    server_name  example.com www.example.com;

    # Let's Encrypt ACME challenge (must be accessible over HTTP)
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect everything else to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}
```

---

### Virtual Host — HTTPS with full hardening

```nginx
# ── HTTPS: main server block ─────────────────────────────────────────────────
server {
    listen       443 ssl;
    listen       [::]:443 ssl;
    http2        on;               # enable HTTP/2 (nginx ≥ 1.25.1 syntax)
    server_name  example.com www.example.com;

    # ── TLS certificates (generated by certbot) ───────────────────────────────
    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # ── TLS settings ─────────────────────────────────────────────────────────
    ssl_protocols              TLSv1.2 TLSv1.3;   # disable TLS 1.0, 1.1
    ssl_ciphers                ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers  off;

    # DH parameters for perfect forward secrecy
    # Generate: openssl dhparam -out /etc/nginx/dhparam.pem 2048
    ssl_dhparam /etc/nginx/dhparam.pem;

    # Session resumption (improves TLS handshake performance)
    ssl_session_timeout  1d;
    ssl_session_cache    shared:MozSSL:10m;   # 10MB ≈ 40,000 sessions
    ssl_session_tickets  off;                 # disable for perfect forward secrecy

    # OCSP stapling: server fetches + caches cert revocation status
    ssl_stapling        on;
    ssl_stapling_verify on;
    resolver            8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout    5s;

    # ── Security headers ──────────────────────────────────────────────────────
    add_header  Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header  X-Frame-Options           "SAMEORIGIN"             always;
    add_header  X-Content-Type-Options    "nosniff"                always;
    add_header  X-XSS-Protection          "1; mode=block"          always;
    add_header  Referrer-Policy           "strict-origin-when-cross-origin" always;
    add_header  Permissions-Policy        "geolocation=(), microphone=(), camera=()" always;
    add_header  Content-Security-Policy   "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'" always;

    # ── Document root ─────────────────────────────────────────────────────────
    root   /var/www/example.com/public;
    index  index.html index.htm;

    # ── Static file caching ───────────────────────────────────────────────────
    # Tell browsers to cache immutable assets (hashed filenames) for 1 year
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires     1y;
        add_header  Cache-Control "public, immutable";
        access_log  off;                # don't log static file hits
    }

    # HTML files: no caching (always fresh)
    location ~* \.html$ {
        expires    -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }

    # ── API rate limiting ──────────────────────────────────────────────────────
    location /api/ {
        limit_req  zone=api_limit  burst=20  nodelay;
        limit_req_status 429;

        # Proxy to backend (see reverse-proxy.md for full config)
        proxy_pass  http://backend_pool;
    }

    location /api/auth/login {
        limit_req  zone=login_limit  burst=5;
        proxy_pass http://backend_pool;
    }

    # ── Default location ─────────────────────────────────────────────────────
    location / {
        try_files $uri $uri/ /index.html;   # SPA fallback
    }

    # ── Block hidden files (.env, .git, etc.) ────────────────────────────────
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # ── Custom error pages ────────────────────────────────────────────────────
    error_page  404              /404.html;
    error_page  500 502 503 504  /50x.html;
    location = /50x.html {
        root /var/www/html;
    }
}
```

---

### SSL Certificate with Let's Encrypt (Certbot)

```bash
# Install certbot with Nginx plugin
apt install certbot python3-certbot-nginx

# Obtain and install certificate (auto-edits nginx config)
certbot --nginx -d example.com -d www.example.com

# Obtain certificate only (you manage nginx config manually)
certbot certonly --nginx -d example.com -d www.example.com

# Test auto-renewal
certbot renew --dry-run

# Renewal is handled automatically by a systemd timer or cron:
# /etc/cron.d/certbot  or  systemctl list-timers | grep certbot

# Verify certificate
openssl s_client -connect example.com:443 -servername example.com < /dev/null | \
  openssl x509 -noout -dates
```

---

## 🔧 Apache Configuration

### File Layout

```
/etc/apache2/               (Ubuntu/Debian)   /etc/httpd/               (RHEL)
├── apache2.conf            ← main config     ├── conf/httpd.conf
├── ports.conf              ← Listen ports    ├── conf.d/
├── sites-available/        ← vhosts          ├── sites-enabled/
│   └── example.com.conf                      └── modules/
├── sites-enabled/          ← active symlinks
├── conf-available/         ← fragments
├── conf-enabled/
└── mods-enabled/           ← loaded modules
```

### Enable Required Modules

```bash
# SSL and modern features
a2enmod ssl
a2enmod headers        # add_header directives
a2enmod rewrite        # mod_rewrite (URL rewriting / redirects)
a2enmod deflate        # gzip compression
a2enmod expires        # browser caching headers
a2enmod proxy          # reverse proxy support
a2enmod proxy_http     # HTTP proxy
a2enmod http2          # HTTP/2 support

# Apply
systemctl restart apache2
```

### Virtual Host — HTTP redirect + HTTPS with hardening

```apache
# /etc/apache2/sites-available/example.com.conf

# ── HTTP: redirect to HTTPS ───────────────────────────────────────────────────
<VirtualHost *:80>
    ServerName  example.com
    ServerAlias www.example.com

    # Allow Let's Encrypt ACME challenge over HTTP
    Alias /.well-known/acme-challenge/ /var/www/certbot/.well-known/acme-challenge/
    <Directory /var/www/certbot/.well-known/acme-challenge/>
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    # Redirect everything else to HTTPS
    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/\.well-known/
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>

# ── HTTPS: main virtual host ─────────────────────────────────────────────────
<VirtualHost *:443>
    ServerName  example.com
    ServerAlias www.example.com

    DocumentRoot /var/www/example.com/public
    DirectoryIndex index.html index.htm

    # ── TLS ──────────────────────────────────────────────────────────────────
    SSLEngine on
    SSLCertificateFile      /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile   /etc/letsencrypt/live/example.com/privkey.pem

    SSLProtocol             all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder     off
    SSLSessionTickets       off

    # HTTP/2 (requires mod_http2)
    Protocols h2 http/1.1

    # ── Security headers ──────────────────────────────────────────────────────
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"

    # Hide Apache version
    ServerSignature Off

    # ── Compression ───────────────────────────────────────────────────────────
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/css
        AddOutputFilterByType DEFLATE application/javascript application/json
        AddOutputFilterByType DEFLATE image/svg+xml font/woff2
    </IfModule>

    # ── Browser caching ───────────────────────────────────────────────────────
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/jpeg         "access plus 1 year"
        ExpiresByType image/png          "access plus 1 year"
        ExpiresByType text/css           "access plus 1 month"
        ExpiresByType application/javascript "access plus 1 month"
        ExpiresByType text/html          "access plus 0 seconds"
    </IfModule>

    # ── Directory settings ────────────────────────────────────────────────────
    <Directory /var/www/example.com/public>
        Options -Indexes -FollowSymLinks   # disable directory listing
        AllowOverride None                 # disable .htaccess (better performance)
        Require all granted

        # SPA fallback
        FallbackResource /index.html
    </Directory>

    # ── Block hidden files ────────────────────────────────────────────────────
    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>

    # ── Logs ─────────────────────────────────────────────────────────────────
    ErrorLog  ${APACHE_LOG_DIR}/example.com_error.log
    CustomLog ${APACHE_LOG_DIR}/example.com_access.log combined
</VirtualHost>
```

```bash
# Enable the site and reload
a2ensite example.com.conf
apache2ctl configtest && systemctl reload apache2
```

---

## 🔍 Testing & Debugging

```bash
# ── Nginx ────────────────────────────────────────────────────────────────────
nginx -t                                      # syntax check
nginx -T                                      # dump full config (includes)
nginx -s reload                               # zero-downtime reload
nginx -s quit                                 # graceful shutdown

# Check which config file controls a request
nginx -T 2>&1 | grep -A5 "server_name example.com"

# Watch logs live
tail -f /var/log/nginx/access.log | grep " 5[0-9][0-9] "   # errors only
tail -f /var/log/nginx/error.log

# ── Apache ────────────────────────────────────────────────────────────────────
apache2ctl configtest                         # syntax check
apache2ctl -S                                 # list all virtual hosts and ports
apache2ctl graceful                           # zero-downtime reload

# ── TLS testing ───────────────────────────────────────────────────────────────
curl -vI https://example.com                  # verbose headers
openssl s_client -connect example.com:443     # raw TLS inspect
ssllabs-scan example.com                      # SSL Labs grade (online)

# Test compression
curl -H "Accept-Encoding: gzip" -I https://example.com
curl -H "Accept-Encoding: gzip" -o /dev/null -s -w "%{size_download}\n" https://example.com

# ── Benchmark ────────────────────────────────────────────────────────────────
ab -n 1000 -c 50 https://example.com/          # Apache Bench
wrk -t4 -c100 -d30s https://example.com/       # wrk (more realistic)
```

---

## 📈 Performance Tuning Checklist

| Setting | Nginx | Apache | What it does |
|---------|-------|--------|-------------|
| HTTP/2 | `http2 on` | `Protocols h2` | Multiplexed streams, header compression |
| Gzip | `gzip on` | `mod_deflate` | 60–80% response size reduction |
| Keepalive | `keepalive_timeout 65` | `KeepAliveTimeout 65` | Reuse TCP connections |
| Static cache headers | `expires 1y` | `mod_expires` | Browser caches assets |
| Worker tuning | `worker_processes auto` | `mpm_event` module | Match CPU cores |
| Buffer sizes | `client_body_buffer_size` | `MaxRequestWorkers` | Prevent disk I/O for small bodies |
| `sendfile` | `sendfile on` | `EnableSendfile on` | Zero-copy static file transfer |