<p align="center">
  <h1 align="center">🧰 FTA Server Toolbox</h1>
  <p align="center">
    <em>Your ultimate server management companion</em>
    <br />
    A single, comprehensive script for initializing, hardening, and maintaining Linux servers.
    <br /><br />
    <a href="#-quick-start">Quick Start</a> · <a href="#-modules">Modules</a> · <a href="#-modern-cli-tools">Tools</a> · <a href="#-supported-operating-systems">Supported OS</a>
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/CentOS_Stream-9_%7C_10-blue?logo=centos&logoColor=white" alt="CentOS" />
  <img src="https://img.shields.io/badge/Fedora-40+-blue?logo=fedora&logoColor=white" alt="Fedora" />
  <img src="https://img.shields.io/badge/Ubuntu-22.04_%7C_24.04_%7C_26.04-orange?logo=ubuntu&logoColor=white" alt="Ubuntu" />
  <img src="https://img.shields.io/badge/Debian-12+-red?logo=debian&logoColor=white" alt="Debian" />
  <img src="https://img.shields.io/badge/Arch-x86__64_%7C_ARM64-green" alt="Architecture" />
  <img src="https://img.shields.io/github/license/anxuanzi/FTA-Server-Toolbox" alt="License" />
  <img src="https://img.shields.io/github/actions/workflow/status/anxuanzi/FTA-Server-Toolbox/ci.yml?label=CI" alt="CI" />
</p>

---

## ✨ Features

| | Feature | Description |
|---|---|---|
| 📦 | **Single Script** | Everything in one file — no dependencies, no multi-file downloads |
| 🐧 | **Multi-OS** | CentOS Stream 9/10, RHEL 9/10, Rocky, AlmaLinux, Fedora 40+, Ubuntu 22.04/24.04/26.04, Debian 12 |
| 🏗️ | **Multi-Arch** | x86_64 and ARM64 (aarch64) fully supported |
| 📡 | **Latest Software** | Auto-fetches the latest stable versions from official sources and GitHub |
| 🛡️ | **Production Safe** | Config backups, dry-run mode, container detection, idempotent operations |
| 🧩 | **Modular** | Run individual modules or the full setup wizard with opt-in control |

---

## 🚀 Quick Start

```bash
# 📥 Download
curl -fsSLO https://raw.githubusercontent.com/anxuanzi/FTA-Server-Toolbox/main/fta-toolbox.sh

# 🔑 Make executable
chmod +x fta-toolbox.sh

# 🎯 Run interactive menu
sudo ./fta-toolbox.sh

# ⚡ Or run full setup (core modules, auto-accept)
sudo ./fta-toolbox.sh --yes full
```

---

## 📋 Modules

### 🟢 Core Modules (included in full setup by default)

