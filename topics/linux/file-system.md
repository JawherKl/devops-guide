# 📁 File System

> The Linux file system is a unified hierarchy — everything is a file. Disks, processes, network sockets, devices — all exposed as files under `/`. Understanding this tree, how storage is attached to it, and how permissions work at the inode level is fundamental to diagnosing almost any Linux problem.

---

## The Filesystem Hierarchy Standard (FHS)

```
/                       ← root of the entire filesystem
├── bin  → usr/bin      ← essential user binaries (ls, cp, bash)
├── sbin → usr/sbin     ← essential system binaries (mount, fdisk, iptables)
├── usr/                ← user programs and data (most installed software)
│   ├── bin/            ← user commands (nginx, python, node)
│   ├── sbin/           ← system commands (useradd, sshd)
│   ├── lib/            ← shared libraries
│   ├── local/          ← locally installed software (not from package manager)
│   └── share/          ← architecture-independent data (man pages, icons)
│
├── etc/                ← ALL system configuration files (text files)
│   ├── nginx/          ← nginx config
│   ├── ssh/            ← SSH server config
│   ├── systemd/        ← systemd unit files
│   ├── passwd          ← user accounts
│   ├── shadow          ← password hashes (root only)
│   ├── hosts           ← local DNS overrides
│   └── fstab           ← filesystem mount table (auto-mount on boot)
│
├── var/                ← variable data: changes at runtime
│   ├── log/            ← log files (nginx, syslog, auth.log)
│   ├── lib/            ← persistent app state (databases, package lists)
│   ├── cache/          ← cached data (apt cache, pip wheels)
│   ├── tmp/            ← temp files that persist across reboots
│   └── www/            ← web server document roots
│
├── tmp/                ← temporary files (CLEARED on boot)
├── home/               ← user home directories (/home/alice, /home/bob)
├── root/               ← root user's home directory
├── opt/                ← optional/third-party software (not from package manager)
├── srv/                ← data served by the system (web, FTP)
│
├── proc/               ← virtual: running processes and kernel info (in RAM)
├── sys/                ← virtual: kernel and hardware parameters (in RAM)
├── dev/                ← device files (disks, terminals, null, random)
│   ├── sda             ← first SATA/SCSI disk
│   ├── nvme0n1         ← first NVMe disk
│   ├── null            ← discard all writes, return EOF on reads
│   ├── zero            ← returns infinite null bytes
│   └── random          ← cryptographically secure random bytes
│
├── boot/               ← kernel image, initrd, bootloader (GRUB)
├── lib → usr/lib       ← shared libraries (symlink)
└── run/                ← runtime data (PIDs, sockets) — cleared on boot
    ├── nginx.pid       ← nginx process ID file
    └── docker.sock     ← Docker Unix socket
```

---

## Inodes — The Real Identity of a File

Every file and directory is represented by an **inode** — a data structure in the filesystem that stores all metadata EXCEPT the filename and the actual data.

```
Filename (in directory)
    │
    └──► Inode #48291
           ├── file type (regular file, directory, symlink, device...)
           ├── permissions (mode bits + special bits)
           ├── owner UID
           ├── group GID
           ├── size in bytes
           ├── timestamps (atime, mtime, ctime)
           ├── link count (number of hard links pointing here)
           └── pointers to data blocks on disk
```

```bash
# View inode number
ls -i file.txt                   # inode number as first column
stat file.txt                    # full inode info + all timestamps

# Understanding stat timestamps:
#   Access time (atime)  — last time file data was READ
#   Modify time (mtime)  — last time file DATA was changed
#   Change time (ctime)  — last time file METADATA was changed (chmod, chown)

# Count inodes used (running out of inodes = no more files possible, even if disk has space)
df -i                            # inode usage per filesystem
df -i /                          # inode usage of root filesystem
```

---

## Hard Links vs Symbolic Links

```bash
# ── Hard link: another name pointing to the SAME inode ───────────────────────
ln source.txt hardlink.txt
# Both names share the same inode. The file "exists" as long as link count > 0.
# Deleting source.txt does NOT delete data — hardlink.txt still works.
# Limitation: cannot cross filesystems, cannot link directories.

ls -li source.txt hardlink.txt   # same inode number, link count = 2

# ── Symbolic link (symlink): a pointer to a PATH ──────────────────────────────
ln -s /etc/nginx/nginx.conf nginx.conf    # relative or absolute path
ln -s /usr/local/bin/python3.11 /usr/local/bin/python3   # version alias
ls -la nginx.conf                         # shows: nginx.conf -> /etc/nginx/nginx.conf

# Key difference:
# Hard link: points to inode — survives target deletion (data preserved)
# Symlink:   points to path  — breaks if target is deleted (dangling symlink)

# Find broken (dangling) symlinks
find /usr/local -xtype l             # -xtype l = symlink whose target doesn't exist
find . -type l -! -e                 # alternative syntax
```

