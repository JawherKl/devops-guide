# 🔀 Reverse Proxy

> A reverse proxy sits between clients and backend servers. Clients talk to the proxy — the proxy talks to backends on their behalf. This enables load balancing, TLS termination, health checking, request routing, and circuit breaking — all without changing the application.

---

## Why a Reverse Proxy?

```
Without reverse proxy                 With reverse proxy
─────────────────────────────         ──────────────────────────────────────
Client → App :3000 (no TLS)           Client → Nginx :443 (TLS termination)
Client → App :3001                           → upstream pool (app:3000, app:3001)
Client → App :3002                    App only sees plain HTTP on localhost
Apps manage TLS individually          One TLS cert, multiple backends
```

**Key benefits:**
- **TLS termination** — apps handle plain HTTP, proxy handles HTTPS
- **Load balancing** — spread traffic across app instances
- **Health checking** — remove unhealthy backends automatically
- **SSL offloading** — CPU-intensive TLS handshakes done once at the proxy
- **Single entry point** — simplifies firewall rules and monitoring
- **Request buffering** — protect slow app servers from slow clients

---

## Nginx as Reverse Proxy

### Single Backend

```nginx
# /etc/nginx/sites-available/api.example.com.conf

upstream backend {
    server 127.0.0.1:3000;
}

server {
    listen      443 ssl;
    http2       on;
    server_name api.example.com;

    ssl_certificate     /etc/letsencrypt/live/api.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.example.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;

    location / {
        proxy_pass  http://backend;

        # ── Essential proxy headers ──────────────────────────────────────────
        # Tell the backend the real client IP (not the proxy's IP)
        proxy_set_header  X-Real-IP          $remote_addr;
        # Pass the full chain of proxies (for multi-hop setups)
        proxy_set_header  X-Forwarded-For    $proxy_add_x_forwarded_for;
        # Tell the backend the original protocol (https)
        proxy_set_header  X-Forwarded-Proto  $scheme;
        # Pass the original Host header (not the upstream address)
        proxy_set_header  Host               $host;
        # Required for WebSocket upgrade (harmless for HTTP)
        proxy_set_header  Upgrade            $http_upgrade;
        proxy_set_header  Connection         "upgrade";

        # ── Timeouts ─────────────────────────────────────────────────────────
        proxy_connect_timeout  10s;   # max time to connect to upstream
        proxy_send_timeout     60s;   # max time to send request to upstream
        proxy_read_timeout     60s;   # max time to wait for upstream response
        send_timeout           60s;   # max time to send response to client

        # ── Buffering ─────────────────────────────────────────────────────────
        # Buffer upstream response in memory before sending to client.
        # Protects slow app servers from slow clients (Slowloris attack).
        proxy_buffering          on;
        proxy_buffer_size        4k;
        proxy_buffers            8 4k;
        proxy_busy_buffers_size  8k;

        # ── Hide upstream headers the client shouldn't see ────────────────────
        proxy_hide_header  X-Powered-By;
        proxy_hide_header  Server;
    }
}
```

---

### Load Balancing — Multiple Backends

```nginx
# /etc/nginx/sites-available/app.example.com.conf

upstream app_pool {
    # ── Load balancing algorithms ─────────────────────────────────────────────
    # (default)        round_robin — rotate through all servers in order
    # least_conn       — send to server with fewest active connections (recommended)
    # ip_hash          — sticky sessions: same client IP always hits same server
    # hash $request_uri — consistent hash by URI (good for cache locality)

    least_conn;                        # use least-connections algorithm

    # ── Backend servers ───────────────────────────────────────────────────────
    server app1.internal:3000  weight=3;   # weight=3: gets 3× more traffic
    server app2.internal:3000  weight=3;
    server app3.internal:3000  weight=1;   # weight=1: canary — gets less traffic

    # ── Health check parameters per server ───────────────────────────────────
    # max_fails:    mark server down after this many consecutive failures
    # fail_timeout: after marking down, retry after this duration
    server app4.internal:3000  max_fails=3  fail_timeout=30s;

    # ── Backup server ─────────────────────────────────────────────────────────
    # Only used when all primary servers are down
    server app-backup.internal:3000  backup;

    # ── Take a server out of rotation without removing it ────────────────────
    # server app5.internal:3000  down;

    # ── Keepalive connections to upstreams ────────────────────────────────────
    # Maintain persistent connections to backend — reduces TCP handshake overhead
    keepalive  32;              # keep up to 32 idle connections per worker
}

server {
    listen      443 ssl;
    http2       on;
    server_name app.example.com;

    ssl_certificate     /etc/letsencrypt/live/app.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;

    location / {
        proxy_pass         http://app_pool;
        proxy_http_version 1.1;             # required for keepalive to upstreams
        proxy_set_header   Connection "";   # required for keepalive (clear hop header)
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

---

### Active Health Checks (Nginx Plus / OpenResty)

```nginx
# Nginx open-source uses passive health checks (marks server down after failures).
# For active health checks (Nginx Plus or ngx_http_upstream_hc_module):

