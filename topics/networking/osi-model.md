# 🗼 OSI Model

> The OSI (Open Systems Interconnection) model is a conceptual framework that describes how data moves from an application on one machine to an application on another. It exists to give engineers a common language for diagnosing problems: "is this a Layer 3 routing issue or a Layer 7 application issue?" Real networking uses TCP/IP which collapses some layers, but the OSI vocabulary is universal.

---

## The 7 Layers

```
Sender                                              Receiver
──────────────────────────────────────────────────────────────
Application (7)  │ HTTP, DNS, SMTP, SSH, FTP        │ Application (7)
Presentation (6) │ TLS/SSL, compression, encoding   │ Presentation (6)
Session (5)      │ session management, RPC          │ Session (5)
Transport (4)    │ TCP segments, UDP datagrams      │ Transport (4)
Network (3)      │ IP packets, routing              │ Network (3)
Data Link (2)    │ Ethernet frames, MAC addresses   │ Data Link (2)
Physical (1)     │ bits → electrical/optical/radio  │ Physical (1)
──────────────────────────────────────────────────────────────
                 NETWORK (cables, switches, routers)
```

Data travels **down** the layers on the sender (each layer wraps the data with its header) and **up** the layers on the receiver (each layer unwraps). This wrapping is called **encapsulation**.

```
Application data:  "GET /users HTTP/1.1\r\nHost: api.example.com\r\n\r\n"
        ↓ Transport adds:   [TCP header: src port 54321, dst port 443, seq#]
        ↓ Network adds:     [IP header: src 10.0.0.5, dst 93.184.216.34]
        ↓ Data Link adds:   [Ethernet frame: src MAC aa:bb, dst MAC cc:dd]
        ↓ Physical:         01001010 01001000... (bits on wire/radio)
```

---

## Layer 1 — Physical

**What it does:** Transmits raw bits (0s and 1s) over a physical medium.

**Not about meaning — only about signal.**

| Medium | Technology | Speed |
|--------|-----------|-------|
| Copper cable | Ethernet (Cat5e/Cat6) | 1–10 Gbps |
| Fibre optic | Single/multi-mode fibre | 10Gbps – 400Gbps |
| Wireless | Wi-Fi (802.11ax), 5G | 1–10+ Gbps |
| Coax | Cable Internet (DOCSIS) | ~1 Gbps |

**Key concepts:**
- **Bit**: single 0 or 1 encoded as voltage level, light pulse, or radio wave
- **Bandwidth**: maximum data rate of the medium (e.g. 1 Gbps Ethernet)
- **Latency**: time for a signal to travel from A to B (speed of light in medium)
- **MTU** (Maximum Transmission Unit): max bytes per frame — Ethernet = 1500 bytes

**Relevant when:** You see CRC errors, collisions, physical link down, "no carrier" on `ip link`.

```bash
ethtool eth0                   # check physical link speed, duplex, auto-negotiation
ip link show eth0              # state: UP / DOWN / NO-CARRIER
cat /proc/net/dev              # RX/TX errors, dropped, overruns
```

---

## Layer 2 — Data Link

**What it does:** Transfers frames between directly connected nodes (same network segment). Handles MAC addressing, error detection, and media access control.

**Scope: local network only (one hop).**

| Protocol | Used for |
|----------|---------|
| Ethernet (802.3) | Wired LAN |
| Wi-Fi (802.11) | Wireless LAN |
| PPP | Point-to-point serial links |
| VLAN (802.1Q) | Virtual LAN tagging |

**Key concepts:**
- **MAC address**: 48-bit hardware address burned into NIC (`aa:bb:cc:dd:ee:ff`). Unique per NIC, used for local delivery.
- **Frame**: L2 PDU = [dst MAC | src MAC | EtherType | payload | FCS]
- **Switch**: L2 device — forwards frames based on MAC address table
- **ARP** (Address Resolution Protocol): resolves IP → MAC on local network
- **Broadcast domain**: all devices that receive each other's broadcasts (same VLAN)

```bash
# ARP table: IP → MAC mappings learned by this host
arp -n                          # show ARP cache
ip neigh show                   # modern equivalent
ip neigh show dev eth0          # for specific interface

# Send a gratuitous ARP (announce your IP+MAC to update others' ARP caches)
arping -I eth0 192.168.1.100

# View VLAN tags on an interface
ip -d link show eth0.100        # tagged sub-interface

# Sniff L2 frames
tcpdump -i eth0 -e              # -e shows MAC addresses
tcpdump -i eth0 arp             # only ARP frames
```

