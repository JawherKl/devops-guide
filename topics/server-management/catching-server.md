# ⚡ Caching Server

> A caching server stores copies of responses in fast memory (RAM) so that identical future requests can be answered immediately — without hitting the application or database. A well-tuned cache can reduce backend load by 80–95% and cut response times from hundreds of milliseconds to single-digit milliseconds.

---

## Where Caching Fits

```
Client
  │
  ▼
Browser Cache          ← Cache-Control headers tell browser how long to cache
  │
  ▼
CDN / Edge Cache       ← Cloudflare, CloudFront — caches at network edge
  │
  ▼
Varnish / Nginx Cache  ← Server-side reverse proxy cache — this file
  │
  ▼
Application Cache      ← Redis / Memcached — app-level key/value cache
  │
  ▼
Database Query Cache   ← PostgreSQL query plan cache, MySQL query cache
  │
  ▼
Database
```

---

## Cache-Control Headers — The Foundation

Before configuring any cache server, understand `Cache-Control` — the HTTP header that controls caching behaviour at every layer.

```
# Directives:
Cache-Control: max-age=3600          ← cache for 3600 seconds (1 hour)
Cache-Control: no-cache              ← must revalidate with server before using cached copy
Cache-Control: no-store              ← never cache (sensitive data: banking, auth)
Cache-Control: private               ← only browser can cache, not shared caches (CDN/Varnish)
Cache-Control: public                ← any cache may store this
Cache-Control: must-revalidate       ← when stale, must revalidate before serving
Cache-Control: stale-while-revalidate=60  ← serve stale for 60s while refreshing in background
Cache-Control: immutable             ← content will never change (hashed filenames)
```

### Nginx — Setting Cache-Control Headers for Static Assets

```nginx
server {
    # ── Immutable assets (hashed filenames: app.abc123.js) ───────────────────
    # max-age=31536000 = 1 year; immutable = browser won't revalidate
    location ~* \.(js|css|woff2|woff|ttf)$ {
        add_header Cache-Control "public, max-age=31536000, immutable";
        expires 1y;
    }

    # ── Images ────────────────────────────────────────────────────────────────
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)$ {
        add_header Cache-Control "public, max-age=2592000";   # 30 days
        expires 30d;
    }

    # ── HTML: always fresh ────────────────────────────────────────────────────
    location ~* \.html$ {
        add_header Cache-Control "no-cache";
        expires -1;
    }

    # ── API responses: short TTL, revalidate ─────────────────────────────────
    location /api/ {
        add_header Cache-Control "public, max-age=60, stale-while-revalidate=30";
        proxy_pass http://backend;
    }

    # ── User-specific data: never cache in shared caches ─────────────────────
    location /api/user/ {
        add_header Cache-Control "private, no-store";
        proxy_pass http://backend;
    }
}
```

---

## Varnish Cache

Varnish is a dedicated HTTP accelerator designed to sit in front of web servers. It stores full HTTP responses in RAM and serves them at memory speed. Configured with **VCL (Varnish Configuration Language)**.

### Installation

```bash
# Ubuntu/Debian
curl -s https://packagecloud.io/varnishcache/varnish75/gpgkey | apt-key add -
apt install varnish

# Default: Varnish listens on port 6081 (HTTP), backend on port 8080
# Nginx listens on 8080 (moved from 80), Varnish on 80

# /etc/varnish/varnish.params (Debian) or systemd override
# -a 0.0.0.0:80         ← Varnish listens on port 80
# -b 127.0.0.1:8080     ← backend (Nginx) on port 8080
# -s malloc,512m        ← 512MB RAM cache
```

### Nginx Port Change (when using Varnish in front)

```nginx
# Move Nginx from port 80 to 8080 — Varnish takes port 80
server {
    listen 8080;
    listen [::]:8080;
    server_name example.com;
    # ... rest of config unchanged
}
```

### Varnish Configuration (VCL)

