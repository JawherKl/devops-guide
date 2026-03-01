# 🐧 Linux

<p align="center">
  <img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white"/>
  <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white"/>
  <img src="https://img.shields.io/badge/POSIX-003366?style=for-the-badge&logoColor=white"/>
</p>

> Linux is the operating system that runs the internet. Every container, every Kubernetes node, every cloud VM, every CI runner is Linux. Understanding it is not optional for a DevOps engineer — it's the foundation everything else is built on.

---

## 💡 Linux in the DevOps Stack

```
Your Application
        │
        ▼
Container Runtime (Docker / containerd)
        │
        ▼
Linux Kernel
  ├── Namespaces      ← isolation between containers
  ├── cgroups         ← CPU/memory limits per container
  ├── iptables/nft    ← network routing and firewall
  ├── overlayfs       ← container image layering
  └── seccomp/apparmor ← syscall filtering (security)
        │
        ▼
Hardware (CPU, RAM, Disk, Network)
```

Containers are not magic — they are Linux kernel features. When you run `docker run`, Docker asks the kernel to create namespaces and cgroups. Understanding Linux means understanding how containers actually work.

---

## 📋 Files in This Topic

| File | What you'll learn |
|------|-------------------|
| [shell-commands.md](./shell-commands.md) | Navigation, file ops, text processing, process management, permissions — the 50 commands every engineer needs |
| [file-system.md](./file-system.md) | FHS layout, inodes, permissions, links, mounts, disk management, `/proc` and `/sys` |
| [networking.md](./networking.md) | Network interfaces, routing, DNS resolution, `ss`/`netstat`, firewall, troubleshooting |
| [posix.md](./posix.md) | Shell scripting standards, signals, exit codes, process model, pipes and redirection |
| [virtualization.md](./virtualization.md) | VMs vs containers, KVM/QEMU, namespaces, cgroups — how isolation actually works |

---

## 🗺️ Learning Path

```
1. shell-commands.md    ← navigate and operate the system
        ↓
2. file-system.md       ← understand how storage is organised
        ↓
3. networking.md        ← diagnose and configure network
        ↓
4. posix.md             ← write portable scripts, understand the process model
        ↓
5. virtualization.md    ← understand VMs and containers at the kernel level
```

---

## ⚡ Quick Reference

```bash
# ── Navigate ──────────────────────────────────────────────────────────────
pwd && ls -lah               # where am I, what's here
cd -                         # jump to previous directory

# ── Files ─────────────────────────────────────────────────────────────────
find / -name "*.conf" -type f 2>/dev/null   # find config files
grep -r "error" /var/log/ --include="*.log" # search log files

# ── Processes ─────────────────────────────────────────────────────────────
ps aux | grep nginx          # is nginx running?
top -b -n 1 | head -20       # snapshot of CPU/mem usage
kill -9 $(lsof -ti :3000)    # kill whatever is using port 3000

# ── Disk ──────────────────────────────────────────────────────────────────
df -h                        # disk space by filesystem
du -sh /var/log/*            # what's taking up space in /var/log
lsblk                        # list block devices

# ── Network ───────────────────────────────────────────────────────────────
ss -tlnp                     # listening TCP sockets + which process
ip addr show                 # IP addresses on all interfaces
curl -I https://example.com  # HTTP headers from a URL
```

---

## 🔗 Related Topics

- [Networking](../networking/) — DNS, HTTP, SSH, OSI model — protocol-level knowledge
- [Server Management](../server-management/) — Nginx, firewall, caching on top of Linux
- [Containers](../containers/) — Docker uses Linux kernel features (namespaces, cgroups)
- [DevSecOps](../devsecops/) — Linux hardening, AppArmor, SELinux, audit logs