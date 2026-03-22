# 🧰 FTA Server Toolbox

Your ultimate server management companion — a single, comprehensive script for initializing, hardening, and maintaining Linux servers.

## Features

- **Single Script** — Everything in one file. No dependencies, no multi-file downloads
- **Multi-OS Support** — CentOS Stream 9/10, RHEL 9/10, Rocky Linux, AlmaLinux, Ubuntu 22.04/24.04, Debian 12
- **Multi-Architecture** — x86_64 and ARM64 (aarch64) fully supported
- **Latest Software** — Always fetches the latest stable versions from official sources
- **Beautiful UX** — Interactive menus with emoji indicators, colored output, and step-by-step guidance
- **Production Safe** — Config backups, dry-run mode, container detection, idempotent operations
- **Modular Design** — Run individual modules or the full setup wizard

## Quick Start

```bash
# Download
curl -fsSLO https://raw.githubusercontent.com/anxuanzi/shell-scripts/main/fta-toolbox.sh

# Make executable
chmod +x fta-toolbox.sh

# Run interactive menu
sudo ./fta-toolbox.sh

# Or run full setup with auto-accept
sudo ./fta-toolbox.sh --yes full
```

## Modules

| # | Module | Description |
|---|--------|-------------|
| 1 | 📋 System Information | Display system details, installed tools, resource usage |
| 2 | 🔄 System Update | Full system update + essential packages (git, vim, tmux, make, gcc, python3, etc.) |
| 3 | 🌐 Network Tools | dig, traceroute, mtr, nmap, iperf3, tcpdump, whois, socat |
| 4 | 🛠️ Modern CLI Tools | 15+ modern Unix tool replacements (see below) |
| 5 | 💚 Node.js | Node.js LTS via NodeSource (choose v20/v22/v24) + yarn & pnpm |
| 6 | 🐳 Docker Engine | Docker CE + Compose + Buildx from official repos |
| 7 | 🏗️ Portainer & Watchtower | Docker web UI + automatic container updates |
| 8 | 🔒 Security Hardening | SSH hardening, firewall (firewalld/ufw), fail2ban |
| 9 | ⚡ Performance Tuning | TCP BBR, kernel buffer tuning, file descriptor limits |
| 10 | 🕐 Timezone & NTP | Interactive timezone picker + chronyd/NTP sync |
| 11 | 💾 Swap Management | Create/resize swap file with smart size recommendation |
| 88 | 🚀 Full Auto Setup | Guided wizard through all modules with per-step control |

## Modern CLI Tools Installed