**Common problems at this layer:**
- ARP spoofing / ARP poisoning (attacker claims to own IP)
- Duplicate MAC address (two devices with same MAC)
- Incorrect VLAN tagging
- Switch port misconfigured (access vs trunk mode)

---

## Layer 3 — Network

**What it does:** Routes packets across multiple networks (hops). Responsible for logical addressing and path selection.

**Scope: global (across all networks, including the internet).**

| Protocol | Purpose |
|----------|---------|
| IPv4 | 32-bit addresses, most internet traffic |
| IPv6 | 128-bit addresses, growing adoption |
| ICMP | Control messages (ping, traceroute, "port unreachable") |
| OSPF / BGP | Routing protocols (how routers share route tables) |

**Key concepts:**
- **IP address**: logical address assigned to an interface. IPv4: `93.184.216.34`. IPv6: `2001:db8::1`
- **Subnet**: group of IPs sharing a network prefix (`192.168.1.0/24` = 256 addresses)
- **Packet**: L3 PDU = [IP header: src IP, dst IP, TTL, protocol | payload]
- **Router**: L3 device — forwards packets based on IP routing table
- **TTL** (Time to Live): decremented by 1 at each hop; packet dropped at 0 (prevents loops)
- **Fragmentation**: if packet > MTU, split into fragments and reassemble at destination

```bash
# View routing table
ip route show

# Trace the route (uses TTL trick: send packets with TTL=1,2,3... each hop responds with ICMP time-exceeded)
traceroute 8.8.8.8
mtr 8.8.8.8              # live version with packet loss per hop

# Ping (ICMP echo request / echo reply)
ping 8.8.8.8 -c 4
ping6 2001:4860:4860::8888    # IPv6 ping

# Check if IP forwarding is enabled (required for routing/NAT)
cat /proc/sys/net/ipv4/ip_forward   # 1 = enabled

# View ARP / neighbour table (IP → MAC resolution)
ip neigh

# Capture ICMP packets
tcpdump -i eth0 icmp
```

**Subnetting quick reference:**

| CIDR | Mask | Hosts | Common use |
|------|------|-------|-----------|
| /32 | 255.255.255.255 | 1 | Single host (loopback, VPN endpoint) |
| /30 | 255.255.255.252 | 2 | Point-to-point links |
| /29 | 255.255.255.248 | 6 | Small subnet |
| /28 | 255.255.255.240 | 14 | Small subnet |
| /24 | 255.255.255.0 | 254 | Office LAN, container subnet |
| /16 | 255.255.0.0 | 65,534 | Large network |
| /8  | 255.0.0.0 | 16,777,214 | Very large network |

**Private IP ranges (RFC 1918 — not routable on the internet):**
- `10.0.0.0/8` — large private networks (Kubernetes pod networks, VPCs)
- `172.16.0.0/12` — Docker default bridge (`172.17.0.0/16`)
- `192.168.0.0/16` — home/office LANs

---

## Layer 4 — Transport

**What it does:** Provides end-to-end communication between processes. Adds ports (so multiple applications on one IP can communicate simultaneously), and either reliable delivery (TCP) or fast delivery (UDP).

| | TCP | UDP |
|--|-----|-----|
| Connection | Yes (3-way handshake) | No (connectionless) |
| Reliability | Guaranteed delivery, ordered, error-checked | Best-effort, no ordering |
| Speed | Slower (overhead) | Faster |
| Use case | HTTP, SSH, databases | DNS, video streaming, games, VoIP |

**Key concepts:**
- **Port**: 16-bit number (0–65535) identifying a service. `<IP>:<port>` = a socket.
- **Segment** (TCP) / **Datagram** (UDP): L4 PDU
- **TCP 3-way handshake**: SYN → SYN-ACK → ACK (establishes connection, ~1 RTT)
- **TCP flow control**: receiver advertises window size; sender slows down if buffer is full
- **TCP congestion control**: CUBIC/BBR algorithms that back off when packet loss detected