---

## Filesystem Types

| Filesystem | Best for | Notes |
|-----------|----------|-------|
| **ext4** | General Linux use | Default on Ubuntu/Debian, journaled |
| **xfs** | Large files, high throughput | Default on RHEL/CentOS, good for databases |
| **btrfs** | Snapshots, subvolumes | Copy-on-write, built-in RAID |
| **tmpfs** | `/tmp`, `/run` | Lives entirely in RAM |
| **overlayfs** | Container layers | How Docker images stack |
| **nfs** | Network file shares | Remote filesystem over TCP/UDP |
| **ext2** | USB drives (no journal) | Faster for removable media |

```bash
# Check filesystem type of a mount
df -Th                           # -T shows filesystem type
lsblk -f                         # filesystem type + UUID + mount point
mount | grep "^/"                # all mounted filesystems

# Format a disk/partition
mkfs.ext4 /dev/sdb1              # format as ext4
mkfs.xfs /dev/sdb1               # format as xfs
mkfs.tmpfs                       # n/a — tmpfs is always in-memory

# Check filesystem for errors (run on unmounted filesystem)
fsck -n /dev/sdb1                # dry-run check (n = don't repair)
e2fsck -f /dev/sdb1              # force ext4 check
xfs_repair /dev/sdb1             # repair xfs
```

---

## Mounting & /etc/fstab

```bash
# ── Manual mounting ───────────────────────────────────────────────────────────
mount /dev/sdb1 /mnt/data            # mount device to directory
mount -t ext4 /dev/sdb1 /mnt/data   # specify filesystem type
mount -o ro /dev/sdb1 /mnt/data     # read-only mount
mount -o remount,rw /                # remount root read-write (recovery)

# Mount a disk image
mount -o loop disk.img /mnt/         # loop device: file as if it were a disk

# tmpfs: RAM disk
mount -t tmpfs -o size=512m tmpfs /mnt/ramdisk

# ── Unmounting ────────────────────────────────────────────────────────────────
umount /mnt/data                     # unmount by mount point
umount /dev/sdb1                     # unmount by device
umount -l /mnt/data                  # lazy: detach immediately, clean up later
lsof /mnt/data                       # check what has files open (if umount fails)

# ── /etc/fstab: permanent mounts (survive reboot) ─────────────────────────────
# Format: <device>  <mountpoint>  <fstype>  <options>  <dump>  <pass>

# /etc/fstab entries:
UUID=a1b2c3d4-...  /              ext4   errors=remount-ro  0  1
UUID=e5f6a7b8-...  /boot          ext4   defaults           0  2
UUID=c9d0e1f2-...  /home          ext4   defaults           0  2
UUID=d3e4f5a6-...  swap           swap   sw                 0  0

# Additional data disk:
UUID=b7c8d9e0-...  /mnt/data      xfs    defaults,noatime   0  2
# noatime: don't update access time on reads (reduces disk I/O)

# NFS share:
192.168.1.10:/exports/shared  /mnt/nfs  nfs  defaults,_netdev  0  0
# _netdev: wait for network before mounting (important for remote filesystems)

# tmpfs:
tmpfs  /tmp  tmpfs  defaults,size=2g,noexec,nosuid  0  0
# noexec: can't execute files from /tmp (security hardening)
# nosuid: ignore SUID bits (security hardening)

# Apply fstab without rebooting
mount -a                             # mount everything in fstab not yet mounted
systemctl daemon-reload              # reload systemd's view of fstab
```

---

## Disk Partitioning & LVM