| # | Module | Description |
|:---:|--------|-------------|
| 1 | 📋 **System Info** | Display system details, installed tools, resource usage |
| 2 | 🔄 **System Update** | Full system update + essential packages (git, vim, tmux, make, gcc, python3...) |
| 3 | 🌐 **Network Tools** | dig, traceroute, mtr, nmap, iperf3, tcpdump, whois, socat |
| 4 | 🛠️ **Modern CLI Tools** | 17 modern Unix tool replacements ([see below](#-modern-cli-tools)) |
| 9 | 🔒 **Security Hardening** | SSH hardening, fail2ban |
| 10 | ⚡ **Performance Tuning** | TCP BBR, kernel buffer tuning, file descriptor limits |
| 11 | 🕐 **Timezone & NTP** | Interactive timezone picker + chronyd/NTP sync |
| 13 | 🌍 **DNS Configuration** | Preset DNS providers (Cloudflare, Google, OpenDNS, DNSPod, DigitalOcean) or custom |
| 14 | 🔥 **Firewall Management** | Unified firewalld/ufw: status, open/close ports, presets, enable/disable ([see below](#-firewall-management)) |

### 🔵 Optional Modules (opt-in during full setup)

| # | Module | Description |
|:---:|--------|-------------|
| 5 | 💚 **Node.js** | Node.js LTS via NodeSource (choose v24/v22/v20) + yarn & pnpm |
| 6 | 🐳 **Docker Engine** | Docker CE + Compose + Buildx from official repos |
| 7 | 🏗️ **Portainer** | Docker web UI for container management |
| 8 | 👀 **Watchtower** | Automatic container image updates |
| 12 | 💾 **Swap Management** | Create/resize swap file with smart size recommendation |
| 15 | 💽 **Disk & Mount Manager** | Mount a data disk anywhere — e.g. move Docker volumes off the system disk — with verified copy & rollback ([see below](#-disk--mount-manager)) |

> 💡 **Tip:** In `--yes full` mode, only core modules run. Install optional services individually:
> ```bash
> sudo ./fta-toolbox.sh --yes docker
> sudo ./fta-toolbox.sh --yes portainer
> sudo ./fta-toolbox.sh --yes watchtower
> ```

---

## 🛠️ Modern CLI Tools

All tools are auto-installed from package managers when available, with fallback to the latest GitHub releases.

| Tool | Replaces | What It Does |
|:-----|:--------:|:-------------|
| 🦇 [bat](https://github.com/sharkdp/bat) | `cat` | Syntax highlighting, git integration, line numbers |
| 📂 [eza](https://github.com/eza-community/eza) | `ls` | Icons, git status, tree view, color-coded |
| 🔍 [fd](https://github.com/sharkdp/fd) | `find` | Intuitive syntax, super fast, respects .gitignore |
| ⚡ [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` | Extremely fast recursive search across files |
| 🎯 [fzf](https://github.com/junegunn/fzf) | — | Fuzzy finder for files, history, and everything |
| 📊 [jq](https://github.com/stedolan/jq) | — | Lightweight JSON processor |
| 📄 [yq](https://github.com/mikefarah/yq) | — | YAML, XML, and TOML processor |
| 📈 [bottom](https://github.com/ClementTsang/bottom) | `top` | Beautiful, customizable system monitor |
| 💿 [dust](https://github.com/bootandy/dust) | `du` | Intuitive disk usage with visual bars |
| 💾 [duf](https://github.com/muesli/duf) | `df` | Clean disk free overview with colors |
| 📦 [ncdu](https://dev.yorhel.nl/ncdu) | `du` | Interactive disk usage analyzer |
| 🚀 [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | Smarter directory jumping — it learns your habits |
| 📡 [gping](https://github.com/orf/gping) | `ping` | Ping with a live graph in your terminal |
| 🖥️ [fastfetch](https://github.com/fastfetch-cli/fastfetch) | `neofetch` | Lightning-fast system info display |
| 👁️ [glances](https://github.com/nicolargo/glances) | `top` | Advanced system monitoring dashboard |
| 🐳 [lazydocker](https://github.com/jesseduffield/lazydocker) | — | Terminal UI for Docker management |
| 🌿 [lazygit](https://github.com/jesseduffield/lazygit) | — | Terminal UI for Git — staging, diffs, logs |

---

## ⌨️ Usage

### 🖥️ Interactive Mode

```bash
sudo ./fta-toolbox.sh
```

The interactive menu lets you pick any module:

```
  ┌──────────────────────────────────────────────────────┐
  │       🧰 FTA Server Toolbox v2.5.0                  │
  │       Ubuntu 24.04 LTS • x86_64                     │
  └──────────────────────────────────────────────────────┘

    1)  📋  System Information
    2)  🔄  Update System & Essentials
    3)  🌐  Network Diagnostic Tools
    4)  🛠️   Modern CLI Tools
    5)  💚  Node.js (LTS)
    6)  🐳  Docker Engine
    7)  🏗️   Portainer (Docker UI)
    8)  👀  Watchtower (Auto-updater)
    9)  🔒  Security Hardening
   10)  ⚡  Performance Tuning
   11)  🕐  Timezone & NTP
   12)  💾  Swap Management
   13)  🌍  DNS Configuration
   14)  🔥  Firewall Management
   15)  💽  Disk & Mount Manager
    ─────────────────────────────────────
   88)  🚀  Full Auto Setup
   99)  📦  Self-Update Script
    0)  🚪  Exit
```

### 🤖 Non-Interactive Mode

```bash
# 🛠️ Run a specific module
sudo ./fta-toolbox.sh --yes modern

# 🔍 Preview changes without executing
sudo ./fta-toolbox.sh --dry-run --yes full