```vcl
# /etc/varnish/default.vcl
vcl 4.1;

# ── Backend definition ────────────────────────────────────────────────────────
backend default {
    .host = "127.0.0.1";
    .port = "8080";                # Nginx backend

    # Active health check — Varnish probes the backend periodically
    .probe = {
        .url       = "/health";
        .timeout   = 2s;
        .interval  = 5s;           # probe every 5 seconds
        .window    = 5;            # track last 5 probes
        .threshold = 3;            # backend healthy if 3/5 probes pass
    }
}

# ── vcl_recv: called when a request is received ───────────────────────────────
# Decide whether to look up the cache or pass to backend.
sub vcl_recv {

    # ── Normalize the Host header ─────────────────────────────────────────────
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

    # ── Remove tracking query strings (prevent cache fragmentation) ───────────
    # These parameters don't change the response but create different cache keys
    if (req.url ~ "[?&](utm_source|utm_medium|utm_campaign|utm_content|fbclid|gclid)") {
        set req.url = regsuball(req.url,
            "[?&](utm_source|utm_medium|utm_campaign|utm_content|fbclid|gclid)=[^&]*",
            "");
        set req.url = regsub(req.url, "[?&]$", "");
    }

    # ── Only cache GET and HEAD requests ──────────────────────────────────────
    # POST/PUT/DELETE always pass to backend (they mutate state)
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # ── Don't cache authenticated requests ────────────────────────────────────
    if (req.http.Authorization) {
        return (pass);
    }

    # ── Don't cache requests with session cookies ─────────────────────────────
    # Remove harmless cookies (analytics), pass if session cookie present
    if (req.http.Cookie) {
        # Remove Google Analytics / tracking cookies
        set req.http.Cookie = regsuball(req.http.Cookie,
            "(^|; )(__(utm|ga|gads|gac|gid)|_fbp|_fbc)[^;]*", "");
        # Strip leading/trailing semicolons
        set req.http.Cookie = regsub(req.http.Cookie, "^; *", "");
        set req.http.Cookie = regsub(req.http.Cookie, ";? *$", "");

        # If any real session cookie remains, bypass the cache
        if (req.http.Cookie ~ "(sessionid|PHPSESSID|auth_token|remember_token)") {
            return (pass);
        }

        # Strip the now-empty cookie header entirely
        if (req.http.Cookie == "") {
            unset req.http.Cookie;
        }
    }

    # ── API endpoints: pass by default, cache only specific paths ─────────────
    if (req.url ~ "^/api/") {
        # Cache public product listings but not user-specific endpoints
        if (req.url ~ "^/api/products" || req.url ~ "^/api/categories") {
            return (hash);       # look up cache
        }
        return (pass);           # pass everything else
    }

    return (hash);               # look up cache for all other requests
}

# ── vcl_hash: define the cache key ───────────────────────────────────────────
sub vcl_hash {
    hash_data(req.url);
    hash_data(req.http.Host);

    # If the backend serves different content based on Accept-Encoding,
    # include it in the hash:
    # if (req.http.Accept-Encoding ~ "gzip") {
    #     hash_data("gzip");
    # }

    return (lookup);
}

# ── vcl_backend_response: called when backend returns a response ──────────────
# Decide TTL and whether to cache the response.
sub vcl_backend_response {

    # ── Set default TTL ────────────────────────────────────────────────────────
    # Grace: serve stale content for up to 24h while backend is down
    set beresp.grace = 24h;

    # ── Don't cache error responses ────────────────────────────────────────────
    if (beresp.status == 500 || beresp.status == 502 || beresp.status == 503) {
        set beresp.uncacheable = true;
        set beresp.ttl = 1s;        # keep briefly to avoid hammering sick backend
        return (deliver);
    }

    # ── Respect Cache-Control: no-store ───────────────────────────────────────
    if (beresp.http.Cache-Control ~ "no-store" || beresp.http.Cache-Control ~ "private") {
        set beresp.uncacheable = true;
        return (deliver);
    }

    # ── Override TTL for specific paths ───────────────────────────────────────
    if (bereq.url ~ "^/api/products") {
        set beresp.ttl = 5m;       # cache product listings for 5 minutes
    }

    if (bereq.url ~ "\.(js|css|woff2)$") {
        set beresp.ttl = 365d;      # immutable assets: 1 year
        unset beresp.http.Set-Cookie;
    }

    if (bereq.url ~ "\.(jpg|png|gif|ico|svg|webp)$") {
        set beresp.ttl = 30d;
        unset beresp.http.Set-Cookie;
    }

    # ── Strip Set-Cookie for cacheable responses ──────────────────────────────
    # Cookies prevent caching by default — remove them for public content
    if (beresp.ttl > 0s && beresp.http.Set-Cookie) {
        unset beresp.http.Set-Cookie;
    }

    return (deliver);
}

# ── vcl_deliver: called just before sending response to client ────────────────
sub vcl_deliver {
    # Add header showing cache hit/miss (useful for debugging)
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }

    # Remove internal Varnish headers from client response
    unset resp.http.Via;
    unset resp.http.X-Varnish;
    unset resp.http.Age;          # comment out to expose cache age

    return (deliver);
}
```

