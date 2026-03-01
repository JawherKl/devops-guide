# 🖥️ Virtualization

> Virtualization is the technology that lets one physical machine run many isolated workloads. Understanding the difference between virtual machines and containers — and how both are implemented at the kernel level — is essential for every DevOps engineer. Containers are not a separate technology from Linux; they *are* Linux kernel features.

---

## Virtual Machines vs Containers

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Physical Server                              │
│                                                                     │
│  ┌───────────────────────────────┐   ┌──────────────────────────┐   │
│  │    Virtual Machine            │   │    Container Runtime     │   │
│  │ ┌──────┐ ┌──────┐ ┌──────┐    │   │                          │   │
│  │ │Guest │ │Guest │ │Guest │    │   │ ┌─────┐ ┌─────┐ ┌─────┐  │   │
│  │ │ OS   │ │ OS   │ │ OS   │    │   │ │app  │ │app  │ │app  │  │   │
│  │ │+libs │ │+libs │ │+libs │    │   │ │+libs│ │+libs│ │+libs│  │   │
│  │ └──────┘ └──────┘ └──────┘    │   │ └─────┘ └─────┘ └─────┘  │   │
│  │       Hypervisor (KVM/ESXi)   │   │     Container Runtime    │   │
│  └───────────────────────────────┘   │     (Docker/containerd)  │   │
│                                      └──────────────────────────┘   │
│                Host OS + Linux Kernel                               │
│                Hardware                                             │
└─────────────────────────────────────────────────────────────────────┘
```

| | Virtual Machine | Container |
|--|-----------------|-----------|
| **Isolation** | Full OS isolation (separate kernel) | Process-level (shared kernel) |
| **Boot time** | 30s – 2min | Milliseconds |
| **Size** | GB (includes full OS) | MB (includes only app + libs) |
| **Overhead** | High (runs full OS + hypervisor) | Near-zero (no guest OS) |
| **Security** | Strong (separate kernel per VM) | Weaker (shared kernel, breakout possible) |
| **Portability** | Platform-dependent (VMware, KVM, Hyper-V) | High (any Docker/OCI host) |
| **Use case** | Multi-tenant clouds, legacy OS, full isolation | Microservices, CI/CD, dev environments |

---

## Hypervisors — Type 1 vs Type 2

```
Type 1 (Bare-metal)                  Type 2 (Hosted)
────────────────────                  ───────────────────────
VM1  VM2  VM3                         App1  App2
 │    │    │                           │     │
Hypervisor                            VirtualBox / VMware Workstation
    │                                       │
Hardware                              Host OS (macOS, Windows, Linux)
                                           │
                                      Hardware
```

| Type 1 (Bare-metal) | Type 2 (Hosted) |
|---------------------|-----------------|
| Runs directly on hardware | Runs on top of a host OS |
| KVM (Linux), VMware ESXi, Xen, Hyper-V | VirtualBox, VMware Workstation, QEMU |
| Production workloads, cloud providers | Development, testing, desktop |
| Highest performance | Easier to set up |

**KVM** (Kernel-based Virtual Machine) is special: it's part of the Linux kernel itself. On Linux, the kernel is the hypervisor — this is why Linux is both the most common VM host and the foundation of every container.

---

## KVM / QEMU — Linux Virtualization

```bash
# ── Check KVM support ──────────────────────────────────────────────────────
# CPU must support hardware virtualization
grep -E 'vmx|svm' /proc/cpuinfo | head -1
# vmx = Intel VT-x, svm = AMD-V
# No output = virtualization not supported or disabled in BIOS

lsmod | grep kvm                 # check if KVM modules are loaded
# kvm_intel  or  kvm_amd  must appear

# ── Install KVM + QEMU + libvirt ───────────────────────────────────────────
# Ubuntu / Debian:
apt install -y qemu-kvm libvirt-daemon-system virt-manager virtinst

# Start and enable libvirt:
systemctl enable --now libvirtd
usermod -aG libvirt $USER        # add your user to libvirt group
newgrp libvirt                   # apply group change without re-login

# ── Manage VMs with virsh ──────────────────────────────────────────────────
virsh list --all                 # all VMs (running and stopped)
virsh start ubuntu-server        # start a VM
virsh shutdown ubuntu-server     # graceful shutdown (sends ACPI signal)
virsh destroy ubuntu-server      # force stop (like pulling the power)
virsh suspend ubuntu-server      # pause (save CPU state to RAM)
virsh resume ubuntu-server       # resume paused VM
virsh reboot ubuntu-server       # reboot
virsh dominfo ubuntu-server      # info: CPUs, memory, state
virsh domstats ubuntu-server     # detailed stats
virsh console ubuntu-server      # attach to serial console (Ctrl+] to exit)