# 📋 Show system info (no root needed for info only)
sudo ./fta-toolbox.sh info
```

### 🏁 CLI Flags

| Flag | Description |
|:-----|:------------|
| `-h`, `--help` | 📖 Show help message |
| `-v`, `--version` | 🏷️ Show version |
| `-y`, `--yes` | ✅ Skip confirmation prompts (core modules only in full setup) |
| `--dry-run` | 🔍 Preview changes without executing |

### 📦 Available Module Names

```
info · update · network · modern · nodejs · docker · portainer · watchtower · security · tuning · timezone · swap · dns · firewall · disk · full
```

---

## 🔒 Security Hardening

> Each sub-step can be individually accepted or declined.

### 🔑 SSH Hardening
- 🚫 Disable empty password authentication
- ⚡ Disable DNS lookups (faster connections)
- 🚫 Disable GSSAPI authentication
- 🔐 Root login restricted to SSH keys only
- 🛡️ Limit auth attempts to 4
- ⏰ Idle session timeout (10 min)
- 📁 Uses `sshd_config.d` drop-in files when supported

### 🚔 fail2ban
- 🛡️ SSH brute-force protection
- 3️⃣ Max retries before ban
- ⏱️ 1 hour ban duration

> 🔥 Firewall setup moved to its own module in v2.4.0 — see [Firewall Management](#-firewall-management).

---

## 🔥 Firewall Management

One interface for both firewall backends — you never have to remember `firewall-cmd` or `ufw` syntax again. The module auto-detects the backend (firewalld on RHEL family, ufw on Debian/Ubuntu, installed on demand) and every action that activates the firewall **always allows your real SSH port first**, so you can't lock yourself out.

### 🖥️ Interactive menu

```
  Firewall: firewalld (active)

    1)  Show status & rules
    2)  Open a port
    3)  Close a port
    4)  Apply preset (web / portainer)
    5)  Enable firewall (keeps SSH open)
    6)  Disable firewall
    0)  Back to main menu
```

- 🔓 **Open/close ports** — accepts `8080`, `8080/tcp`, or `5353/udp`; well-known ports map to firewalld service names automatically
- 🎛️ **Presets** — web server (80, 443) and Portainer (9443, 8000)
- 🛡️ **SSH lockout guard** — closing your SSH port requires typing `yes` explicitly; refused entirely in non-interactive mode
- 📴 **Works before activation** — rules added while the firewall is off are saved (firewalld offline config / ufw stored rules)

### 🤖 Non-interactive mode

```bash
# Safe defaults: deny incoming, allow SSH/HTTP/HTTPS (+ 9443 if Docker), enable
sudo ./fta-toolbox.sh --yes firewall
```

---

## 💽 Disk & Mount Manager

Attach a data disk and mount it exactly where you need it — the classic case is putting `/var/lib/docker/volumes` on its own disk so all Docker volumes live there while the OS stays on the system disk. If the target folder already holds data, it is **moved onto the disk safely** — no manual rsync/fstab/systemd juggling.

### 🖥️ Interactive menu

```
    1)  Show disks & mounts
    2)  Mount a disk (move a folder like Docker volumes onto it)
    3)  Unmount a data disk
    4)  Grow a filesystem (after enlarging the disk)
    5)  Clean up migration backups
    0)  Back to main menu
```

"Mount a disk" is a 4-step guided flow — **pick a disk → pick a target → filesystem → services** — followed by a plan you approve before anything changes:

```
  ┌─ Plan ─────────────────────────────────────────────────
  │  Disk         /dev/sdb  (200G)
  │  Currently    mounted at /mnt/data → will be retired
  │  Filesystem   keep existing xfs filesystem (UUID 61e2…)
  │  Mount at     /var/lib/docker/volumes
  │  Data         3.2G to copy (hot rsync, then a short cold delta pass)
  │  Old copy     kept as /var/lib/docker/volumes.fta-bak-<timestamp>
  │  Services     docker.socket docker.service containerd.service
  │  fstab        UUID=… /var/lib/docker/volumes xfs defaults,nofail 0 0
  │  Boot order   docker.service waits for the mount (systemd drop-in)
  └────────────────────────────────────────────────────────
