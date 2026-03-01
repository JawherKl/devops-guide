# 🌍 HTTP

> HTTP (HyperText Transfer Protocol) is the foundation of data communication on the web — and the backbone of almost every API, microservice, and web application. Understanding it deeply means you can diagnose failures faster, design better APIs, configure servers correctly, and understand what your frameworks are doing under the hood.

---

## HTTP Versions — The Evolution

| Version | Year | Key change |
|---------|------|-----------|
| HTTP/0.9 | 1991 | GET only, no headers |
| HTTP/1.0 | 1996 | Headers, status codes, multiple methods |
| HTTP/1.1 | 1997 | Persistent connections, chunked transfer, Host header |
| HTTP/2 | 2015 | Multiplexing, header compression, server push, binary |
| HTTP/3 | 2022 | QUIC (UDP-based), 0-RTT, connection migration |

### HTTP/1.1 — One request per connection (by default)

```
Client                                  Server
  │── GET /home HTTP/1.1 ──────────────►│
  │   Host: example.com                 │
  │                                     │
  │◄── HTTP/1.1 200 OK ─────────────────│
  │    Content-Type: text/html          │
  │    [body: HTML]                     │
  │                                     │
  │── GET /style.css HTTP/1.1 ─────────►│  (new request on SAME connection)
  │── GET /app.js HTTP/1.1 ────────────►│  (pipelined, but problematic)
```

**Problems with HTTP/1.1:**
- **Head-of-line blocking**: if request 1 is slow, requests 2, 3, 4… wait
- **Workaround**: browsers open 6 parallel TCP connections per domain
- **Header overhead**: headers are text, repeated in every request (Cookies, User-Agent...)

### HTTP/2 — Multiplexing over one connection

```
Client                                  Server
  │                                     │
  │══ Single TCP connection ════════════│
  │   Stream 1: GET /home              │
  │   Stream 3: GET /style.css         │  ← all concurrent on ONE connection
  │   Stream 5: GET /app.js            │
  │                                     │
  │◄══ Responses interleaved ══════════│
  │   Stream 1: 200 OK (HTML)          │
  │   Stream 5: 200 OK (JS)            │  ← can arrive out of order
  │   Stream 3: 200 OK (CSS)           │
```

**HTTP/2 key features:**
- **Multiplexing**: many requests/responses over one TCP connection, no head-of-line blocking
- **HPACK header compression**: repeated headers compressed (e.g. Cookie header sent once)
- **Binary framing**: more efficient parsing than text
- **Server push**: server can proactively send resources the client will need
- **Stream prioritisation**: important resources delivered first

### HTTP/3 — QUIC (UDP-based)

HTTP/3 replaces TCP with **QUIC** (Quick UDP Internet Connections), developed by Google.

```
HTTP/1.1 + HTTP/2:              HTTP/3:
TCP (reliable, ordered)          QUIC over UDP (reliable per-stream)
TLS (layer 5-6)                  TLS 1.3 built into QUIC
Multiple RTTs to connect         0-RTT or 1-RTT connection

Problem: TCP head-of-line blocking still affects HTTP/2
(one lost TCP segment blocks ALL streams)

QUIC fix: packet loss on stream 3 doesn't block stream 1 and 5
```

```bash
# Check HTTP version used:
curl -I --http2 https://example.com 2>&1 | head -1    # HTTP/2
curl -I --http3 https://example.com 2>&1 | head -1    # HTTP/3 (curl 7.66+)
curl -w "%{http_version}\n" -o /dev/null -s https://example.com

# Check if a server supports HTTP/2:
curl -vI https://example.com 2>&1 | grep "^< "
# < HTTP/2 200  ← server responded with HTTP/2

# Check if Nginx is serving HTTP/2:
nginx -T 2>&1 | grep "http2"
# http2 on;  ← good
```

---

## HTTP Request Anatomy

```
GET /api/users?page=2&limit=20 HTTP/1.1
Host: api.example.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
Accept-Encoding: gzip, deflate, br
Accept-Language: en-US,en;q=0.9
Content-Type: application/json
User-Agent: Mozilla/5.0 (compatible; MyApp/1.0)
Cache-Control: no-cache
Connection: keep-alive
X-Request-ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890

{"filter": "active"}       ← request body (for POST/PUT/PATCH)
```

**Request line:** `METHOD /path?query HTTP/version`

---

## HTTP Methods