### Varnish Cache Purging

```bash
# Purge a specific URL (requires PURGE method to be allowed in VCL)
curl -X PURGE http://127.0.0.1/api/products

# VCL to allow PURGE from localhost:
# sub vcl_recv {
#     if (req.method == "PURGE") {
#         if (client.ip != "127.0.0.1") { return (synth(403)); }
#         return (purge);
#     }
# }

# Purge by pattern using ban (regex against cached objects)
varnishadm ban req.url ~ ^/api/products       # purge all /api/products* URLs
varnishadm ban req.url ~ ^/images/            # purge all images
varnishadm ban obj.http.Host == example.com   # purge entire site

# Inspect ban list
varnishadm ban.list

# Monitor cache in real time
varnishlog                     # live request stream (verbose)
varnishstat                    # running stats (hit rate, threads, memory)
varnishstat -1 -f MAIN.cache_hit -f MAIN.cache_miss   # just hit/miss counts

# Check hit rate (target: >80% for production)
varnishstat -1 | grep -E "cache_hit|cache_miss"
```

---

## Nginx proxy_cache (Built-in Caching)

If you don't want to run a separate Varnish process, Nginx has a built-in cache that covers most use cases.

```nginx
# /etc/nginx/conf.d/cache-zone.conf
# Must be defined OUTSIDE server blocks (in http context)

proxy_cache_path /var/cache/nginx/api
                 levels=1:2
                 keys_zone=api_cache:10m       # 10MB metadata (~80k entries)
                 max_size=2g                   # max disk space
                 inactive=30m                 # evict if unused for 30 min
                 use_temp_path=off;

proxy_cache_path /var/cache/nginx/static
                 levels=1:2
                 keys_zone=static_cache:10m
                 max_size=10g
                 inactive=7d
                 use_temp_path=off;
```

```nginx
# In your server block:
server {
    listen 443 ssl;
    server_name example.com;

    # ── Cache API responses ────────────────────────────────────────────────────
    location /api/products {
        proxy_pass         http://backend_pool;
        proxy_cache        api_cache;
        proxy_cache_key    "$scheme$host$request_uri";

        # Cache 200 and 301 for 5 minutes, 404 for 1 minute
        proxy_cache_valid  200 301  5m;
        proxy_cache_valid  404      1m;

        # Serve stale content while refreshing in background
        proxy_cache_use_stale          error timeout updating http_500 http_502 http_503;
        proxy_cache_background_update  on;
        proxy_cache_lock               on;      # only one request populates per key

        # Bypass cache for authenticated users
        proxy_cache_bypass  $http_authorization $cookie_sessionid;
        proxy_no_cache      $http_authorization $cookie_sessionid;

        # Add debug header
        add_header X-Cache-Status $upstream_cache_status;
    }

    # ── Cache static files ─────────────────────────────────────────────────────
    location ~* \.(js|css|png|jpg|svg|woff2)$ {
        proxy_pass         http://backend_pool;
        proxy_cache        static_cache;
        proxy_cache_valid  200  365d;
        proxy_cache_use_stale error timeout;
        add_header X-Cache-Status $upstream_cache_status;
    }

    # ── Purge endpoint (restrict to internal IPs) ─────────────────────────────
    location ~ /purge(/.*) {
        allow   127.0.0.1;
        allow   10.0.0.0/8;
        deny    all;
        proxy_cache_purge  api_cache "$scheme$host$1";
    }
}
```

---

## Redis — Application-Level Cache

Redis is an in-memory key-value store used by the application layer to cache database query results, sessions, computed values, and API responses.

```bash
# Install
apt install redis-server

# Configuration: /etc/redis/redis.conf
# Key settings:
bind 127.0.0.1          # only listen on loopback (never expose to internet)
maxmemory 512mb          # limit RAM usage
maxmemory-policy allkeys-lru   # evict least-recently-used keys when full
                                # other policies: allkeys-lfu, volatile-lru, noeviction
requirepass yourpassword  # always set a password
```

