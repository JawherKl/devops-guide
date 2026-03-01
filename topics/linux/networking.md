# 🌐 Linux Networking

> Linux networking is controlled entirely through the kernel — interfaces, routes, firewall rules, and connections are all visible and configurable from the command line. This file covers the tools you'll use to configure, diagnose, and troubleshoot networking on any Linux server.

---

## Network Interfaces

```bash
# ── View interfaces ───────────────────────────────────────────────────────────
ip addr                          # all interfaces with IP addresses (modern)
ip addr show eth0                # specific interface
ip link show                     # layer-2 (MAC address, MTU, state)
ip -s link show eth0             # with statistics (bytes, packets, errors)

# Legacy (still works, but ip is preferred):
ifconfig                         # all interfaces
ifconfig eth0                    # specific interface

# Interface naming:
# eth0, eth1    — old predictable names (still used in VMs/containers)
# ens3, ens192  — Ethernet named by bus position
# enp3s0        — Ethernet: e=ethernet, n=network, p3=bus3, s0=slot0
# wlan0, wlp2s0 — wireless
# lo            — loopback (127.0.0.1 — always present, always up)
# docker0       — Docker bridge network
# veth*         — virtual Ethernet pairs (one end in container, one on host)

# ── Bring interfaces up/down ──────────────────────────────────────────────────
ip link set eth0 up
ip link set eth0 down

# ── Assign IP address ─────────────────────────────────────────────────────────
ip addr add 192.168.1.100/24 dev eth0     # temporary (gone on reboot)
ip addr del 192.168.1.100/24 dev eth0     # remove IP
```

### Persistent Network Config

```bash
# ── Ubuntu (Netplan, 18.04+) ──────────────────────────────────────────────────
# /etc/netplan/00-installer-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
        search: [example.com]

# Apply:
netplan apply

# ── RHEL / CentOS / Fedora (NetworkManager) ───────────────────────────────────
# /etc/NetworkManager/system-connections/eth0.nmconnection
[connection]
id=eth0
type=ethernet
interface-name=eth0

[ipv4]
method=manual
addresses=192.168.1.100/24
gateway=192.168.1.1
dns=8.8.8.8;8.8.4.4;

# Apply:
nmcli connection reload
nmcli connection up eth0

# ── Debian legacy (interfaces file) ──────────────────────────────────────────
# /etc/network/interfaces
auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
```

---

## Routing

```bash
# ── View routing table ────────────────────────────────────────────────────────
ip route                          # routing table (modern)
ip route show                     # same
route -n                          # legacy: numeric (no DNS lookup)
netstat -rn                       # legacy alternative

# Sample output:
# default via 192.168.1.1 dev eth0 proto dhcp     ← default gateway
# 192.168.1.0/24 dev eth0 proto kernel scope link ← directly connected network
# 10.0.0.0/8 via 10.10.0.1 dev eth1              ← static route to private network

# ── Add/remove routes ─────────────────────────────────────────────────────────
ip route add 10.0.0.0/8 via 10.10.0.1 dev eth1    # add route
ip route del 10.0.0.0/8                            # remove route
ip route add default via 192.168.1.1               # set default gateway

# ── Check which route a packet would take ─────────────────────────────────────
ip route get 8.8.8.8              # which interface/gateway would be used?
ip route get 10.5.0.1             # useful for debugging routing decisions

# ── Enable IP forwarding (for routers, VPNs, container hosts) ─────────────────
echo 1 > /proc/sys/net/ipv4/ip_forward         # temporary
sysctl -w net.ipv4.ip_forward=1               # temporary (same thing)
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-forward.conf  # persistent
sysctl --system                               # apply sysctl.d files
```

---

## DNS Resolution