| Method | Idempotent | Safe | Cacheable | Body | Use |
|--------|-----------|------|-----------|------|-----|
| **GET** | Yes | Yes | Yes | No | Retrieve resource |
| **POST** | No | No | No | Yes | Create resource |
| **PUT** | Yes | No | No | Yes | Replace entire resource |
| **PATCH** | No | No | No | Yes | Partial update |
| **DELETE** | Yes | No | No | No | Delete resource |
| **HEAD** | Yes | Yes | Yes | No | GET without body (check existence/headers) |
| **OPTIONS** | Yes | Yes | No | No | CORS preflight, list allowed methods |

**Idempotent**: calling it N times has the same effect as calling it once.  
**Safe**: doesn't modify server state.

```bash
curl -X GET    https://api.example.com/users/123
curl -X POST   https://api.example.com/users -d '{"name":"Alice"}'
curl -X PUT    https://api.example.com/users/123 -d '{"name":"Alice","email":"a@b.com"}'
curl -X PATCH  https://api.example.com/users/123 -d '{"email":"new@b.com"}'
curl -X DELETE https://api.example.com/users/123
curl -X HEAD   https://api.example.com/users/123    # check if 200/404 without body
curl -X OPTIONS https://api.example.com/users -I    # see allowed methods + CORS headers
```

---

## HTTP Response Anatomy

```
HTTP/2 200 OK
Content-Type: application/json; charset=utf-8
Content-Length: 342
Content-Encoding: gzip
Cache-Control: public, max-age=300, stale-while-revalidate=60
ETag: "abc123def456"
Last-Modified: Wed, 21 Jan 2026 07:28:00 GMT
X-Request-ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1706854800
Strict-Transport-Security: max-age=63072000; includeSubDomains
Vary: Accept-Encoding, Authorization
Date: Sat, 21 Jan 2026 07:28:10 GMT

{"users": [...]}       ← response body
```

---

## HTTP Status Codes

### 1xx — Informational
| Code | Meaning |
|------|---------|
| `100 Continue` | Server ready to receive request body |
| `101 Switching Protocols` | WebSocket upgrade accepted |

### 2xx — Success
| Code | Meaning | When to use |
|------|---------|------------|
| `200 OK` | Request succeeded | GET, PUT, PATCH success |
| `201 Created` | Resource created | POST success with new resource |
| `202 Accepted` | Request accepted, processing async | Background jobs |
| `204 No Content` | Success, no body | DELETE, PUT success with no response body |
| `206 Partial Content` | Range request fulfilled | File streaming, resumable downloads |

### 3xx — Redirection
| Code | Meaning | Cache? |
|------|---------|--------|
| `301 Moved Permanently` | Permanent redirect | Yes |
| `302 Found` | Temporary redirect | No |
| `304 Not Modified` | Resource unchanged (use your cache) | N/A |
| `307 Temporary Redirect` | Temp redirect, preserve method | No |
| `308 Permanent Redirect` | Perm redirect, preserve method | Yes |

> **301 vs 308**: Both are permanent, but 301 allows changing POST→GET on redirect. 308 preserves the method. Use 308 for API redirects.

### 4xx — Client Errors
| Code | Meaning | Common cause |
|------|---------|-------------|
| `400 Bad Request` | Malformed request | Invalid JSON, missing field |
| `401 Unauthorized` | Not authenticated | Missing or invalid token |
| `403 Forbidden` | Authenticated but not authorised | Insufficient permissions |
| `404 Not Found` | Resource doesn't exist | Wrong URL, deleted resource |
| `405 Method Not Allowed` | Wrong HTTP method | POST to a GET-only endpoint |
| `409 Conflict` | Resource state conflict | Duplicate create, optimistic lock |
| `410 Gone` | Resource permanently deleted | Explicitly gone (unlike 404) |
| `422 Unprocessable Entity` | Valid syntax, invalid semantics | Validation failure |
| `429 Too Many Requests` | Rate limit exceeded | Include `Retry-After` header |

### 5xx — Server Errors
| Code | Meaning | Common cause |
|------|---------|-------------|
| `500 Internal Server Error` | Unhandled exception | Bug in app code |
| `501 Not Implemented` | Method not supported | Feature not built yet |
| `502 Bad Gateway` | Upstream returned invalid response | Backend crashed |
| `503 Service Unavailable` | Server can't handle requests | Overloaded, deploying |
| `504 Gateway Timeout` | Upstream took too long | Backend too slow |

---

## HTTP Headers — The Important Ones

### Request Headers

