# FTA Server Toolbox — Agent Instructions

## Project Overview

Single-file Bash toolbox (`fta-toolbox.sh`, ~2300 lines) for initializing, hardening, and maintaining Linux servers. Everything lives in one script — no external dependencies, no multi-file downloads.

**Supported OS:** CentOS Stream 9/10, RHEL 9/10, Rocky 9/10, AlmaLinux 9/10, Ubuntu 22.04/24.04 LTS, Debian 12
**Architectures:** x86_64, ARM64 (aarch64)

## File Structure

```
fta-toolbox.sh          # The entire toolbox (single file)
test/run-tests.sh       # Docker-based test runner
test/Dockerfile.*       # Test containers (centos9, centos10, ubuntu2404)
.github/workflows/ci.yml  # CI pipeline (ShellCheck + Docker integration tests)
.shellcheckrc           # ShellCheck suppressions (SC2034, SC2086, SC2155, SC2059, SC1091)
```

## Script Architecture

The script is organized into numbered sections (1–21). When adding or modifying modules, maintain this structure:

| Sections | Purpose |
|----------|---------|
| 1–4 | Constants, colors, cleanup, utility functions |
| 5 | OS detection (`detect_os`) |
| 6–17 | Feature modules (`module_*` functions) |
| 18 | Full auto setup wizard (`module_full_setup`) |
| 19 | Self-update |
| 20 | Menu system (`show_menu`, `handle_choice`, `menu_loop`) |
| 21 | CLI argument parsing & `main()` |

## Module Conventions

Every module function follows a consistent pattern:

1. `msg_header "emoji Title"` — section banner
2. Show current state (existing config, installed version, etc.)
3. `confirm "..."` guard — skips if user declines
4. `DRY_RUN` check — preview without changes
5. OS-family dispatch (`case "$OS_FAMILY" in rhel|debian`)
6. `backup_file` before modifying any config
7. Verification step after changes
8. `msg_done "... complete"` at end

**Key globals:** `AUTO_YES`, `DRY_RUN`, `WIZARD_ACTIVE`, `OS_FAMILY` (rhel|debian), `OS_ID`, `ARCH`, `ARCH_ALT`

## Adding a New Module — Checklist

When adding a new module, update ALL of these locations:

1. **Module function** — new `# SECTION N:` block before the wizard (Section 18)
2. **Renumber sections** — bump all subsequent section comment numbers
3. **`show_menu()`** — add menu item line
4. **`handle_choice()`** — add case branch
5. **`show_help()`** — add to MODULES list
6. **CLI parser in `main()`** — add to the argument pattern match AND the dispatch case
7. **`module_full_setup()`** — add `do_*` variable, prompt, summary line, total counter, and execution block
8. **`test/run-tests.sh`** — add to usage message module list
9. **`README.md`** — add to module tables, menu display, module names list, and optionally a dedicated section

## Available Utility Functions

Use these instead of raw commands:

| Function | Purpose |
|----------|---------|
| `msg_info/ok/warn/err/step/skip/done` | Styled output + logging |
| `msg_header "title"` | Section banner |
| `confirm "prompt" [default]` | Y/n confirmation (auto-accepted by `--yes` and wizard) |
| `command_exists cmd` | Check if command is available |
| `is_container` | Detect Docker/LXC environment |
| `pkg_install pkg...` | OS-agnostic package install (dnf/apt) |
| `pkg_update` | OS-agnostic package list refresh |
| `backup_file /path` | Copy to `~/.fta-toolbox/backups/` with timestamp |
| `download_file url dest` | curl with wget fallback |
| `install_github_binary name repo binary url_pattern type` | Full GitHub release installer |
| `get_latest_version repo` | Fetch latest GitHub release tag |
| `spinner pid msg` | Animated spinner for long operations |
| `press_enter` | Pause (skipped in auto/wizard mode) |
| `log msg` | Write to `/var/log/fta-toolbox.log` |

## Testing

```bash
# Syntax check (always do this before committing)
bash -n fta-toolbox.sh

# Run a module in Docker
./test/run-tests.sh ubuntu2404 info
./test/run-tests.sh centos9 modern
./test/run-tests.sh all info

# Dry-run a module locally
sudo ./fta-toolbox.sh --dry-run --yes dns
```

CI runs ShellCheck + Docker integration tests on push to `main` and on PRs.

## Code Style

- **Strict mode:** `set -uo pipefail` (no `set -e`; errors handled explicitly)
- **Quoting:** Quote variables in conditionals and paths; unquoted is OK for known-safe single-token values (suppressed via `.shellcheckrc`)
- **Functions:** `snake_case`, prefixed `module_` for top-level modules
- **Comments:** `# --- Section Name ---` for logical blocks within functions
- **Output:** Always use `msg_*` helpers, never raw `echo` (except inside subshells or heredocs)
- **Config changes:** Always `backup_file` first, always verify after
- **OS dispatch:** `case "$OS_FAMILY" in rhel) ... ;; debian) ... ;; esac`

## Version Management & Release Workflow

**CRITICAL: Every commit that changes `fta-toolbox.sh` behavior MUST bump the version.** The self-update mechanism (menu option 99) compares the version string to decide whether to update. If you change code without bumping the version, users will never receive the update.

### How self-update works

1. Downloads `fta-toolbox.sh` from `main` branch via raw GitHub URL
2. Extracts `TOOLBOX_VERSION` from the downloaded file
3. Compares to the running version — **string equality, not semver**
4. If different → offers to replace itself in-place and exits

### Version location

Line 26 of `fta-toolbox.sh`:
```bash
readonly TOOLBOX_VERSION="X.Y.Z"
```

### When to bump

| Change type | Bump | Example |
|-------------|------|---------|
| New module, major feature | **Minor** (X.Y+1.0) | 2.1.0 → 2.2.0 |
| Bug fix, tweak, small improvement | **Patch** (X.Y.Z+1) | 2.1.0 → 2.1.1 |
| Breaking changes, major rewrite | **Major** (X+1.0.0) | 2.1.0 → 3.0.0 |
| Docs-only changes (README, CLAUDE.md) | **No bump needed** | — |

### Commit workflow

1. Make your code changes
2. Bump `TOOLBOX_VERSION` on line 26
3. Run `bash -n fta-toolbox.sh` to syntax check
4. Commit and push

**Never push behavioral changes to `fta-toolbox.sh` without a version bump.**

## Current Modules (menu numbers)

1=System Info, 2=Update, 3=Network Tools, 4=Modern CLI, 5=Node.js, 6=Docker, 7=Portainer, 8=Watchtower, 9=Security, 10=Performance, 11=Timezone, 12=Swap, 13=DNS, 88=Full Setup, 99=Self-Update, 0=Exit