```bash
# ── /etc/hosts: local static resolution (checked BEFORE DNS) ─────────────────
# /etc/hosts
127.0.0.1       localhost
127.0.1.1       my-hostname
192.168.1.50    db.internal db
192.168.1.60    redis.internal redis
10.0.0.1        k8s-master.cluster.local

# Great for: local dev environments, overriding DNS in /etc/hosts

# ── /etc/resolv.conf: DNS server config ───────────────────────────────────────
# /etc/resolv.conf
nameserver 8.8.8.8          # primary DNS server
nameserver 8.8.4.4          # fallback DNS server
search example.com          # append this to bare hostnames: "db" → "db.example.com"
domain example.com          # single domain (alternative to search)
options ndots:5             # use search list if < 5 dots in name

# On Ubuntu, /etc/resolv.conf is managed by systemd-resolved — it's a symlink
# Edit /etc/systemd/resolved.conf instead, or use netplan DNS settings

# ── /etc/nsswitch.conf: resolution order ──────────────────────────────────────
# /etc/nsswitch.conf (relevant line):
hosts: files dns               # check /etc/hosts FIRST, then DNS
# Other options: mdns4_minimal (Avahi/mDNS), resolve (systemd-resolved)

# ── DNS lookup tools ──────────────────────────────────────────────────────────
# dig: most detailed, shows full DNS response
dig example.com                    # A record lookup (IPv4)
dig example.com AAAA               # IPv6 lookup
dig example.com MX                 # mail server records
dig example.com NS                 # nameserver records
dig example.com TXT                # text records (SPF, DKIM, verification)
dig @8.8.8.8 example.com           # query specific DNS server
dig +short example.com             # just the IP(s), no detail
dig +trace example.com             # trace full delegation chain from root
dig -x 93.184.216.34               # reverse lookup: IP → hostname (PTR record)

# nslookup: simpler, interactive or one-shot
nslookup example.com               # basic lookup
nslookup example.com 8.8.8.8       # use specific DNS server
nslookup -type=MX example.com      # MX records

# host: simplest
host example.com                   # IP address
host -t MX example.com             # MX records
host 93.184.216.34                  # reverse lookup

# systemd-resolved
resolvectl status                  # DNS config and stats per interface
resolvectl query example.com       # resolve using systemd-resolved
resolvectl flush-caches            # flush DNS cache
```

---

## Ports & Connections

```bash
# ── ss: socket statistics (modern replacement for netstat) ────────────────────
ss -tlnp                     # TCP Listening sockets with process name + PID
ss -ulnp                     # UDP Listening sockets
ss -tnp                      # established TCP connections with process
ss -s                        # summary statistics (total sockets by state)
ss -tlnp | grep :443         # who is listening on port 443?

# ── netstat (legacy, still available) ────────────────────────────────────────
netstat -tlnp                # TCP listening
netstat -an                  # all sockets (numeric)
netstat -s                   # statistics

# ── lsof: list open files (including network sockets) ────────────────────────
lsof -i                      # all network connections
lsof -i :80                  # connections on port 80
lsof -i :80 -i :443          # ports 80 AND 443
lsof -i TCP:1-1024           # all privileged ports
lsof -p 1234                 # all open files for PID 1234
lsof -u www-data             # all open files by www-data user

# ── Connection states ─────────────────────────────────────────────────────────
# LISTEN      ← waiting for incoming connections
# ESTABLISHED ← active connection
# TIME_WAIT   ← waiting after connection close (prevents old packets confusing new connections)
# CLOSE_WAIT  ← remote closed, waiting for local app to close
# SYN_SENT    ← sent SYN, waiting for SYN-ACK (connecting)

# Count connections in each state (useful for diagnosing overload):
ss -s
# or:
ss -tn | awk 'NR>1 {print $1}' | sort | uniq -c | sort -rn
```

---

## Network Diagnostics