```http
Authorization: Bearer <token>           ← authentication token (JWT, OAuth)
Authorization: Basic dXNlcjpwYXNz       ← Basic auth: base64(user:pass)
Content-Type: application/json          ← format of the request body
Accept: application/json                ← formats the client understands
Accept-Encoding: gzip, br               ← compression the client accepts
Cache-Control: no-cache                 ← don't serve from cache
If-None-Match: "abc123"                 ← conditional GET (ETag)
If-Modified-Since: Wed, 21 Jan 2026    ← conditional GET (date)
X-Request-ID: uuid                      ← distributed tracing (correlation ID)
Cookie: sessionid=abc; csrf=xyz         ← session cookie
```

### Response Headers

```http
Content-Type: application/json          ← format of the response body
Content-Encoding: gzip                  ← compression applied to body
Content-Length: 342                     ← body size in bytes
ETag: "abc123def456"                    ← fingerprint for cache validation
Last-Modified: Wed, 21 Jan 2026        ← last modified date
Cache-Control: public, max-age=3600    ← caching instructions
Vary: Accept-Encoding, Authorization   ← which request headers affect the response
Location: /api/users/123               ← where to find the created resource (201)
Retry-After: 60                        ← seconds to wait before retrying (429, 503)
WWW-Authenticate: Bearer realm="api"  ← how to authenticate (401)
X-RateLimit-Limit: 100                 ← requests allowed per window
X-RateLimit-Remaining: 95             ← requests left in current window
X-RateLimit-Reset: 1706854800         ← UNIX timestamp when window resets
Strict-Transport-Security: max-age=63072000  ← HSTS: use HTTPS only
```

---

## TLS / HTTPS