```
TCP 3-way handshake:

Client                          Server
  │                               │
  │────── SYN, seq=1000 ─────────►│  Client: "I want to connect, my starting seq is 1000"
  │                               │
  │◄───── SYN-ACK, seq=5000 ──────│  Server: "OK, my seq is 5000, ack your 1001"
  │       ack=1001                │
  │                               │
  │────── ACK, ack=5001 ─────────►│  Client: "Got it, ack your 5001. Connection open."
  │                               │
  │════════════════════════════════│  Data flows (ESTABLISHED)
```

```bash
# View TCP connections and listening ports
ss -tlnp                    # listening TCP
ss -tnp state established   # established connections
ss -s                        # summary by state

# Watch connection states
watch -n1 'ss -s'

# Test TCP handshake
nc -zv example.com 443      # "Connection to example.com 443 port [tcp/https] succeeded!"

# Common well-known ports:
# 22    SSH
# 25    SMTP
# 53    DNS (UDP + TCP)
# 80    HTTP
# 443   HTTPS
# 3306  MySQL
# 5432  PostgreSQL
# 6379  Redis
# 27017 MongoDB
```

---

## Layer 5 — Session

**What it does:** Manages sessions between applications — establishing, maintaining, and terminating communication sessions. In practice, mostly absorbed into Layer 4 (TCP) or Layer 7.

**Real-world examples:**
- **TLS/SSL session resumption**: reusing a previously negotiated TLS session (avoids full handshake overhead)
- **RPC** (Remote Procedure Call): gRPC session management
- **SQL database sessions**: connection pooling in PostgreSQL, MySQL
- **WebSockets**: persistent full-duplex connection over HTTP

---

## Layer 6 — Presentation

**What it does:** Translates data between network format and application format. Handles encoding, encryption, and compression.

**Real-world examples:**
- **TLS/SSL** encryption/decryption (often placed here conceptually)
- **Character encoding**: UTF-8, ASCII
- **Serialisation formats**: JSON, protobuf, MessagePack
- **MIME types**: `Content-Type: application/json`, `image/png`
- **Compression**: gzip, brotli in HTTP

---

## Layer 7 — Application

**What it does:** Provides the interface between the network and the application. This is where protocols like HTTP, DNS, and SSH operate.

| Protocol | Port | Purpose |
|----------|------|---------|
| HTTP | 80 | Web (unencrypted) |
| HTTPS | 443 | Web over TLS |
| DNS | 53 (UDP/TCP) | Name resolution |
| SSH | 22 | Secure remote shell |
| SMTP | 25, 587 | Email sending |
| IMAP | 143, 993 | Email retrieval |
| FTP | 21 | File transfer (legacy) |
| SFTP | 22 | File transfer over SSH |
| NTP | 123 (UDP) | Time synchronisation |
| gRPC | 443 | RPC over HTTP/2 |
| MQTT | 1883, 8883 | IoT messaging |

---

## TCP/IP vs OSI

In practice, TCP/IP (the protocol suite that runs the internet) maps to 4 layers, not 7:

```
TCP/IP Model          OSI Model (approximate mapping)
─────────────         ────────────────────────────────
Application     ←→   Application (7) + Presentation (6) + Session (5)
Transport       ←→   Transport (4)
Internet        ←→   Network (3)
Network Access  ←→   Data Link (2) + Physical (1)
```

---

## Diagnosing Problems by Layer

| Symptom | Layer | Tool | Check |
|---------|-------|------|-------|
| No physical link | L1 | `ip link show`, `ethtool` | Cable, NIC, speed/duplex |
| Can't reach gateway | L2 | `arp -n`, `tcpdump arp` | ARP resolution, VLAN config |
| Can ping IP but not hostname | L3+DNS | `dig`, `ping IP directly` | DNS config, /etc/resolv.conf |
| Ping works, HTTP doesn't | L4 | `nc -zv host 80`, `ss -tlnp` | Port open, firewall, service listening |
| TLS handshake fails | L6 | `openssl s_client` | Certificate, cipher, expiry |
| HTTP 5xx errors | L7 | `curl -v`, app logs | Application error, backend down |

```bash
# Layered diagnostic:
# L1: ip link show eth0         (is the interface up? any errors?)
# L2: ping <gateway>            (can you reach the default gateway?)
# L3: traceroute <remote-ip>    (can you route to the destination?)
# L4: nc -zv <host> <port>      (is the port open and reachable?)
# L7: curl -v https://<host>    (does the application respond correctly?)
```