```

**Target presets:** Docker volumes · Docker data root · `/home` · `/data` · any custom path.
**Disk can be:** a blank disk (formatted as **xfs** or ext4), an unmounted disk with a filesystem (keep or reformat), or a disk already mounted somewhere like `/mnt/data` (its old mount is retired).

### 🔁 What a migration does

1. 📦 Installs `rsync` / `xfsprogs` if missing; formats the disk if requested
2. 🔥 **Hot copy** with `rsync -aHAXx --numeric-ids` while services keep running (keeps permissions, owners, hardlinks, ACLs, xattrs/SELinux labels)
3. ⏸️ Stops the dependent services, runs a short **cold delta** pass, then **verifies** the disk matches the source
4. 🔀 Moves the original folder aside to `<dir>.fta-bak-<timestamp>` (instant rename, nothing deleted)
5. 📝 Writes `/etc/fstab` by **UUID** with `nofail` (your server still boots if the disk goes missing) and mounts from fstab to prove the entry works
6. 🏷️ Restores SELinux labels (RHEL family), adds a systemd drop-in so services **wait for the mount at boot** (`RequiresMountsFor` + `ConditionPathIsMountPoint` — Docker never silently writes to the system disk), and restarts the services

### 🛡️ Safety

- ↩️ **Automatic rollback** — any failure before the new mount is live (copy error, busy mount, bad fstab entry, Ctrl-C) puts fstab, the original folder, the old mount and the services back exactly as they were
- ⌨️ **Erase guard** — formatting a disk that has any filesystem/partition signature requires typing the device name; it is refused outright in `--yes` mode (only truly blank disks are auto-formatted)
- 🚫 Refuses system disks and paths (`/`, `/etc`, `/usr`, `/var`, `/boot`…), disks with partitions, LVM/RAID members, swap, and targets that are already mounts
- 📏 Checks free space and XFS `ftype=1` (required by Docker's overlay2) before copying
- 🧹 Backups are kept until you remove them via **Clean up migration backups** (the menu shows how many are pending)

### 🤖 Non-interactive mode

```bash
# Move Docker volumes onto a disk that is currently mounted at /mnt/data
sudo ./fta-toolbox.sh --yes disk /mnt/data /var/lib/docker/volumes

# Format a blank disk as xfs and mount it at /data
sudo ./fta-toolbox.sh --yes disk /dev/sdb /data xfs

# Preview the plan without changing anything
sudo ./fta-toolbox.sh --dry-run disk /dev/sdb /var/lib/docker/volumes
```

Usage: `disk [SOURCE TARGET [xfs|ext4|keep]]` — `SOURCE` is a device (`/dev/sdb`) or a mounted path. With no arguments, `--yes disk` just prints the overview.

> 💡 In the **Full Setup wizard**, the data disk step is offered when a free disk is attached, and it runs *before* Docker so a fresh install writes straight to the data disk.

---

## ⚡ Performance Tuning

### 🔧 Kernel Parameters
- 📡 TCP BBR congestion control
- 📊 Optimized TCP buffer sizes
- 🔗 Connection backlog tuning (`somaxconn: 65535`)
- 🚀 TCP Fast Open enabled
- 💓 Keepalive optimization
- ⚖️ Fair queuing (`fq`) scheduler

### 📈 System Limits
- 📂 File descriptors: **1,048,576** (soft + hard)
- ⚙️ Processes: **65,536** (soft + hard)
- 🔧 systemd `DefaultLimitNOFILE` updated

---

## 🌍 DNS Configuration

Choose from five popular public DNS providers or enter custom servers:

| # | Provider | Primary | Secondary |
|:-:|:---------|:--------|:----------|
| 1 | ☁️ **Cloudflare** (default) | `1.1.1.1` | `1.0.0.1` |
| 2 | 🔍 **Google** | `8.8.8.8` | `8.8.4.4` |
| 3 | 🛡️ **OpenDNS** | `208.67.222.222` | `208.67.220.220` |
| 4 | 🇨🇳 **DNSPod** | `119.29.29.29` | `119.28.28.28` |
| 5 | 🌊 **DigitalOcean** | `67.207.67.2` | `67.207.67.3` |
| 0 | ✏️ **Custom** | *(you provide)* | *(optional)* |

### 🔧 How It Works

The module auto-detects the DNS management backend on your system and applies changes through the correct channel:

| Backend | Systems | Config Path |
|:--------|:--------|:------------|
| **systemd-resolved** | Ubuntu 22.04/24.04, modern Debian | `/etc/systemd/resolved.conf` |
| **NetworkManager** | CentOS/RHEL/Rocky/Alma | `nmcli` connection settings |
| **Direct** (fallback) | Minimal installs | `/etc/resolv.conf` |

- 💾 Original configuration is **backed up** before any change
- ✅ DNS resolution is **verified** after applying (via `dig` or `nslookup`)
- 🔍 Supports `--dry-run` to preview changes without modifying anything

```bash
# 🌍 Interactive DNS setup
sudo ./fta-toolbox.sh dns