upstream app_pool {
    server app1.internal:3000;
    server app2.internal:3000;

    # Nginx Plus syntax:
    # zone app_pool 64k;            # shared memory for health state
}

server {
    location / {
        proxy_pass http://app_pool;

        # Nginx Plus active health check:
        # health_check interval=5s fails=2 passes=3 uri=/health;
    }
}
```

For **open-source Nginx**, configure the backend app to return a non-200 on its health endpoint when unhealthy — Nginx's passive checker (`max_fails`) will remove it after `max_fails` consecutive 5xx/connection-refused responses.

---

### Path-Based Routing

```nginx
# Route different URL prefixes to different backend services
# Useful for a microservices architecture behind a single domain.

server {
    listen      443 ssl;
    http2       on;
    server_name api.example.com;

    ssl_certificate     /etc/letsencrypt/live/api.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.example.com/privkey.pem;

    # ── /api/users/* → user-service ──────────────────────────────────────────
    location /api/users/ {
        proxy_pass         http://user_service/;   # trailing slash strips prefix
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    # ── /api/tasks/* → task-service ──────────────────────────────────────────
    location /api/tasks/ {
        proxy_pass         http://task_service/;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    # ── /ws → WebSocket backend ───────────────────────────────────────────────
    location /ws {
        proxy_pass          http://websocket_backend;
        proxy_http_version  1.1;
        proxy_set_header    Upgrade    $http_upgrade;
        proxy_set_header    Connection "Upgrade";
        proxy_set_header    Host       $host;
        proxy_read_timeout  3600s;    # keep WebSocket connections alive for 1 hour
    }

    # ── Default: static frontend ──────────────────────────────────────────────
    location / {
        root      /var/www/frontend/dist;
        try_files $uri $uri/ /index.html;
    }
}

upstream user_service  { server 127.0.0.1:3001; }
upstream task_service  { server 127.0.0.1:3002; }
upstream websocket_backend { server 127.0.0.1:3003; }
```

---

### Proxy Caching

```nginx
# /etc/nginx/conf.d/proxy-cache.conf
# Define a shared cache zone — use BEFORE your server blocks

proxy_cache_path  /var/cache/nginx
                  levels=1:2
                  keys_zone=api_cache:10m    # 10MB of cache metadata (~80k keys)
                  max_size=1g                # max disk usage for cached content
                  inactive=60m              # remove content not accessed in 60 min
                  use_temp_path=off;         # write directly to cache dir (faster)

# In your server block:
server {
    ...
    location /api/ {
        proxy_pass         http://backend_pool;
        proxy_cache        api_cache;

        # Cache successful GET/HEAD responses for 10 minutes
        proxy_cache_valid  200 301   10m;
        proxy_cache_valid  302       1m;
        proxy_cache_valid  404       1m;

        # Cache key: method + scheme + host + URI
        proxy_cache_key    "$request_method$scheme$host$request_uri";

        # Cache even if upstream sends no-cache header
        # (respects your explicit TTL above instead)
        proxy_ignore_headers  Cache-Control Expires;

        # Return stale cache if upstream is down (grace period)
        proxy_cache_use_stale  error timeout updating http_500 http_502 http_503;
        proxy_cache_background_update  on;   # refresh cache in background
        proxy_cache_lock               on;   # only one request fetches for a given key

        # Add a header so you can see cache hit/miss in responses
        add_header  X-Cache-Status  $upstream_cache_status;
    }
}
```

---

## Apache as Reverse Proxy

```apache
# /etc/apache2/sites-available/api.example.com.conf

<VirtualHost *:443>
    ServerName api.example.com

    SSLEngine on
    SSLCertificateFile    /etc/letsencrypt/live/api.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/api.example.com/privkey.pem

    # ── Simple proxy ─────────────────────────────────────────────────────────
    ProxyPreserveHost On             # pass original Host header to backend
    ProxyRequests     Off            # disable forward proxy (security)

    # Pass real client IP to backend
    RequestHeader set X-Real-IP       "%{REMOTE_ADDR}s"
    RequestHeader set X-Forwarded-For "%{REMOTE_ADDR}s"
    RequestHeader set X-Forwarded-Proto "https"

    ProxyPass        /  http://127.0.0.1:3000/
    ProxyPassReverse /  http://127.0.0.1:3000/

    # ── Load balancer with balancer manager ───────────────────────────────────
    # Requires: a2enmod proxy_balancer lbmethod_byrequests
    <Proxy "balancer://app_pool">
        BalancerMember http://app1.internal:3000  loadfactor=3
        BalancerMember http://app2.internal:3000  loadfactor=3
        BalancerMember http://app3.internal:3000  loadfactor=1  status=+H   # hot standby

        # lbmethod: byrequests (round-robin), bytraffic, bybusyness, heartbeat
        ProxySet lbmethod=bybusyness
    </Proxy>

    ProxyPass        /  balancer://app_pool/
    ProxyPassReverse /  balancer://app_pool/

    ErrorLog  ${APACHE_LOG_DIR}/api.example.com_error.log
    CustomLog ${APACHE_LOG_DIR}/api.example.com_access.log combined
</VirtualHost>
```

---

## HAProxy — Dedicated Load Balancer

HAProxy is purpose-built for load balancing and is more feature-rich than Nginx's upstream module for complex routing needs.

```
# /etc/haproxy/haproxy.cfg

global
    log /dev/log  local0
    log /dev/log  local1 notice
    chroot        /var/lib/haproxy
    stats socket  /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user          haproxy
    group         haproxy
    daemon
    maxconn       50000

defaults
    log      global
    mode     http
    option   httplog
    option   dontlognull
    option   forwardfor          # add X-Forwarded-For
    option   http-server-close   # close connection after each request (efficiency)
    timeout  connect  5s
    timeout  client   30s
    timeout  server   30s

# ── Stats page (internal monitoring) ─────────────────────────────────────────
frontend stats
    bind  *:8404
    stats enable
    stats uri     /haproxy?stats
    stats refresh 10s
    stats auth    admin:changeme

# ── HTTPS frontend ────────────────────────────────────────────────────────────
frontend https_in
    bind  *:443 ssl crt /etc/haproxy/certs/example.com.pem  alpn h2,http/1.1

    # Redirect HTTP to HTTPS
    http-request redirect scheme https unless { ssl_fc }

    # Route by Host header
    use_backend  api_backend    if { hdr(host) -i api.example.com }
    use_backend  www_backend    if { hdr(host) -i example.com }
    default_backend  www_backend

# ── Backend: API ──────────────────────────────────────────────────────────────
backend api_backend
    balance     leastconn
    option      httpchk GET /health    # active health check path

    http-check  expect status 200

    server  api1  app1.internal:3000  check  inter 5s  fall 3  rise 2
    server  api2  app2.internal:3000  check  inter 5s  fall 3  rise 2
    server  api3  app3.internal:3000  check  inter 5s  fall 3  rise 2  backup

# ── Backend: WWW ──────────────────────────────────────────────────────────────
backend www_backend
    balance     roundrobin
    option      httpchk GET /health

    server  web1  web1.internal:80  check
    server  web2  web2.internal:80  check
```

---

## 🔍 Debugging Proxy Issues

```bash
# Check what your backend receives (use httpbin to inspect headers)
curl -s http://httpbin.org/headers | jq .headers

# Trace a request through proxy (verbose)
curl -vI https://api.example.com/health 2>&1 | grep -E "^[<>*]"

# Check upstream response time
curl -o /dev/null -s -w \
  "Connect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" \
  https://api.example.com/api/status

# Verify X-Forwarded-For is passed correctly
curl -s https://api.example.com/api/debug | jq .headers

# Watch Nginx upstream errors live
tail -f /var/log/nginx/error.log | grep "upstream"

# Test HAProxy backend health
echo "show servers state backend_name" | socat stdio /run/haproxy/admin.sock
```