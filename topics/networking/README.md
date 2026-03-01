# 🌐 Networking

<p align="center">
  <img src="https://img.shields.io/badge/HTTP-005C97?style=for-the-badge&logo=http&logoColor=white"/>
  <img src="https://img.shields.io/badge/DNS-1572B6?style=for-the-badge&logoColor=white"/>
  <img src="https://img.shields.io/badge/SSH-4D4D4D?style=for-the-badge&logo=openssh&logoColor=white"/>
  <img src="https://img.shields.io/badge/OSI_Model-FF6B35?style=for-the-badge&logoColor=white"/>
  <img src="https://img.shields.io/badge/TCP/IP-00758F?style=for-the-badge&logoColor=white"/>
</p>

> Networking is the invisible plumbing of everything in DevOps. Every HTTP request, every `git push`, every Kubernetes pod-to-pod call, every database query — all of it is networking. You don't need to be a network engineer, but you do need to understand the protocols well enough to diagnose failures and design reliable systems.

---

## 💡 How a Request Travels

```
Browser types: https://api.example.com/users

1. DNS resolution
   OS checks /etc/hosts → cache → resolv.conf → UDP :53 to 8.8.8.8
   8.8.8.8 → root → .com NS → example.com NS → 93.184.216.34

2. TCP connection (OSI Layer 4)
   Client: SYN →
   Server: ← SYN-ACK
   Client: ACK →         (3-way handshake complete, 1 RTT)

3. TLS handshake (OSI Layer 6)
   Client Hello → Server Hello + Certificate → Key Exchange → Finished
   (1–2 RTTs, then symmetric encryption for the session)

4. HTTP/2 request (OSI Layer 7)
   GET /users HTTP/2
   Host: api.example.com
   Authorization: Bearer eyJ...

5. Response
   HTTP/2 200 OK
   Content-Type: application/json
   [response body]

6. TCP teardown
   FIN → FIN-ACK → ACK (or connection kept alive for reuse)
```

---

## 📋 Files in This Topic

| File | What you'll learn |
|------|-------------------|
| [osi-model.md](./osi-model.md) | The 7 layers from physical bits to applications — with real protocol examples at each layer |
| [dns.md](./dns.md) | How names become IPs — recursive resolution, record types, TTL, DoH, troubleshooting |
| [http.md](./http.md) | HTTP/1.1 through HTTP/3, methods, status codes, headers, TLS, REST patterns |
| [ssh.md](./ssh.md) | Key-based auth, config, tunnels, port forwarding, agent forwarding, hardening |

---

## 🗺️ Learning Path

```
1. osi-model.md   ← understand the layers before anything else
        ↓
2. dns.md         ← how names are resolved before any connection
        ↓
3. http.md        ← the protocol that runs the web and APIs
        ↓
4. ssh.md         ← secure remote access, the daily tool of every engineer
```

---

## ⚡ Quick Reference

```bash
# ── DNS ───────────────────────────────────────────────────────────────────────
dig +short api.example.com           # what IP does this resolve to?
dig +trace api.example.com           # full delegation chain from root
dig -x 93.184.216.34                 # reverse: IP → hostname

# ── HTTP ──────────────────────────────────────────────────────────────────────
curl -I https://api.example.com      # just response headers
curl -w "%{http_code} %{time_total}s\n" -o /dev/null -s https://api.example.com
openssl s_client -connect api.example.com:443  # inspect TLS certificate

# ── SSH ───────────────────────────────────────────────────────────────────────
ssh-keygen -t ed25519 -C "my-key"    # generate key pair
ssh-copy-id user@host                # copy public key to server
ssh -L 5432:db:5432 jumphost         # local port forward through jump host
ssh -D 1080 user@host                # SOCKS5 proxy through SSH

# ── General diagnostics ───────────────────────────────────────────────────────
ss -tlnp                             # what's listening on which ports
traceroute api.example.com           # trace path (find where it breaks)
nc -zv api.example.com 443           # is port 443 reachable?
mtr api.example.com                  # live traceroute with packet loss
```

---

## 🔗 Related Topics

- [Linux](../linux/) — `ip`, `ss`, `tcpdump`, `/etc/hosts`, `/etc/resolv.conf`
- [Server Management](../server-management/) — Nginx, reverse proxy, TLS termination
- [Containers](../containers/) — Docker bridge networks, port mapping, DNS in containers
- [Orchestration](../orchestration/) — Kubernetes Services, Ingress, CoreDNS, CNI plugins
- [DevSecOps](../devsecops/) — TLS hardening, certificate management, network policies