# ☁️ Set Cloudflare DNS non-interactively
sudo ./fta-toolbox.sh --yes dns
```

---

## 🐧 Supported Operating Systems

| OS | Versions | Package Manager |
|:---|:---------|:---------------:|
| 🟠 CentOS Stream | 9, 10 | `dnf` |
| 🔴 RHEL | 9, 10 | `dnf` |
| 🟢 Rocky Linux | 9, 10 | `dnf` |
| 🔵 AlmaLinux | 9, 10 | `dnf` |
| 🔵 Fedora | 40+ | `dnf` |
| 🟠 Ubuntu LTS | 22.04, 24.04, 26.04 | `apt` |
| 🔴 Debian | 12+ | `apt` |

---

## 🧪 Testing

The script is tested in Docker containers via GitHub Actions CI and locally:

```bash
# 🏗️ Make test runner executable
chmod +x test/run-tests.sh

# 🟠 Test on CentOS 9
./test/run-tests.sh centos9 info

# 🟠 Test on CentOS 10
./test/run-tests.sh centos10 modern

# 🔵 Test on Fedora
./test/run-tests.sh fedora modern

# 🟣 Test on Ubuntu 24.04 / 26.04
./test/run-tests.sh ubuntu2404 modern
./test/run-tests.sh ubuntu2604 firewall

# 🌍 Test all platforms
./test/run-tests.sh all info
```

---

## 🛡️ Production Safety

| | Feature | Details |
|---|---------|---------|
| 💾 | **Backups** | Config files backed up before modification → `~/.fta-toolbox/backups/` |
| 🔍 | **Dry-run** | Preview all changes with `--dry-run` before applying |
| 📦 | **Container-aware** | Detects Docker/LXC and skips incompatible operations (kernel tuning, firewall, etc.) |
| 🔄 | **Idempotent** | Safe to re-run — checks for existing installations before acting |
| 🛡️ | **Non-destructive** | Never removes existing configs; uses drop-in files where possible |
| 📝 | **Logging** | All operations logged to `/var/log/fta-toolbox.log` |
| ✅ | **Opt-in services** | Docker, Node.js, Portainer, Watchtower require explicit selection |

---

## 🔄 Self-Update

```bash
sudo ./fta-toolbox.sh
# Select option 99 from the menu
```

Or directly:
```bash
curl -fsSLO https://raw.githubusercontent.com/anxuanzi/FTA-Server-Toolbox/main/fta-toolbox.sh && chmod +x fta-toolbox.sh
```

---

## 📁 Project Structure

```
📦 FTA-Server-Toolbox
├── 🧰 fta-toolbox.sh            # Main toolbox (single file, everything included)
├── 📖 README.md                  # This file
├── 📜 LICENSE                    # Apache 2.0
├── 🔧 .shellcheckrc             # ShellCheck configuration
├── 🤖 .github/workflows/ci.yml  # GitHub Actions CI pipeline
└── 🧪 test/
    ├── 🟠 Dockerfile.centos9    # CentOS 9 Stream test container
    ├── 🟠 Dockerfile.centos10   # CentOS 10 Stream test container
    ├── 🔵 Dockerfile.fedora     # Fedora (latest) test container
    ├── 🟣 Dockerfile.ubuntu2404 # Ubuntu 24.04 LTS test container
    ├── 🟣 Dockerfile.ubuntu2604 # Ubuntu 26.04 LTS test container
    └── 🏃 run-tests.sh          # Docker test runner
```

---

## 📜 License

Apache License 2.0 — see [LICENSE](LICENSE)

## 🤝 Contributing

Contributions welcome! Fork the repo, make improvements, and submit a pull request.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/anxuanzi">FantasticTony</a>
</p>