# ── Create a VM ────────────────────────────────────────────────────────────
virt-install \
  --name ubuntu-22.04 \
  --ram 2048 \                   # MB of RAM
  --vcpus 2 \                    # virtual CPUs
  --disk path=/var/lib/libvirt/images/ubuntu-22.04.qcow2,size=20 \
  --cdrom /tmp/ubuntu-22.04-server.iso \
  --os-variant ubuntu22.04 \
  --network bridge=virbr0 \      # use default NAT bridge
  --graphics none \              # no display (headless)
  --console pty,target_type=serial

# ── Snapshots ─────────────────────────────────────────────────────────────
virsh snapshot-create-as ubuntu-server snap1 "Before upgrade"
virsh snapshot-list ubuntu-server
virsh snapshot-revert ubuntu-server snap1
virsh snapshot-delete ubuntu-server snap1

# ── QEMU disk image management ────────────────────────────────────────────
qemu-img create -f qcow2 disk.qcow2 20G   # create 20GB sparse image
qemu-img info disk.qcow2                   # info: virtual size, actual disk usage
qemu-img convert -f raw -O qcow2 disk.raw disk.qcow2  # convert format
qemu-img snapshot -c snap1 disk.qcow2     # create snapshot inside image
qemu-img resize disk.qcow2 +10G           # expand image (then resize partition inside)
```

---

## Linux Namespaces — Container Isolation

Namespaces are the Linux kernel feature that makes containers possible. Each namespace gives a process its own isolated view of a system resource.

```
Without namespaces:                 With namespaces:
─────────────────────               ──────────────────────────────────────
All processes share:                Container A sees:  Container B sees:
  - PIDs 1,2,3,4,...                  PID 1 (nginx)      PID 1 (node)
  - hostname "host1"                  hostname "appA"    hostname "appB"
  - eth0 + 192.168.1.1                eth0 + 10.0.0.1    eth0 + 10.0.0.2
  - / filesystem                      / → container FS   / → container FS
  - UID 1000 = "alice"                UID 0 = "root"*    UID 0 = "root"*
                                    (* mapped to host UID 100000)
```

### The 7 Linux Namespaces

| Namespace | Flag | Isolates |
|-----------|------|---------|
| **pid** | `CLONE_NEWPID` | Process IDs — container has its own PID 1 |
| **net** | `CLONE_NEWNET` | Network interfaces, routes, iptables rules |
| **mnt** | `CLONE_NEWNS` | Filesystem mount points |
| **uts** | `CLONE_NEWUTS` | Hostname and NIS domain name |
| **ipc** | `CLONE_NEWIPC` | SysV IPC, POSIX message queues |
| **user** | `CLONE_NEWUSER` | User/group IDs (UID 0 in container ≠ UID 0 on host) |
| **cgroup** | `CLONE_NEWCGROUP` | View of cgroup hierarchy |

```bash
# ── View namespaces ────────────────────────────────────────────────────────
lsns                              # list all namespaces
lsns -t net                       # only network namespaces
lsns -t pid                       # only PID namespaces

# See which namespaces a process belongs to:
ls -la /proc/1234/ns/             # symlinks to namespace files
# lrwxrwxrwx net -> net:[4026531992]
# lrwxrwxrwx pid -> pid:[4026531836]
# Same number = same namespace. Different number = isolated.

# ── Run a command in a new namespace (unshare) ────────────────────────────
unshare --pid --fork --mount-proc /bin/sh   # new PID namespace + shell
# In this shell: ps aux shows only this shell (PID 1) and children

unshare --net /bin/sh             # new network namespace: no network interfaces
# ip addr → only lo (loopback)

unshare --uts /bin/sh             # new UTS namespace: change hostname in isolation
hostname new-isolated-host        # only visible inside this namespace

# ── Enter an existing namespace (nsenter) ─────────────────────────────────
# Enter a running container's namespaces without going through Docker:
CONTAINER_PID=$(docker inspect --format '{{.State.Pid}}' my-container)
nsenter -t $CONTAINER_PID --net --pid --mount /bin/sh