Every HTTP connection in production should use TLS. TLS provides confidentiality (encryption), integrity (tamper detection), and authentication (you're talking to the real server).

```
TLS 1.3 Handshake (1-RTT):

Client                              Server
  │── ClientHello ─────────────────►│   (supported ciphers, key share)
  │   (key_share: X25519)           │
  │◄── ServerHello ─────────────────│   (chosen cipher, key share)
  │    Certificate                  │   (server's cert chain)
  │    CertificateVerify            │   (proof cert matches private key)
  │    Finished ────────────────────│
  │── Finished ────────────────────►│
  │                                  │
  │═══════════════════════════════════   Encrypted application data
```

```bash
# Inspect a TLS certificate:
openssl s_client -connect api.example.com:443 -servername api.example.com < /dev/null
openssl s_client -connect api.example.com:443 < /dev/null 2>/dev/null \
  | openssl x509 -noout -text | grep -E "Subject:|Issuer:|Not (Before|After)"

# Check certificate expiry:
echo | openssl s_client -connect api.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates
# notBefore=Jan  1 00:00:00 2025 GMT
# notAfter=Jan   1 00:00:00 2026 GMT   ← expired!

# Test which TLS versions and ciphers are supported:
nmap --script ssl-enum-ciphers -p 443 api.example.com

# Verify certificate chain:
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt cert.pem

# Test with specific TLS version:
curl --tls-max 1.2 https://api.example.com    # force TLS 1.2
curl --tls-max 1.3 https://api.example.com    # require TLS 1.3

# Check HSTS header:
curl -I https://api.example.com | grep Strict-Transport-Security
# Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```

---

## Caching

HTTP has a rich caching model. Getting it right dramatically reduces latency and load.

```http
# Immutable static assets (hashed filenames: app.abc123.js):
Cache-Control: public, max-age=31536000, immutable
# max-age=31536000 = 1 year; immutable = browser will never revalidate

# API responses with short TTL:
Cache-Control: public, max-age=60, stale-while-revalidate=30
# Serve cached for 60s; between 60–90s serve stale while refreshing in background

# Private user data (never cache in CDN/proxy):
Cache-Control: private, no-store
# private = browser-only; no-store = don't cache at all

# Conditional caching with ETag:
# Server sends: ETag: "abc123"
# Client sends: If-None-Match: "abc123"
# Server: 304 Not Modified (if unchanged) or 200 + new content (if changed)

# Conditional caching with date:
# Server sends: Last-Modified: Wed, 21 Jan 2026 07:28:00 GMT
# Client sends: If-Modified-Since: Wed, 21 Jan 2026 07:28:00 GMT
# Server: 304 or 200
```

```bash
# Test caching behaviour:
curl -I https://api.example.com/products          # note ETag value
curl -I https://api.example.com/products \
  -H "If-None-Match: \"abc123\""                  # should get 304

# See X-Cache header (CDN / Varnish hit/miss):
curl -I https://api.example.com/products | grep -i "x-cache\|age\|cache"
# X-Cache: HIT
# Age: 243   ← seconds this response has been in cache
```

---

## CORS — Cross-Origin Resource Sharing

CORS is a browser security mechanism that controls which origins can make requests to your API from JavaScript.

```bash
# ── CORS preflight (OPTIONS) ──────────────────────────────────────────────────
# Before a cross-origin POST/PUT/PATCH, the browser sends OPTIONS:
curl -X OPTIONS https://api.example.com/users \
  -H "Origin: https://app.example.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Authorization, Content-Type" \
  -I

# Expected response:
# Access-Control-Allow-Origin: https://app.example.com
# Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
# Access-Control-Allow-Headers: Authorization, Content-Type
# Access-Control-Max-Age: 3600       ← cache preflight for 1 hour
# Access-Control-Allow-Credentials: true  ← if cookies/auth headers needed
```

```nginx
# Nginx CORS config:
location /api/ {
    # Allow specific origin (never use * with credentials):
    if ($http_origin ~* "^https://(app|staging)\.example\.com$") {
        add_header Access-Control-Allow-Origin "$http_origin" always;
        add_header Access-Control-Allow-Credentials "true" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Authorization, Content-Type, X-Request-ID" always;
        add_header Access-Control-Max-Age 3600 always;
    }

    # Handle preflight:
    if ($request_method = OPTIONS) {
        return 204;
    }

    proxy_pass http://backend;
}
```

---

## REST API Design

```bash
# ── URL structure: resources, not actions ─────────────────────────────────────
# ✅ Good (resource-oriented):
GET    /api/v1/users              # list users
POST   /api/v1/users              # create user
GET    /api/v1/users/123          # get user 123
PUT    /api/v1/users/123          # replace user 123
PATCH  /api/v1/users/123          # partial update user 123
DELETE /api/v1/users/123          # delete user 123
GET    /api/v1/users/123/orders   # user 123's orders (nested resource)

# ❌ Bad (action-oriented):
POST /api/getUser
POST /api/createUser
POST /api/deleteUser/123
GET  /api/user?action=delete&id=123

# ── Versioning ────────────────────────────────────────────────────────────────
GET /api/v1/users          # URL versioning (most common, highly visible)
GET /api/users             # with header: Accept: application/vnd.myapp.v1+json

# ── Pagination ────────────────────────────────────────────────────────────────
GET /api/v1/users?page=2&per_page=20      # page-based
GET /api/v1/users?cursor=abc123&limit=20  # cursor-based (better for large datasets)
GET /api/v1/users?offset=40&limit=20      # offset-based

# Response with pagination metadata:
{
  "data": [...],
  "pagination": {
    "total": 1523,
    "page": 2,
    "per_page": 20,
    "next_cursor": "def456"
  }
}

# ── Consistent error responses ────────────────────────────────────────────────
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {"field": "email", "message": "must be a valid email address"},
      {"field": "age", "message": "must be between 18 and 120"}
    ],
    "request_id": "a1b2c3d4-e5f6-7890"
  }
}
```

---

## Debugging HTTP with curl

```bash
# ── The ultimate debug command ─────────────────────────────────────────────────
curl -v https://api.example.com/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice"}' \
  2>&1 | less
# Lines starting with > = sent by client
# Lines starting with < = received from server
# Lines starting with * = curl info (DNS, TLS, etc.)

# ── Timing breakdown ──────────────────────────────────────────────────────────
curl -w "\nDNS:       %{time_namelookup}s\nConnect:   %{time_connect}s\nTLS:       %{time_appconnect}s\nTTFB:      %{time_starttransfer}s\nTotal:     %{time_total}s\nSize:      %{size_download} bytes\nStatus:    %{http_code}\n" \
  -o /dev/null -s https://api.example.com
# DNS:     0.003s  ← if high, DNS is slow
# Connect: 0.021s  ← TCP handshake (latency)
# TLS:     0.041s  ← TLS handshake (certificate download + key exchange)
# TTFB:    0.156s  ← time to first byte (server processing time)
# Total:   0.162s  ← full response

# ── Follow redirects ──────────────────────────────────────────────────────────
curl -L https://example.com                    # follow redirects
curl -L -v https://example.com 2>&1 | grep "< HTTP\|Location:"  # trace redirects

# ── Test with different clients / bypass DNS ──────────────────────────────────
curl --resolve api.example.com:443:93.184.216.34 https://api.example.com  # specific IP
curl --insecure https://self-signed.example.com   # ignore TLS errors (testing only)

# ── Save and replay ───────────────────────────────────────────────────────────
curl -c cookies.txt -b cookies.txt https://api.example.com/login  # save/send cookies
curl -D headers.txt https://api.example.com  # save response headers to file
```