### Redis Usage Patterns

```bash
# ── CLI basics ────────────────────────────────────────────────────────────────
redis-cli -h 127.0.0.1 -p 6379 -a yourpassword

# ── Key-value with TTL ────────────────────────────────────────────────────────
SET  user:1234:profile  '{"name":"Alice","email":"alice@example.com"}'  EX 3600
GET  user:1234:profile
TTL  user:1234:profile     # remaining seconds; -2 = expired/gone; -1 = no TTL
DEL  user:1234:profile

# ── Check memory usage ────────────────────────────────────────────────────────
redis-cli INFO memory | grep used_memory_human
redis-cli INFO stats   | grep keyspace_hits
redis-cli INFO stats   | grep keyspace_misses

# ── Monitor live commands ──────────────────────────────────────────────────────
redis-cli MONITOR         # dangerous in production — logs every command

# ── Flush ─────────────────────────────────────────────────────────────────────
redis-cli FLUSHDB         # flush current database (dev only)
redis-cli FLUSHALL        # flush ALL databases (never in production)
```

### Application Cache Pattern (Node.js example)

```javascript
// cache.js — generic Redis cache wrapper
const redis = require('redis');
const client = redis.createClient({ url: 'redis://127.0.0.1:6379' });
client.connect();

// cache-aside pattern: check cache first, fall back to DB
async function getCachedOrFetch(key, ttlSeconds, fetchFn) {
    // 1. Try cache
    const cached = await client.get(key);
    if (cached) {
        return JSON.parse(cached);   // cache HIT
    }

    // 2. Cache miss — fetch from source (DB, API…)
    const data = await fetchFn();

    // 3. Write to cache with TTL
    await client.setEx(key, ttlSeconds, JSON.stringify(data));

    return data;
}

// Usage:
const products = await getCachedOrFetch(
    'products:all',            // cache key
    300,                       // TTL: 5 minutes
    () => db.query('SELECT * FROM products')  // fetch function
);

// Invalidate on write:
async function updateProduct(id, data) {
    await db.query('UPDATE products SET ...', [id, data]);
    await client.del('products:all');        // invalidate list cache
    await client.del(`products:${id}`);     // invalidate single-item cache
}
```

---

## 📊 Cache Hit Rate — What to Target

| Hit Rate | Status | Action |
|----------|--------|--------|
| > 90% | Excellent | Monitor, maintain |
| 70–90% | Good | Review cache TTLs |
| 50–70% | Fair | Review cache keys, check bypass conditions |
| < 50% | Poor | Investigate — too many unique keys, too many bypasses, wrong TTL |

```bash
# Varnish hit rate
varnishstat -1 | grep -E "cache_hit|cache_miss" | awk '{print $1, $2}'
# Calculate: hit_rate = cache_hit / (cache_hit + cache_miss) * 100

# Nginx cache status
awk '{print $NF}' /var/log/nginx/access.log | sort | uniq -c | sort -rn
# Looks for HIT / MISS / EXPIRED / BYPASS in the last field

# Redis hit rate
redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses"
# Calculate: hit_rate = keyspace_hits / (keyspace_hits + keyspace_misses) * 100
```

---

## ⚠️ Cache Invalidation Strategies

Cache invalidation is one of the hardest problems in computing. Here are the main patterns:

| Strategy | How | When to use |
|----------|-----|-------------|
| **TTL expiry** | Set `max-age` / `EX` on every key | Simple, works for most content |
| **Write-through** | Update cache on every write | Need real-time consistency |
| **Cache-aside** | App manages cache explicitly | Flexible, most common pattern |
| **Event-driven** | Invalidate via message queue on write | Microservices with shared cache |
| **Versioned keys** | `products:v2:all` — bump version on deploy | Full cache bust on release |
| **Surrogate keys** | Tag responses, purge by tag | CDNs (Cloudflare Cache Tag, Fastly) |

```bash
# Versioned key pattern — never need to delete, just bump the version
# Old:  products:v1:all
# New:  products:v2:all       ← old key expires naturally via TTL
# Application reads from v2, v1 becomes dead weight and expires
```