# Run a command in Docker container's network namespace from host:
nsenter -t $CONTAINER_PID --net -- ip addr   # see container's IPs
nsenter -t $CONTAINER_PID --net -- ss -tlnp  # container's listening ports

# ── Create and use a network namespace manually ───────────────────────────
ip netns add myns                            # create named network namespace
ip netns list                                # list named namespaces
ip netns exec myns ip addr                   # run command inside namespace
ip netns exec myns ping 8.8.8.8             # test (will fail — no route yet)

# Connect two network namespaces with a veth pair:
ip link add veth0 type veth peer name veth1  # create veth pair
ip link set veth1 netns myns                 # move one end into namespace
ip addr add 10.0.0.1/24 dev veth0           # assign IP to host end
ip netns exec myns ip addr add 10.0.0.2/24 dev veth1  # assign to namespace end
ip link set veth0 up
ip netns exec myns ip link set veth1 up
ping 10.0.0.2                               # ping across namespace boundary

# ── Delete ────────────────────────────────────────────────────────────────
ip netns delete myns
```

---

## cgroups — Container Resource Limits

**Control groups (cgroups)** limit, account for, and isolate the resource usage (CPU, memory, disk I/O, network) of process groups. This is how `docker run --memory 512m` works.

```
cgroup hierarchy (/sys/fs/cgroup/):
/
├── system.slice/              ← systemd services
│   ├── nginx.service/
│   └── postgresql.service/
├── user.slice/                ← user sessions
└── docker/                    ← Docker containers
    ├── <container-id-1>/
    │   ├── memory.limit_in_bytes   ← 512MB limit
    │   ├── memory.usage_in_bytes   ← current usage
    │   ├── cpu.cfs_quota_us        ← CPU quota
    │   └── cpu.cfs_period_us       ← CPU period
    └── <container-id-2>/
```

```bash
# ── cgroups v1 vs v2 ──────────────────────────────────────────────────────
# cgroups v2 (unified hierarchy) is the default on modern distros (Ubuntu 22+)
# cgroups v1 uses separate trees per resource type

# Check which version is active:
stat -f -c %T /sys/fs/cgroup   # "cgroup2fs" = v2, "tmpfs" = v1
ls /sys/fs/cgroup/             # v2: unified files; v1: separate dirs per resource

# ── Exploring cgroups v2 ──────────────────────────────────────────────────
ls /sys/fs/cgroup/
# cgroup.controllers    memory.stat    cpu.stat    ...

# See Docker container's cgroup:
docker inspect --format '{{.Id}}' my-container
ls /sys/fs/cgroup/system.slice/docker-<id>.scope/
cat /sys/fs/cgroup/system.slice/docker-<id>.scope/memory.current  # current usage
cat /sys/fs/cgroup/system.slice/docker-<id>.scope/memory.max      # limit

# ── Manually create and use a cgroup (v2) ────────────────────────────────
mkdir /sys/fs/cgroup/my_group               # create cgroup
echo "1234" > /sys/fs/cgroup/my_group/cgroup.procs  # add PID to group

# Set memory limit to 100MB:
echo "104857600" > /sys/fs/cgroup/my_group/memory.max

# Set CPU limit to 50% of one core:
# quota/period = fraction of CPU time
echo "50000 100000" > /sys/fs/cgroup/my_group/cpu.max
# 50000µs out of every 100000µs period = 50%

# Remove cgroup (must be empty — no processes):
rmdir /sys/fs/cgroup/my_group

# ── systemd-run: run a command with cgroup limits (practical) ─────────────
systemd-run --scope \
  -p MemoryMax=512M \
  -p CPUQuota=50% \
  -- node /app/server.js         # run Node.js limited to 512MB + 50% CPU

# ── cgroupspy: see which cgroup a process is in ───────────────────────────
cat /proc/1234/cgroup             # lists all cgroups the process belongs to
```

---

## Container Internals — What Docker Actually Does

When you run `docker run -it ubuntu bash`, Docker performs these kernel operations:

```bash
# Docker's simplified process (what happens under the hood):

# 1. Pull and prepare the image layers (overlayfs)
# 2. Create a new set of namespaces:
clone(CLONE_NEWPID | CLONE_NEWNET | CLONE_NEWNS | CLONE_NEWUTS | CLONE_NEWIPC | CLONE_NEWUSER)

# 3. Set up the container's filesystem (overlayfs):
#    Lower layers: read-only image layers
#    Upper layer:  writable container layer
mount -t overlay overlay \
  -o lowerdir=/var/lib/docker/overlay2/<hash>/diff,\
     upperdir=/var/lib/docker/overlay2/<container>/diff,\
     workdir=/var/lib/docker/overlay2/<container>/work \
  /var/lib/docker/overlay2/<container>/merged