```bash
# ── ping: test reachability and round-trip time ────────────────────────────────
ping 8.8.8.8                 # continuous ping (Ctrl+C to stop)
ping -c 4 8.8.8.8            # exactly 4 packets
ping -i 0.2 8.8.8.8          # 0.2s interval (faster)
ping -M do -s 1400 8.8.8.8   # test MTU: send 1400-byte packet with DF bit set

# ── traceroute: show each hop to destination ──────────────────────────────────
traceroute 8.8.8.8            # UDP probes (default)
traceroute -T 8.8.8.8         # TCP probes (less likely to be blocked by firewalls)
traceroute -I 8.8.8.8         # ICMP probes
mtr 8.8.8.8                   # live traceroute + packet loss per hop (apt install mtr)
mtr --report 8.8.8.8          # one-shot report

# ── curl: HTTP testing ────────────────────────────────────────────────────────
curl https://example.com                            # GET request
curl -I https://example.com                        # HEAD: headers only
curl -v https://example.com                        # verbose: show full conversation
curl -o /dev/null -s -w "%{http_code}\n" https://example.com  # just status code
curl -o /dev/null -s -w "DNS: %{time_namelookup}s\nConnect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" https://example.com
curl -X POST -H "Content-Type: application/json" \
     -d '{"key":"value"}' https://api.example.com  # POST JSON
curl -b "sessionid=abc123" https://example.com     # send cookie
curl --insecure https://self-signed.example.com    # ignore TLS errors
curl -L https://example.com                        # follow redirects
curl --resolve example.com:443:93.184.216.34 https://example.com  # force IP (bypass DNS)

# ── netcat (nc): raw TCP/UDP connections ──────────────────────────────────────
nc -zv example.com 443          # test TCP port reachability
nc -zv example.com 80 443 8080  # test multiple ports
nc -l 4444                       # listen on port 4444 (simple server)
echo "hello" | nc example.com 9000  # send data to a port
nc -u -l 5005                    # listen on UDP port

# ── tcpdump: capture packets ──────────────────────────────────────────────────
tcpdump -i eth0                           # all traffic on eth0
tcpdump -i any                            # all interfaces
tcpdump -i eth0 port 80                   # only HTTP traffic
tcpdump -i eth0 host 192.168.1.50         # traffic to/from specific host
tcpdump -i eth0 'tcp and port 443'        # HTTPS traffic
tcpdump -i eth0 -w capture.pcap           # save to file for Wireshark analysis
tcpdump -i eth0 -r capture.pcap           # read saved capture
tcpdump -i eth0 'not port 22'             # exclude SSH (avoid capturing your own terminal)
tcpdump -i eth0 -n -A port 80             # ASCII output (readable HTTP)

# ── nmap: port scanning ───────────────────────────────────────────────────────
nmap localhost                            # quick scan of common ports
nmap -p 1-65535 192.168.1.100            # full port range
nmap -sV 192.168.1.100                   # detect service versions
nmap -O 192.168.1.100                    # detect OS
nmap -p 22,80,443 192.168.1.0/24        # scan subnet for specific ports
# Note: only scan networks you own — nmap scans can look like attacks
```

---

## Network Performance

```bash
# ── Bandwidth and throughput ──────────────────────────────────────────────────
iperf3 -s                            # start iperf3 server (on target machine)
iperf3 -c 192.168.1.100              # run client against server
iperf3 -c 192.168.1.100 -t 30 -P 4  # 30s test, 4 parallel streams
iperf3 -c 192.168.1.100 -u -b 100M  # UDP test at 100Mbps

# ── Interface statistics ──────────────────────────────────────────────────────
watch -n 1 "cat /proc/net/dev"        # raw counters, updated every second
iftop -i eth0                         # live bandwidth by connection (apt install iftop)
nethogs eth0                          # bandwidth per process (apt install nethogs)
nload eth0                            # real-time throughput graph

# ── Check for packet loss / errors ───────────────────────────────────────────
ip -s link show eth0                  # RX/TX bytes, packets, errors, dropped
# Look for non-zero: errors, dropped, overruns → possible hardware or driver issue
ethtool eth0                          # NIC speed, duplex, auto-negotiation
ethtool -S eth0                       # detailed NIC counters
```

---

## Hostname & Name Resolution

```bash
# View and set hostname
hostname                             # current hostname
hostnamectl                          # full hostname info
hostnamectl set-hostname new-name    # set hostname persistently
hostnamectl set-hostname new-name --static  # static hostname (survives reboots)

# Test full DNS resolution chain
systemd-resolve --status             # DNS config summary
systemd-resolve example.com          # resolve (same as host/dig)
systemd-resolve --flush-caches       # clear DNS cache

# Test /etc/hosts override
getent hosts example.com             # use system resolution (hosts + DNS)
getent hosts 8.8.8.8                 # reverse lookup through system resolver
```

---

## Practical Troubleshooting Workflow

```bash
# Problem: "I can't reach http://api.example.com from this server"

# Step 1: Can I ping the IP?
ping -c 3 api.example.com
# → "ping: api.example.com: Temporary failure in name resolution" → DNS issue
# → "Request timeout" → routing or firewall issue
# → Response → network is up, problem is at app layer

# Step 2: Is DNS working?
dig api.example.com +short
cat /etc/resolv.conf
resolvectl status

# Step 3: Can I reach the port?
nc -zv api.example.com 80
curl -v http://api.example.com

# Step 4: Is the route correct?
ip route get <resolved-ip>
traceroute api.example.com

# Step 5: Is a local firewall blocking it?
iptables -L OUTPUT -n
iptables -L -n | grep REJECT

# Step 6: Is something listening locally on the same port?
ss -tlnp | grep :80

# Step 7: Capture the actual traffic
tcpdump -i any -n host api.example.com
```