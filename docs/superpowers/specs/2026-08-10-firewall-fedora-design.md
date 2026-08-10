# Firewall Management Module + Fedora Support — Design

**Date:** 2026-08-10
**Approved approach:** Interactive submenu (selected by Tony via design question)
**Version target:** 2.4.0 (minor bump — new module + new OS support)

## Goals

1. A dedicated **Firewall Management** module (menu 14, CLI `firewall`) that unifies
   firewalld (RHEL family) and ufw (Debian family) behind one interface.
2. **Full Fedora support** (40+): detection, package paths, Docker repo, tests.
3. Freshness pass: Node.js version menu (24 is now LTS/recommended, 20 is EOL),
   Ubuntu 26.04 LTS accepted, docs/CI consistency.

## Firewall Management module

### Placement
New `SECTION 18: FIREWALL MANAGEMENT` before the wizard; subsequent sections
renumber to 19–22. Menu item **14**, CLI module name **firewall**.

### Behavior
- **Interactive** (default): submenu loop — show status & rules, open a port,
  close a port, apply preset (web / portainer), enable firewall, disable firewall.
- **Non-interactive** (`--yes` or wizard): applies safe defaults — install native
  backend if missing, deny incoming, allow SSH/HTTP/HTTPS (+ 9443/tcp if Docker
  present), enable.
- **Containers**: module warns and exits 0 (firewalls are managed on the host) —
  same precedent as the security module today.
- **DRY_RUN**: every mutating operation previews instead of executing.

### Functions
| Function | Purpose |
|----------|---------|
| `module_firewall` | Entry point: container guard, backend bootstrap, route to submenu or defaults |
| `fw_detect_backend` | Sets `FW_BACKEND` (firewalld/ufw/none) and `FW_ACTIVE` |
| `fw_ensure_backend` | Installs native backend (rhel→firewalld, debian→ufw) if none |
| `fw_ssh_port` | Parses sshd_config (+drop-ins) for the real SSH port, default 22 |
| `fw_status` | Unified status: backend, active state, allowed services/ports |
| `fw_open_port` / `fw_close_port` | Validated `PORT[/tcp\|udp]`; firewalld uses service names for 22/80/443; `firewall-offline-cmd` when daemon inactive |
| `fw_preset_menu` | Presets: web (HTTP/HTTPS), portainer (9443, 8000) |
| `fw_enable` / `fw_disable` | Enable always allows SSH first; disable requires explicit confirm |
| `fw_apply_defaults` | The non-interactive safe setup (replaces old `configure_firewall`) |

### SSH lockout guard
- `fw_enable` and `fw_apply_defaults` always allow the detected SSH port before
  activating the firewall.
- `fw_close_port` on the SSH port prints a loud warning and requires an explicit
  "y" (never auto-accepted; refused in `--yes` mode).

### Security module change (module separation)
Per project feedback ("each tool gets its own menu item"), the firewall step is
**removed from the Security module** — Security becomes SSH hardening + fail2ban
and prints a pointer to the Firewall module. The old `configure_firewall` is
deleted; its logic lives in `fw_apply_defaults`. The wizard gains a dedicated
firewall step (core, default Y), so full setups still configure a firewall.
Behavior note: standalone `--yes security` no longer touches the firewall —
documented in README.

## Fedora support

| Area | Change |
|------|--------|
| `detect_os` | Already maps fedora→rhel. Add Fedora to the unsupported-OS hint; warn if Fedora < 40 |
| Update module | Skip EPEL + CRB on Fedora (packages are in the main repos) |
| Docker module | Repo file downloaded directly to `/etc/yum.repos.d/docker-ce.repo` from `download.docker.com/linux/{centos\|fedora}/docker-ce.repo` — also removes the `dnf config-manager --add-repo` dependency, which breaks on dnf5 (Fedora 41+) |
| Header/docs | Fedora 40+ added to supported list, README badges/tables, CLAUDE.md |
| Tests | New `test/Dockerfile.fedora` (fedora:latest — Fedora's 13-month cycle makes pinning churn), run-tests.sh target, CI matrix rows |

## Freshness pass

- **Node.js menu** (module + wizard): 24 LTS (Recommended, new default), 22 LTS,
  20 marked EOL. NodeSource still serves all three.
- **Ubuntu 26.04 LTS**: accepted without warning in `detect_os`; new
  `test/Dockerfile.ubuntu2604` + CI rows (info, security).
- README/CLAUDE.md updated for all of the above.

## Test plan

1. `bash -n` + ShellCheck (severity=warning, respecting .shellcheckrc).
2. Docker matrix via run-tests.sh: `info` and `firewall` on centos9, centos10,
   ubuntu2404, ubuntu2604, fedora; `security` regression on all; `update` on fedora
   (EPEL skip); `--dry-run --yes full` walks the wizard incl. firewall step.
3. Functional firewall verification: in a privileged ubuntu container, source the
   script with `main` stripped and `is_container` stubbed, then exercise
   fw_apply_defaults / fw_open_port / fw_close_port / fw_status against real ufw.
4. Interactive submenu smoke test by piping choices into `docker run -i`.

## Out of scope

- CLI subcommands (`firewall open 8080`) — submenu option was chosen instead.
- firewalld rich rules, zones, rate limiting — YAGNI for a toolbox.
- Debian 13 / trixie support — separate effort.