| Tool | Replaces | Source |
|------|----------|--------|
| [bat](https://github.com/sharkdp/bat) | `cat` | Syntax highlighting, git integration |
| [eza](https://github.com/eza-community/eza) | `ls` | Icons, git status, tree view |
| [fd](https://github.com/sharkdp/fd) | `find` | Intuitive syntax, fast |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` | Extremely fast recursive search |
| [fzf](https://github.com/junegunn/fzf) | — | Fuzzy finder for everything |
| [jq](https://github.com/stedolan/jq) | — | JSON processor |
| [yq](https://github.com/mikefarah/yq) | — | YAML/XML/TOML processor |
| [bottom](https://github.com/ClementTsang/bottom) | `top`/`htop` | Beautiful system monitor |
| [dust](https://github.com/bootandy/dust) | `du` | Intuitive disk usage |
| [duf](https://github.com/muesli/duf) | `df` | Disk free overview |
| [ncdu](https://dev.yorhel.nl/ncdu) | `du` | Interactive disk usage |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | Smarter directory navigation |
| [gping](https://github.com/orf/gping) | `ping` | Ping with live graph |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | `neofetch` | System info display |
| [glances](https://github.com/nicolargo/glances) | `top` | Advanced system monitoring dashboard |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | — | Docker TUI manager |
| [lazygit](https://github.com/jesseduffield/lazygit) | — | Git TUI manager |

Tools are installed from package managers when available, with automatic fallback to GitHub releases or pipx.

## Usage

### Interactive Mode (Menu)

```bash
sudo ./fta-toolbox.sh
```

### Non-Interactive Mode (CLI)

```bash
# Run a specific module
sudo ./fta-toolbox.sh --yes modern

# Preview changes without executing
sudo ./fta-toolbox.sh --dry-run --yes full

# Show system info
sudo ./fta-toolbox.sh info
```

### CLI Options

| Flag | Description |
|------|-------------|
| `-h, --help` | Show help message |
| `-v, --version` | Show version |
| `-y, --yes` | Skip all confirmation prompts |
| `--dry-run` | Preview changes without executing |

### Available Modules

`info` `update` `network` `modern` `nodejs` `docker` `portainer` `security` `tuning` `timezone` `swap` `full`

## Security Hardening Details

The security module applies these changes (each can be individually accepted/declined):

**SSH Hardening:**
- Disable empty password authentication
- Disable DNS lookups (faster connections)
- Disable GSSAPI authentication
- Root login: key-based only
- Limit auth attempts to 4
- Idle session timeout (10 min)
- Uses sshd_config.d drop-in when supported

**Firewall:**
- firewalld (RHEL) or ufw (Debian/Ubuntu)
- Default: allow SSH, HTTP, HTTPS
- Portainer port (9443) if Docker installed

**fail2ban:**
- SSH brute-force protection
- 3 max retries, 1 hour ban

## Performance Tuning Details

**Kernel Parameters:**
- TCP BBR congestion control
- Optimized TCP buffer sizes
- Connection backlog tuning (somaxconn: 65535)
- TCP Fast Open enabled
- Keepalive optimization
- Fair queuing scheduler

**System Limits:**
- File descriptors: 1,048,576 (soft + hard)
- Processes: 65,536 (soft + hard)
- systemd DefaultLimitNOFILE updated

## Supported Operating Systems

| OS | Versions | Package Manager |
|----|----------|-----------------|
| CentOS Stream | 9, 10 | dnf |
| RHEL | 9, 10 | dnf |
| Rocky Linux | 9, 10 | dnf |
| AlmaLinux | 9, 10 | dnf |
| Ubuntu LTS | 22.04, 24.04 | apt |
| Debian | 12+ | apt |

## Testing

The script is tested in Docker containers to ensure safety:

```bash
# Run tests
chmod +x test/run-tests.sh

# Test on CentOS 9
./test/run-tests.sh centos9 info

# Test on CentOS 10
./test/run-tests.sh centos10 modern

# Test on Ubuntu 24.04
./test/run-tests.sh ubuntu2404 modern

# Test all platforms
./test/run-tests.sh all info
```

## Production Safety

- **Backups** — All config files are backed up before modification to `~/.fta-toolbox/backups/`
- **Dry-run** — Preview all changes with `--dry-run` before applying
- **Container-aware** — Detects Docker/LXC environments and skips incompatible operations
- **Idempotent** — Safe to re-run; checks for existing installations
- **Non-destructive** — Never removes existing configurations; uses drop-in files where possible
- **Logging** — All operations logged to `/var/log/fta-toolbox.log`

## Self-Update

```bash
sudo ./fta-toolbox.sh
# Select option 99 from the menu
```

## Project Structure

```
├── fta-toolbox.sh           # Main toolbox script (single file, everything included)
├── README.md                # This file
├── LICENSE                  # Apache 2.0
├── .shellcheckrc            # ShellCheck configuration
├── .github/workflows/ci.yml # GitHub Actions CI pipeline
└── test/
    ├── Dockerfile.centos9   # CentOS 9 test container
    ├── Dockerfile.centos10  # CentOS 10 test container
    ├── Dockerfile.ubuntu2404 # Ubuntu 24.04 test container
    └── run-tests.sh         # Docker test runner
```

## Legacy Scripts

The original multi-file scripts (`setup.sh`, `fta_os_init.sh`, `install_docker.sh`, etc.) are still available for reference but are superseded by `fta-toolbox.sh`.

## License

Apache License 2.0 — see [LICENSE](LICENSE)

## Contributing

Contributions welcome! Fork, improve, and submit a pull request.