```bash
# ── View disk layout ──────────────────────────────────────────────────────────
lsblk                            # tree view of block devices
lsblk -f                         # with filesystem and UUID
fdisk -l                         # detailed partition table (requires root)
parted -l                        # alternative to fdisk
blkid                            # UUIDs and filesystem types

# ── Partition a disk (fdisk, interactive) ─────────────────────────────────────
fdisk /dev/sdb
# Commands inside fdisk:
# p = print current table
# n = new partition
# d = delete partition
# t = change partition type (83=Linux, 82=swap, 8e=LVM)
# w = write changes and exit
# q = quit without saving

# ── LVM (Logical Volume Manager) ─────────────────────────────────────────────
# LVM sits between physical disks and filesystems.
# Lets you resize volumes without repartitioning.

# Physical Volume (PV) → Volume Group (VG) → Logical Volume (LV) → filesystem

# Set up LVM:
pvcreate /dev/sdb /dev/sdc           # initialise physical volumes
vgcreate vg_data /dev/sdb /dev/sdc   # create volume group from 2 disks
lvcreate -L 100G -n lv_db vg_data    # create 100GB logical volume
lvcreate -l 100%FREE -n lv_data vg_data  # use remaining free space
mkfs.ext4 /dev/vg_data/lv_db         # format
mount /dev/vg_data/lv_db /var/lib/postgresql

# Resize (without downtime for ext4/xfs):
lvextend -L +50G /dev/vg_data/lv_db  # add 50GB to logical volume
resize2fs /dev/vg_data/lv_db          # grow ext4 filesystem to fill LV
# xfs equivalent: xfs_growfs /var/lib/postgresql

# View LVM info:
pvs                               # physical volumes
vgs                               # volume groups
lvs                               # logical volumes
lvdisplay /dev/vg_data/lv_db      # detailed LV info
```

---

## /proc and /sys — The Virtual Filesystems

`/proc` and `/sys` are not on disk — they're windows into the running kernel. Reading them gives real-time kernel and process information. Writing to them changes kernel behaviour.

```bash
# ── /proc: process and kernel information ─────────────────────────────────────
cat /proc/cpuinfo                # CPU model, cores, features
cat /proc/meminfo                # memory breakdown (MemTotal, MemFree, Cached...)
cat /proc/loadavg                # load average: 1min 5min 15min running/total
cat /proc/uptime                 # seconds since boot
cat /proc/version                # kernel version + compiler
cat /proc/mounts                 # currently mounted filesystems (live version of fstab)
cat /proc/net/dev                # network interface stats (bytes, packets, errors)
cat /proc/net/tcp                # TCP connections (hex format)
cat /proc/sys/fs/file-max        # max open files system-wide

# Per-process info (replace 1234 with PID):
cat /proc/1234/status            # process status, memory, UID
cat /proc/1234/cmdline           # full command line (null-separated)
cat /proc/1234/environ           # environment variables
cat /proc/1234/fd/               # open file descriptors
ls -la /proc/1234/fd/            # see open files (→ symlinks to actual files)
cat /proc/1234/maps              # memory map: virtual address → file/device
cat /proc/1234/net/tcp           # TCP connections for this process's namespace
cat /proc/self/...               # /proc/self = current process (useful in scripts)

# ── /sys: kernel and hardware parameters ──────────────────────────────────────
ls /sys/class/net/               # network interfaces
cat /sys/class/net/eth0/speed    # interface speed in Mbps
cat /sys/block/sda/size          # disk size in 512-byte sectors
cat /sys/block/sda/queue/scheduler  # I/O scheduler (deadline, mq-deadline, none)

# ── sysctl: kernel parameter tuning ──────────────────────────────────────────
sysctl -a                                      # all kernel parameters
sysctl net.ipv4.ip_forward                     # check IP forwarding
sysctl -w net.ipv4.ip_forward=1               # enable IP forwarding now

# Persistent (survives reboot): /etc/sysctl.conf or /etc/sysctl.d/99-custom.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-networking.conf
sysctl --system                                # apply all sysctl.d files

# Production tuning examples:
# net.core.somaxconn = 65535         # max pending TCP connections
# net.ipv4.tcp_max_syn_backlog = 65535
# vm.swappiness = 10                 # prefer RAM over swap (0=never swap)
# fs.file-max = 2097152              # max open files system-wide
# net.ipv4.tcp_keepalive_time = 600  # detect dead connections faster
```

---

## File Descriptors & Special Files

```bash
# Every process has file descriptors (FDs):
# 0 = stdin   (standard input)
# 1 = stdout  (standard output)
# 2 = stderr  (standard error)
# 3+ = opened by the process (files, sockets, pipes)

# Check open file limits
ulimit -n                        # max open files for current shell/process
ulimit -n 65535                  # increase limit for current session
# System-wide limit: /proc/sys/fs/file-max
# Per-process limit: /etc/security/limits.conf
#   nginx  soft  nofile  65535
#   nginx  hard  nofile  65535

# Special device files:
/dev/null                        # black hole: discards all writes, EOF on read
/dev/zero                        # produces infinite null bytes
/dev/random                      # entropy pool: blocks when low entropy
/dev/urandom                     # non-blocking: slightly less random

# Use cases:
dd if=/dev/zero of=/tmp/test bs=1M count=100  # create a 100MB zero-filled file
dd if=/dev/urandom of=random_key bs=32 count=1 | base64  # generate random key
cat /dev/null > logfile.txt      # truncate a log file (keeps the file, empties it)
command > /dev/null 2>&1         # silence all output
```