# 4. Set up networking (veth pair):
ip link add veth0 type veth peer name eth0
ip link set eth0 netns <container-net-ns>
ip addr add 172.17.0.2/16 dev eth0  # inside container
# Bridge veth0 to docker0 on host

# 5. Apply cgroup limits:
mkdir /sys/fs/cgroup/docker/<container-id>
echo "536870912" > /sys/fs/cgroup/docker/<container-id>/memory.max  # 512MB
echo "50000 100000" > /sys/fs/cgroup/docker/<container-id>/cpu.max

# 6. Apply seccomp filter (block dangerous syscalls like ptrace, mount)
# 7. Apply AppArmor/SELinux profile (MAC policy)
# 8. Drop capabilities (by default: keep ~14 of 37, drop CAP_SYS_ADMIN etc.)

# 9. exec() the container process (bash in this case)
# → Container process sees: PID 1, its own eth0, its own /, hostname from --name
```

```bash
# Inspect a running container's namespaces from the host:
CPID=$(docker inspect --format '{{.State.Pid}}' my-container)
ls -la /proc/$CPID/ns/           # see the namespace links

# Compare host PID namespace vs container:
ls -la /proc/1/ns/pid            # host: pid:[4026531836]
ls -la /proc/$CPID/ns/pid        # container: pid:[4026532123]  (different!)

# See container's filesystem (the merged overlayfs):
docker inspect --format '{{.GraphDriver.Data.MergedDir}}' my-container
ls $(docker inspect --format '{{.GraphDriver.Data.MergedDir}}' my-container)

# Check container's cgroup limits:
CGROUP=$(docker inspect --format '{{.Id}}' my-container | head -c 12)
find /sys/fs/cgroup -name "*.scope" | grep $CGROUP | head -1
```

---

## seccomp — Syscall Filtering

Containers don't have an isolated kernel — they share the host kernel. seccomp (Secure Computing Mode) limits which system calls a container can make, reducing the attack surface.

```bash
# Docker's default seccomp profile blocks ~44 of ~300+ syscalls, including:
# - ptrace (process tracing/injection)
# - mount (mounting filesystems)
# - kexec_load (loading a new kernel)
# - create_module (loading kernel modules)

# Check if seccomp is active on a container:
docker inspect --format '{{.HostConfig.SecurityOpt}}' my-container

# Run without seccomp (for debugging — not production):
docker run --security-opt seccomp=unconfined ubuntu

# Apply a custom seccomp profile:
docker run --security-opt seccomp=/path/to/profile.json ubuntu

# Check syscalls a process uses (to build a minimal seccomp profile):
strace -c -f -e trace=all command 2>&1 | tail -20
```

---

## Capabilities — Fine-grained Privilege

Traditionally: root can do everything, non-root can't do privileged operations. Capabilities split root's power into ~37 distinct privileges that can be granted individually.

```bash
# Common capabilities:
# CAP_NET_BIND_SERVICE → bind to ports < 1024 (nginx on port 80 without root)
# CAP_SYS_ADMIN        → very broad: mount filesystems, set hostname, etc.
# CAP_SYS_PTRACE       → trace other processes (debuggers, profilers)
# CAP_NET_RAW          → raw network sockets (ping, tcpdump)
# CAP_CHOWN            → change file ownership
# CAP_KILL             → send signals to other users' processes

# View capabilities of a running process:
cat /proc/1234/status | grep Cap
# CapPrm: 00000000a80425fb   ← permitted capabilities (hex bitmask)
# CapEff: 00000000a80425fb   ← effective (currently active)
# CapBnd: 000000ffffffffff   ← bounding (ceiling — cannot gain more than this)

# Decode capabilities bitmask:
capsh --decode=00000000a80425fb

# Run a command with only specific capabilities:
capsh --caps="cap_net_bind_service+eip" --user=www-data -- -c "nginx"

# Docker: run with extra capability:
docker run --cap-add NET_ADMIN ubuntu    # add network admin capability
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE nginx  # minimal: only bind ports

# Give a binary a specific capability (instead of making it SUID):
setcap cap_net_bind_service+ep /usr/bin/node  # node can bind port 80 without root
getcap /usr/bin/node                           # verify

# Check what capabilities the current shell has:
capsh --print
```