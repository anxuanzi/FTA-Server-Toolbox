#!/usr/bin/env bash
# =============================================================================
#  _____ _____  _      ____              _                 _____           _
# |  ___|_   _|/ \    / ___|  ___ _ __  | | __ ___  _ __  |_   _|__   ___ | |
# | |_    | | / _ \   \___ \ / _ \ '__| \ \ / // _ \| '__|   | |/ _ \ / _ \| |
# |  _|   | |/ ___ \   ___) |  __/ |     \ V /|  __/| |      | | (_) | (_) | |
# |_|     |_/_/   \_\ |____/ \___|_|      \_/  \___||_|      |_|\___/ \___/|_|
#
# FTA Server Toolbox — Your Ultimate Server Management Companion
# =============================================================================
# Version:     2.0.0
# Author:      FantasticTony
# License:     Apache 2.0
# Repository:  https://github.com/anxuanzi/FTA-Server-Toolbox
# Supported:   CentOS Stream 9/10, RHEL 9/10, Rocky 9/10, AlmaLinux 9/10,
#              Ubuntu 22.04/24.04 LTS, Debian 12
# =============================================================================

# --- Strict Mode (no set -e; we handle errors explicitly) ---
set -uo pipefail

# =============================================================================
# SECTION 1: CONSTANTS & CONFIGURATION
# =============================================================================

readonly TOOLBOX_VERSION="2.0.0"
readonly TOOLBOX_NAME="FTA Server Toolbox"
readonly LOG_FILE="/var/log/fta-toolbox.log"
readonly CONFIG_DIR="/root/.fta-toolbox"
readonly LOCK_FILE="/tmp/fta-toolbox.lock"
readonly GITHUB_REPO="anxuanzi/FTA-Server-Toolbox"
readonly SELF_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/fta-toolbox.sh"

BACKUP_DIR=""
TMP_DIR=""
AUTO_YES=false
DRY_RUN=false
WIZARD_ACTIVE=false

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH_ALT="amd64"       # Debian/Go: amd64
        ARCH_GH="x86_64"       # Go mixed (lazydocker/lazygit/gping): x86_64
        ARCH_FP="amd64"        # fastfetch: amd64
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ARCH_ALT="arm64"       # Debian/Go: arm64
        ARCH_GH="arm64"        # Go mixed (lazydocker/lazygit/gping): arm64
        ARCH_FP="aarch64"      # fastfetch: aarch64
        ;;
    *)
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# OS detection variables (populated by detect_os)
OS_ID=""
OS_VERSION=""
OS_NAME=""
OS_FAMILY=""      # rhel or debian
OS_PRETTY=""

# =============================================================================
# SECTION 2: COLORS & STYLING
# =============================================================================

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN=''
    WHITE='' BOLD='' DIM='' RESET=''
fi

# =============================================================================
# SECTION 3: SIGNAL HANDLING & CLEANUP
# =============================================================================

cleanup() {
    [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]] && rm -rf "$TMP_DIR"
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
}
trap cleanup EXIT INT TERM

# =============================================================================
# SECTION 4: UTILITY FUNCTIONS
# =============================================================================

# --- Logging ---
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

# --- Messaging ---
msg()         { printf "%b\n" "$*"; }
msg_info()    { msg "  ${BLUE}ℹ${RESET}  $1"; log "INFO: $1"; }
msg_ok()      { msg "  ${GREEN}✅${RESET} $1"; log "OK: $1"; }
msg_warn()    { msg "  ${YELLOW}⚠️${RESET}  $1"; log "WARN: $1"; }
msg_err()     { msg "  ${RED}❌${RESET} $1"; log "ERROR: $1"; }
msg_step()    { msg "  ${CYAN}▶${RESET}  $1"; log "STEP: $1"; }
msg_skip()    { msg "  ${DIM}⏭  $1 (already installed)${RESET}"; }
msg_done()    { msg "  ${GREEN}🎉${RESET} ${BOLD}$1${RESET}"; log "DONE: $1"; }

msg_header() {
    msg ""
    msg "  ${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    msg "  ${BOLD}${MAGENTA}  $1${RESET}"
    msg "  ${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    msg ""
}

msg_banner() {
    msg ""
    msg "  ${CYAN}┌──────────────────────────────────────────────────────┐${RESET}"
    msg "  ${CYAN}│${RESET}       ${BOLD}🧰 ${TOOLBOX_NAME} v${TOOLBOX_VERSION}${RESET}              ${CYAN}│${RESET}"
    msg "  ${CYAN}│${RESET}       ${DIM}${OS_PRETTY} • ${ARCH}${RESET}$(printf '%*s' $((27 - ${#OS_PRETTY} - ${#ARCH})) '')${CYAN}│${RESET}"
    msg "  ${CYAN}└──────────────────────────────────────────────────────┘${RESET}"
    msg ""
}

# --- Confirmation ---
confirm() {
    local prompt=$1
    local default=${2:-Y}
    [[ "$AUTO_YES" == true || "$WIZARD_ACTIVE" == true ]] && return 0
    local yn
    if [[ "$default" == "Y" ]]; then
        read -rp "  $prompt [Y/n]: " yn
        [[ -z "$yn" || "$yn" =~ ^[yY] ]]
    else
        read -rp "  $prompt [y/N]: " yn
        [[ "$yn" =~ ^[yY] ]]
    fi
}

# --- Utility Helpers ---
command_exists() { command -v "$1" &>/dev/null; }

is_container() {
    [[ -f /.dockerenv ]] ||
    grep -qsE 'docker|lxc|containerd|kubepods' /proc/1/cgroup 2>/dev/null ||
    [[ "$(cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep -c container)" -gt 0 ]]
}

ensure_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_err "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_internet() {
    if ! curl -fsS --connect-timeout 5 https://github.com -o /dev/null 2>/dev/null; then
        if ! curl -fsS --connect-timeout 5 https://google.com -o /dev/null 2>/dev/null; then
            msg_err "No internet connectivity detected"
            return 1
        fi
    fi
    return 0
}

ensure_tmp() {
    if [[ -z "${TMP_DIR:-}" || ! -d "${TMP_DIR:-}" ]]; then
        TMP_DIR=$(mktemp -d /tmp/fta-toolbox.XXXXXX)
    fi
}

backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        [[ -z "$BACKUP_DIR" ]] && BACKUP_DIR="${CONFIG_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp -p "$file" "${BACKUP_DIR}/$(basename "$file").bak"
        msg_info "Backed up $(basename "$file")"
    fi
}

# --- Package Manager Abstraction ---
pkg_install() {
    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would install: $*"
        return 0
    fi
    case "$OS_FAMILY" in
        rhel)   dnf install -y --allowerasing "$@" &>/dev/null ;;
        debian) DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" &>/dev/null ;;
    esac
}

pkg_update() {
    msg_step "Updating package lists..."
    case "$OS_FAMILY" in
        rhel)   dnf makecache -q &>/dev/null ;;
        debian) apt-get update -qq &>/dev/null ;;
    esac
}

# --- GitHub Release Helpers ---
get_latest_version() {
    local repo=$1
    local version
    # Method: follow redirect to get effective URL → extract tag
    version=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
        "https://github.com/${repo}/releases/latest" 2>/dev/null | sed 's|.*/||')
    if [[ -n "$version" && "$version" != "latest" && "$version" != "releases" ]]; then
        echo "$version"
        return 0
    fi
    # Fallback: GitHub API
    version=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep -m1 '"tag_name"' | sed 's/.*"tag_name": "//;s/".*//')
    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    fi
    return 1
}

download_file() {
    local url=$1 dest=$2
    curl -fsSL "$url" -o "$dest" 2>/dev/null || wget -qO "$dest" "$url" 2>/dev/null
}

install_github_binary() {
    local name=$1 repo=$2 binary=$3 url_pattern=$4 type=${5:-tar}

    if command_exists "$binary"; then
        msg_skip "$name"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would install $name from GitHub ($repo)"
        return 0
    fi

    local version
    version=$(get_latest_version "$repo") || {
        msg_warn "Cannot fetch latest version for $name — skipping"
        return 1
    }
    local vbare=${version#v}

    # Replace placeholders
    local url=$url_pattern
    url=${url//\{VER\}/$vbare}
    url=${url//\{TAG\}/$version}
    url=${url//\{ARCH\}/$ARCH}
    url=${url//\{ARCH_ALT\}/$ARCH_ALT}
    url=${url//\{ARCH_GH\}/$ARCH_GH}
    url=${url//\{ARCH_FP\}/$ARCH_FP}

    ensure_tmp
    local dl_dir=$(mktemp -d "$TMP_DIR/gh.XXXXXX")
    msg_step "Installing $name ${DIM}($version)${RESET}..."

    if ! download_file "$url" "$dl_dir/download"; then
        msg_warn "Failed to download $name — skipping"
        rm -rf "$dl_dir"
        return 1
    fi

    case $type in
        tar)
            tar -xf "$dl_dir/download" -C "$dl_dir" 2>/dev/null
            local found
            found=$(find "$dl_dir" -name "$binary" -type f ! -path "*/download" 2>/dev/null | head -1)
            if [[ -n "$found" ]]; then
                install -m 755 "$found" /usr/local/bin/
            fi
            ;;
        zip)
            unzip -qo "$dl_dir/download" -d "$dl_dir" 2>/dev/null
            local found
            found=$(find "$dl_dir" -name "$binary" -type f ! -path "*/download" 2>/dev/null | head -1)
            if [[ -n "$found" ]]; then
                install -m 755 "$found" /usr/local/bin/
            fi
            ;;
        binary)
            install -m 755 "$dl_dir/download" "/usr/local/bin/$binary"
            ;;
        deb)
            dpkg -i "$dl_dir/download" &>/dev/null || apt-get install -f -y &>/dev/null
            ;;
        rpm)
            dnf install -y "$dl_dir/download" &>/dev/null || rpm -ivh "$dl_dir/download" &>/dev/null
            ;;
    esac

    rm -rf "$dl_dir"

    if command_exists "$binary"; then
        msg_ok "$name $version installed"
    else
        msg_warn "$name may not have installed correctly"
        return 1
    fi
}

# --- Spinner for long operations ---
spinner() {
    local pid=$1 msg=$2
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    [[ ! -t 1 ]] && { wait "$pid" 2>/dev/null; return $?; }
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${RESET} %s" "${chars:i%${#chars}:1}" "$msg"
        i=$((i + 1))
        sleep 0.1
    done
    wait "$pid" 2>/dev/null
    local rc=$?
    printf "\r%*s\r" $((${#msg} + 6)) ""
    return $rc
}

press_enter() {
    [[ "$AUTO_YES" == true || "$WIZARD_ACTIVE" == true ]] && return
    echo ""
    read -rp "  Press Enter to continue..."
}

# =============================================================================
# SECTION 5: OS DETECTION
# =============================================================================

detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        msg_err "Cannot detect OS — /etc/os-release not found"
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-0}"
    OS_NAME="${NAME:-Unknown}"
    OS_PRETTY="${PRETTY_NAME:-Unknown OS}"

    # Determine OS family
    case "$OS_ID" in
        centos|rhel|rocky|almalinux|ol|fedora)
            OS_FAMILY="rhel"
            ;;
        ubuntu|debian|linuxmint|pop)
            OS_FAMILY="debian"
            ;;
        *)
            # Check ID_LIKE for derivatives
            local id_like="${ID_LIKE:-}"
            if [[ "$id_like" == *"rhel"* || "$id_like" == *"centos"* || "$id_like" == *"fedora"* ]]; then
                OS_FAMILY="rhel"
            elif [[ "$id_like" == *"debian"* || "$id_like" == *"ubuntu"* ]]; then
                OS_FAMILY="debian"
            else
                msg_err "Unsupported OS: $OS_PRETTY"
                msg_info "Supported: CentOS/RHEL/Rocky/Alma 9-10, Ubuntu 22.04/24.04, Debian 12"
                exit 1
            fi
            ;;
    esac

    # Version validation
    case "$OS_FAMILY" in
        rhel)
            local major=${OS_VERSION%%.*}
            if [[ "$major" -lt 9 ]]; then
                msg_warn "OS version $OS_VERSION may not be fully supported (recommended: 9+)"
            fi
            ;;
        debian)
            if [[ "$OS_ID" == "ubuntu" ]]; then
                case "$OS_VERSION" in
                    22.04|24.04|24.10) ;;
                    *) msg_warn "Ubuntu $OS_VERSION may not be fully tested (recommended: 22.04/24.04)" ;;
                esac
            elif [[ "$OS_ID" == "debian" ]]; then
                local major=${OS_VERSION%%.*}
                if [[ "$major" -lt 12 ]]; then
                    msg_warn "Debian $OS_VERSION may not be fully supported (recommended: 12+)"
                fi
            fi
            ;;
    esac

    log "Detected OS: $OS_PRETTY ($OS_FAMILY) on $ARCH"
}

# =============================================================================
# SECTION 6: SYSTEM INFORMATION MODULE
# =============================================================================

show_system_info() {
    msg_header "📋 System Information"

    # Basic system info
    msg "  ${BOLD}Hostname:${RESET}       $(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo 'N/A')"
    msg "  ${BOLD}OS:${RESET}             $OS_PRETTY"
    msg "  ${BOLD}Kernel:${RESET}         $(uname -r)"
    msg "  ${BOLD}Architecture:${RESET}   $ARCH"
    msg "  ${BOLD}Uptime:${RESET}         $(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//')"
    msg ""

    # CPU
    local cpu_model
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "?")
    msg "  ${BOLD}CPU:${RESET}            ${cpu_model:-Unknown} (${cpu_cores} cores)"

    # Memory
    if command_exists free; then
        local mem_total mem_used mem_pct
        mem_total=$(free -h | awk '/^Mem:/{print $2}')
        mem_used=$(free -h | awk '/^Mem:/{print $3}')
        mem_pct=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
        msg "  ${BOLD}Memory:${RESET}         ${mem_used} / ${mem_total} (${mem_pct}%)"
    fi

    # Swap
    if command_exists free; then
        local swap_total
        swap_total=$(free -h | awk '/^Swap:/{print $2}')
        if [[ "$swap_total" == "0B" || "$swap_total" == "0" ]]; then
            msg "  ${BOLD}Swap:${RESET}           ${YELLOW}Not configured${RESET}"
        else
            local swap_used
            swap_used=$(free -h | awk '/^Swap:/{print $3}')
            msg "  ${BOLD}Swap:${RESET}           ${swap_used} / ${swap_total}"
        fi
    fi

    # Disk
    msg "  ${BOLD}Disk (/):${RESET}       $(df -h / | awk 'NR==2{printf "%s / %s (%s used)", $3, $2, $5}')"
    msg ""

    # Network
    local primary_ip
    primary_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || ip -4 addr show scope global 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
    msg "  ${BOLD}Primary IP:${RESET}     ${primary_ip:-N/A}"

    # Timezone
    local tz
    tz=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "Unknown")
    msg "  ${BOLD}Timezone:${RESET}       $tz"
    msg ""

    # Installed tools check
    msg "  ${BOLD}${CYAN}── Installed Tools ──${RESET}"
    local tools=(git docker node npm python3 bat eza fd rg fzf jq btm zoxide glances)
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            local ver
            case "$tool" in
                node)    ver=$(node --version 2>/dev/null) ;;
                python3) ver=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:3])))' 2>/dev/null || python3 --version 2>/dev/null | awk '{print $2}') ;;
                docker)  ver=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1) ;;
                git)     ver=$(git --version 2>/dev/null | awk '{print $3}') ;;
                bat)     ver=$(bat --version 2>/dev/null | awk '{print $2}' | head -1) ;;
                rg)      ver=$(rg --version 2>/dev/null | head -1 | awk '{print $2}') ;;
                btm)     ver=$(btm --version 2>/dev/null | awk '{print $2}') ;;
                *)       ver=$(${tool} --version 2>/dev/null | head -1 | grep -oP '[\d]+\.[\d.]+' | head -1) ;;
            esac
            printf "  ${GREEN}  ✓${RESET} %-12s ${DIM}%s${RESET}\n" "$tool" "${ver:-}"
        else
            printf "  ${DIM}  ○${RESET} %-12s ${DIM}not installed${RESET}\n" "$tool"
        fi
    done
    msg ""

    # Container detection
    if is_container; then
        msg "  ${YELLOW}📦 Running inside a container${RESET}"
        msg ""
    fi
}

# =============================================================================
# SECTION 7: SYSTEM UPDATE & ESSENTIAL PACKAGES
# =============================================================================

module_update_system() {
    msg_header "🔄 System Update & Essential Packages"

    if ! confirm "Update system packages and install essentials?"; then
        msg_info "Skipped"
        return 0
    fi

    # --- System Update ---
    msg_step "Updating all system packages (this may take a while)..."
    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would run full system update"
    else
        case "$OS_FAMILY" in
            rhel)
                dnf update -y 2>&1 | tail -5
                ;;
            debian)
                DEBIAN_FRONTEND=noninteractive apt-get update -qq &>/dev/null
                DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq 2>&1 | tail -5
                ;;
        esac
        msg_ok "System packages updated"
    fi

    # --- EPEL Repository (RHEL family) ---
    if [[ "$OS_FAMILY" == "rhel" ]]; then
        msg_step "Enabling EPEL repository..."
        if ! rpm -q epel-release &>/dev/null; then
            pkg_install epel-release && msg_ok "EPEL repository enabled" || msg_warn "Could not install EPEL"
        else
            msg_skip "EPEL repository"
        fi
        # Enable CRB/PowerTools for additional packages
        dnf config-manager --set-enabled crb &>/dev/null || \
        dnf config-manager --set-enabled powertools &>/dev/null || true
    fi

    # --- Essential Packages ---
    msg_step "Installing essential packages..."
    local common_pkgs=(git curl wget vim tmux screen htop tree unzip zip tar make jq bc)

    case "$OS_FAMILY" in
        rhel)
            local rhel_pkgs=("${common_pkgs[@]}" gcc-c++ python3 python3-pip
                yum-utils device-mapper-persistent-data lvm2 bash-completion
                policycoreutils-python-utils)
            pkg_install "${rhel_pkgs[@]}" && msg_ok "Essential packages installed"
            ;;
        debian)
            local deb_pkgs=("${common_pkgs[@]}" build-essential python3 python3-pip
                software-properties-common apt-transport-https ca-certificates
                gnupg lsb-release bash-completion)
            pkg_install "${deb_pkgs[@]}" && msg_ok "Essential packages installed"
            ;;
    esac

    msg_done "System update & essentials complete"
}

# =============================================================================
# SECTION 8: NETWORK DIAGNOSTIC TOOLS
# =============================================================================

module_network_tools() {
    msg_header "🌐 Network Diagnostic Tools"

    if ! confirm "Install network diagnostic tools (dig, mtr, nmap, etc.)?"; then
        msg_info "Skipped"
        return 0
    fi

    msg_step "Installing network tools..."
    case "$OS_FAMILY" in
        rhel)
            pkg_install bind-utils net-tools traceroute mtr nmap iperf3 \
                tcpdump whois socat telnet
            ;;
        debian)
            pkg_install dnsutils net-tools traceroute mtr-tiny nmap iperf3 \
                tcpdump whois socat inetutils-telnet
            ;;
    esac

    # Verify key tools
    local net_tools=(dig traceroute mtr nmap iperf3 tcpdump whois socat)
    local installed=0 total=${#net_tools[@]}
    for tool in "${net_tools[@]}"; do
        if command_exists "$tool"; then
            ((installed++))
        fi
    done

    msg_ok "Network tools installed ($installed/$total available)"
    msg_done "Network diagnostic tools complete"
}

# =============================================================================
# SECTION 9: MODERN CLI TOOLS
# =============================================================================

module_modern_tools() {
    msg_header "🛠️  Modern CLI Tools"

    msg "  This will install modern replacements for common Unix commands:"
    msg ""
    msg "  ${CYAN}bat${RESET}        → better cat with syntax highlighting"
    msg "  ${CYAN}eza${RESET}        → better ls with git integration"
    msg "  ${CYAN}fd${RESET}         → better find, intuitive syntax"
    msg "  ${CYAN}ripgrep${RESET}    → better grep, blazing fast"
    msg "  ${CYAN}fzf${RESET}        → fuzzy finder for everything"
    msg "  ${CYAN}jq/yq${RESET}      → JSON/YAML processors"
    msg "  ${CYAN}bottom${RESET}     → better top/htop system monitor"
    msg "  ${CYAN}dust${RESET}       → better du, intuitive disk usage"
    msg "  ${CYAN}duf${RESET}        → better df, disk free overview"
    msg "  ${CYAN}ncdu${RESET}       → interactive disk usage analyzer"
    msg "  ${CYAN}zoxide${RESET}     → smarter cd that learns"
    msg "  ${CYAN}gping${RESET}      → ping with live graph"
    msg "  ${CYAN}fastfetch${RESET}  → system info display"
    msg "  ${CYAN}glances${RESET}    → advanced system monitoring dashboard"
    msg "  ${CYAN}lazydocker${RESET} → Docker TUI manager"
    msg "  ${CYAN}lazygit${RESET}    → Git TUI manager"
    msg ""

    if ! confirm "Install modern CLI tools?"; then
        msg_info "Skipped"
        return 0
    fi

    # --- Package Manager Tools ---
    msg_step "Installing tools from package manager..."

    case "$OS_FAMILY" in
        rhel)
            pkg_install ripgrep fzf htop ncdu
            # bat and fd-find may be in EPEL
            pkg_install bat 2>/dev/null || true
            pkg_install fd-find 2>/dev/null || true
            ;;
        debian)
            pkg_install ripgrep fzf htop ncdu
            # bat is 'bat' but binary is 'batcat' on Debian/Ubuntu
            if ! command_exists bat; then
                pkg_install bat 2>/dev/null || true
                # Create symlink: batcat → bat
                if command_exists batcat && ! command_exists bat; then
                    ln -sf "$(which batcat)" /usr/local/bin/bat
                    msg_info "Created symlink: bat → batcat"
                fi
            fi
            # fd-find binary is 'fdfind' on Debian/Ubuntu
            if ! command_exists fd; then
                pkg_install fd-find 2>/dev/null || true
                if command_exists fdfind && ! command_exists fd; then
                    ln -sf "$(which fdfind)" /usr/local/bin/fd
                    msg_info "Created symlink: fd → fdfind"
                fi
            fi
            # eza may be in Ubuntu 24.04+ repos
            pkg_install eza 2>/dev/null || true
            # duf may be in newer repos
            pkg_install duf 2>/dev/null || true
            ;;
    esac

    # --- GitHub Release Tools ---
    msg_step "Installing tools from GitHub releases..."

    # bat (if not installed via package manager)
    if ! command_exists bat; then
        case "$OS_FAMILY" in
            rhel)
                install_github_binary "bat" "sharkdp/bat" "bat" \
                    "https://github.com/sharkdp/bat/releases/download/{TAG}/bat-{TAG}-{ARCH}-unknown-linux-gnu.tar.gz" "tar"
                ;;
            debian)
                install_github_binary "bat" "sharkdp/bat" "bat" \
                    "https://github.com/sharkdp/bat/releases/download/{TAG}/bat_{VER}_{ARCH_ALT}.deb" "deb"
                # Ensure symlink exists
                command_exists batcat && ! command_exists bat && ln -sf "$(which batcat)" /usr/local/bin/bat
                ;;
        esac
    fi

    # eza (if not installed via package manager)
    if ! command_exists eza; then
        install_github_binary "eza" "eza-community/eza" "eza" \
            "https://github.com/eza-community/eza/releases/download/{TAG}/eza_{ARCH}-unknown-linux-gnu.tar.gz" "tar"
    fi

    # fd (if not installed via package manager)
    if ! command_exists fd; then
        case "$OS_FAMILY" in
            rhel)
                install_github_binary "fd" "sharkdp/fd" "fd" \
                    "https://github.com/sharkdp/fd/releases/download/{TAG}/fd-{TAG}-{ARCH}-unknown-linux-gnu.tar.gz" "tar"
                ;;
            debian)
                install_github_binary "fd" "sharkdp/fd" "fd" \
                    "https://github.com/sharkdp/fd/releases/download/{TAG}/fd_{VER}_{ARCH_ALT}.deb" "deb"
                command_exists fdfind && ! command_exists fd && ln -sf "$(which fdfind)" /usr/local/bin/fd
                ;;
        esac
    fi

    # bottom (btm)
    install_github_binary "bottom" "ClementTsang/bottom" "btm" \
        "https://github.com/ClementTsang/bottom/releases/download/{TAG}/bottom_{ARCH}-unknown-linux-gnu.tar.gz" "tar"

    # dust
    install_github_binary "dust" "bootandy/dust" "dust" \
        "https://github.com/bootandy/dust/releases/download/{TAG}/dust-{TAG}-{ARCH}-unknown-linux-gnu.tar.gz" "tar"

    # duf (if not installed)
    if ! command_exists duf; then
        case "$OS_FAMILY" in
            rhel)
                install_github_binary "duf" "muesli/duf" "duf" \
                    "https://github.com/muesli/duf/releases/download/{TAG}/duf_{VER}_linux_{ARCH_ALT}.rpm" "rpm"
                ;;
            debian)
                install_github_binary "duf" "muesli/duf" "duf" \
                    "https://github.com/muesli/duf/releases/download/{TAG}/duf_{VER}_linux_{ARCH_ALT}.deb" "deb"
                ;;
        esac
    fi

    # zoxide
    install_github_binary "zoxide" "ajeetdsouza/zoxide" "zoxide" \
        "https://github.com/ajeetdsouza/zoxide/releases/download/{TAG}/zoxide-{VER}-{ARCH}-unknown-linux-musl.tar.gz" "tar"

    # yq (YAML processor)
    install_github_binary "yq" "mikefarah/yq" "yq" \
        "https://github.com/mikefarah/yq/releases/download/{TAG}/yq_linux_{ARCH_ALT}" "binary"

    # gping (note: tag format is gping-vX.Y.Z, asset uses Linux-gnu-arch)
    install_github_binary "gping" "orf/gping" "gping" \
        "https://github.com/orf/gping/releases/download/{TAG}/gping-Linux-gnu-{ARCH_GH}.tar.gz" "tar"

    # fastfetch (uses amd64/aarch64 naming)
    case "$OS_FAMILY" in
        rhel)
            install_github_binary "fastfetch" "fastfetch-cli/fastfetch" "fastfetch" \
                "https://github.com/fastfetch-cli/fastfetch/releases/download/{TAG}/fastfetch-linux-{ARCH_FP}.rpm" "rpm"
            ;;
        debian)
            install_github_binary "fastfetch" "fastfetch-cli/fastfetch" "fastfetch" \
                "https://github.com/fastfetch-cli/fastfetch/releases/download/{TAG}/fastfetch-linux-{ARCH_FP}.deb" "deb"
            ;;
    esac

    # lazydocker (uses x86_64/arm64 naming)
    install_github_binary "lazydocker" "jesseduffield/lazydocker" "lazydocker" \
        "https://github.com/jesseduffield/lazydocker/releases/download/{TAG}/lazydocker_{VER}_Linux_{ARCH_GH}.tar.gz" "tar"

    # lazygit (uses x86_64/arm64 naming)
    install_github_binary "lazygit" "jesseduffield/lazygit" "lazygit" \
        "https://github.com/jesseduffield/lazygit/releases/download/{TAG}/lazygit_{VER}_Linux_{ARCH_GH}.tar.gz" "tar"

    # --- Glances (system monitor) ---
    if ! command_exists glances; then
        msg_step "Installing glances (system monitor)..."
        local glances_installed=false

        # Try package manager first (EPEL on RHEL, universe on Ubuntu)
        if pkg_install glances 2>/dev/null && command_exists glances; then
            glances_installed=true
        fi

        # Fallback: pipx (handles PEP 668 cleanly)
        if [[ "$glances_installed" == false ]]; then
            if [[ "$DRY_RUN" != true ]]; then
                msg_info "Trying pipx fallback..."
                pkg_install pipx 2>/dev/null || true
                if command_exists pipx; then
                    pipx install glances &>/dev/null && glances_installed=true
                fi
            fi
        fi

        if [[ "$glances_installed" == true ]]; then
            msg_ok "glances installed"
        else
            msg_warn "glances could not be installed (try: pipx install glances)"
        fi
    else
        msg_skip "glances"
    fi

    # --- Shell Integration ---
    msg_step "Setting up shell enhancements..."
    setup_shell_enhancements

    msg_done "Modern CLI tools installation complete"
}

setup_shell_enhancements() {
    local profile_file="/etc/profile.d/fta-modern-tools.sh"

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would create $profile_file"
        return 0
    fi

    cat > "$profile_file" << 'SHELL_EOF'
# =============================================================================
# FTA Server Toolbox — Modern Tool Enhancements
# Safe aliases that don't break scripts (only apply in interactive shells)
# =============================================================================

# Only apply for interactive shells
[[ $- != *i* ]] && return

# Modern ls with eza (if available)
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first'
    alias lt='eza --tree --icons --level=2'
fi

# Better cat with bat (if available)
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never --style=plain'
    alias bcat='bat'  # full bat with paging
fi

# Better du with dust (if available)
command -v dust &>/dev/null && alias du='dust'

# Better df with duf (if available)
command -v duf &>/dev/null && alias df='duf'

# Smarter cd with zoxide (if available)
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
fi

# fzf integration (if available)
if command -v fzf &>/dev/null; then
    # Ctrl+R for fuzzy history search
    if [[ -f /usr/share/fzf/shell/key-bindings.bash ]]; then
        source /usr/share/fzf/shell/key-bindings.bash
    elif [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
        source /usr/share/doc/fzf/examples/key-bindings.bash
    fi
fi
SHELL_EOF

    chmod 644 "$profile_file"
    msg_ok "Shell enhancements configured in $profile_file"
    msg_info "Aliases will activate on next login (or run: source $profile_file)"
}

# =============================================================================
# SECTION 10: NODE.JS MODULE
# =============================================================================

module_nodejs() {
    msg_header "💚 Node.js Installation"

    if command_exists node; then
        local current_ver
        current_ver=$(node --version 2>/dev/null)
        msg_info "Node.js $current_ver is already installed"
        if ! confirm "Reinstall/update Node.js?" "N"; then
            return 0
        fi
    else
        if ! confirm "Install Node.js LTS?"; then
            msg_info "Skipped"
            return 0
        fi
    fi

    # Let user choose version
    msg ""
    msg "  Available Node.js versions:"
    msg "    ${CYAN}1${RESET}) Node.js 22 LTS  ${GREEN}(Recommended)${RESET}"
    msg "    ${CYAN}2${RESET}) Node.js 20 LTS"
    msg "    ${CYAN}3${RESET}) Node.js 24 (Latest)"
    msg ""

    local node_version="22"
    if [[ "$AUTO_YES" != true ]]; then
        read -rp "  Select version [1]: " nv_choice
        case "${nv_choice:-1}" in
            2) node_version="20" ;;
            3) node_version="24" ;;
            *) node_version="22" ;;
        esac
    fi

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would install Node.js ${node_version}.x"
        return 0
    fi

    msg_step "Installing Node.js ${node_version}.x LTS..."

    case "$OS_FAMILY" in
        rhel)
            # Remove old NodeSource config if present
            rm -f /etc/yum.repos.d/nodesource*.repo 2>/dev/null
            # Install via NodeSource
            curl -fsSL "https://rpm.nodesource.com/setup_${node_version}.x" | bash - &>/dev/null
            dnf install -y nodejs &>/dev/null
            ;;
        debian)
            # Remove old NodeSource config if present
            rm -f /etc/apt/sources.list.d/nodesource*.list 2>/dev/null
            rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null
            # Install via NodeSource
            curl -fsSL "https://deb.nodesource.com/setup_${node_version}.x" | bash - &>/dev/null
            DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs &>/dev/null
            ;;
    esac

    if command_exists node; then
        msg_ok "Node.js $(node --version) installed"
        msg_ok "npm $(npm --version) included"

        # Install useful global npm packages
        if confirm "Install useful global npm tools (yarn, pnpm, npx)?"; then
            npm install -g yarn pnpm &>/dev/null
            msg_ok "yarn and pnpm installed globally"
        fi
    else
        msg_err "Node.js installation failed"
        return 1
    fi

    msg_done "Node.js setup complete"
}

# =============================================================================
# SECTION 11: DOCKER MODULE
# =============================================================================

module_docker() {
    msg_header "🐳 Docker Engine"

    if command_exists docker; then
        local docker_ver
        docker_ver=$(docker --version 2>/dev/null)
        msg_info "Docker is already installed: $docker_ver"
        if ! confirm "Reinstall Docker?" "N"; then
            return 0
        fi
    else
        if ! confirm "Install Docker Engine?"; then
            msg_info "Skipped"
            return 0
        fi
    fi

    if is_container; then
        msg_warn "Running inside a container — Docker-in-Docker is not supported"
        msg_info "Skipping Docker installation"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would install Docker Engine"
        return 0
    fi

    # --- Remove old Docker versions ---
    msg_step "Removing old Docker versions (if any)..."
    case "$OS_FAMILY" in
        rhel)
            dnf remove -y docker docker-client docker-client-latest docker-common \
                docker-latest docker-latest-logrotate docker-logrotate docker-engine \
                podman buildah &>/dev/null || true
            ;;
        debian)
            apt-get remove -y docker docker-engine docker.io containerd runc &>/dev/null || true
            ;;
    esac

    # --- Setup Repository ---
    msg_step "Setting up Docker repository..."
    case "$OS_FAMILY" in
        rhel)
            dnf install -y yum-utils &>/dev/null
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo &>/dev/null
            dnf makecache -q &>/dev/null
            ;;
        debian)
            # Add Docker GPG key
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc

            # Add Docker repo
            local codename
            codename=$(. /etc/os-release && echo "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}")
            echo "deb [arch=${ARCH_ALT} signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/${OS_ID} ${codename} stable" \
                > /etc/apt/sources.list.d/docker.list
            apt-get update -qq &>/dev/null
            ;;
    esac

    # --- Install Docker ---
    msg_step "Installing Docker Engine..."
    case "$OS_FAMILY" in
        rhel)
            dnf install -y docker-ce docker-ce-cli containerd.io \
                docker-buildx-plugin docker-compose-plugin &>/dev/null
            ;;
        debian)
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                docker-ce docker-ce-cli containerd.io \
                docker-buildx-plugin docker-compose-plugin &>/dev/null
            ;;
    esac

    # --- Start & Enable ---
    msg_step "Starting Docker service..."
    systemctl start docker &>/dev/null
    systemctl enable docker &>/dev/null

    # --- Verify ---
    if command_exists docker; then
        msg_ok "Docker $(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1) installed"
        msg_ok "Docker Compose $(docker compose version --short 2>/dev/null || echo 'plugin') included"
        msg_info "💡 Add your user to docker group: sudo usermod -aG docker \$USER"
    else
        msg_err "Docker installation failed"
        return 1
    fi

    msg_done "Docker Engine setup complete"
}

# =============================================================================
# SECTION 12: PORTAINER & WATCHTOWER
# =============================================================================

_require_docker() {
    if ! command_exists docker; then
        msg_err "Docker is not installed — please install Docker first (option 6)"
        return 1
    fi
    if ! systemctl is-active docker &>/dev/null 2>&1 && ! docker info &>/dev/null 2>&1; then
        msg_err "Docker is not running"
        return 1
    fi
    return 0
}

module_portainer() {
    msg_header "🏗️  Portainer (Docker UI)"

    _require_docker || return 1

    if ! confirm "Deploy Portainer (Docker UI)?"; then
        msg_info "Skipped"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would deploy Portainer container"
        return 0
    fi

    local portainer_name="portainer"
    if docker ps -a --format '{{.Names}}' | grep -q "^${portainer_name}$"; then
        msg_warn "Portainer container already exists"
        msg_info "To reinstall: docker stop portainer && docker rm portainer"
    else
        msg_step "Deploying Portainer CE..."
        docker volume create portainer_data &>/dev/null || true

        docker run -d \
            --name "$portainer_name" \
            --restart always \
            -p 9443:9443 \
            -p 8000:8000 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data \
            --label com.centurylinklabs.watchtower.enable=true \
            portainer/portainer-ce:latest &>/dev/null

        if docker ps --format '{{.Names}}' | grep -q "^${portainer_name}$"; then
            local server_ip
            server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
            msg_ok "Portainer deployed"
            msg_info "Access UI: https://${server_ip:-localhost}:9443"
        else
            msg_err "Failed to start Portainer"
        fi
    fi

    msg_done "Portainer setup complete"
}

module_watchtower() {
    msg_header "👀 Watchtower (Auto-updater)"

    _require_docker || return 1

    if ! confirm "Deploy Watchtower (automatic container updates)?"; then
        msg_info "Skipped"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would deploy Watchtower container"
        return 0
    fi

    # Ensure docker config exists for Watchtower
    local docker_config="/root/.docker/config.json"
    if [[ ! -f "$docker_config" ]]; then
        mkdir -p /root/.docker
        echo '{}' > "$docker_config"
    fi

    local watchtower_name="watchtower"
    if docker ps -a --format '{{.Names}}' | grep -q "^${watchtower_name}$"; then
        msg_warn "Watchtower container already exists"
        msg_info "To reinstall: docker stop watchtower && docker rm watchtower"
    else
        msg_step "Deploying Watchtower..."
        docker run -d \
            --name "$watchtower_name" \
            --restart always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$docker_config":/config.json \
            -e WATCHTOWER_CLEANUP=true \
            -e WATCHTOWER_INCLUDE_STOPPED=true \
            -e WATCHTOWER_REVIVE_STOPPED=true \
            -e WATCHTOWER_POLL_INTERVAL=300 \
            -e WATCHTOWER_LABEL_ENABLE=true \
            containrrr/watchtower:latest &>/dev/null

        if docker ps --format '{{.Names}}' | grep -q "^${watchtower_name}$"; then
            msg_ok "Watchtower deployed (checking for updates every 5 min)"
        else
            msg_err "Failed to start Watchtower"
        fi
    fi

    msg_done "Watchtower setup complete"
}

# =============================================================================
# SECTION 13: SECURITY HARDENING
# =============================================================================

module_security() {
    msg_header "🔒 Security Hardening"

    msg "  This module will:"
    msg "    • Harden SSH configuration"
    msg "    • Configure firewall (firewalld/ufw)"
    msg "    • Install fail2ban"
    msg ""

    if ! confirm "Apply security hardening?"; then
        msg_info "Skipped"
        return 0
    fi

    # --- SSH Hardening ---
    if confirm "  Harden SSH configuration?"; then
        harden_ssh
    fi

    # --- Firewall ---
    if ! is_container; then
        if confirm "  Configure firewall?"; then
            configure_firewall
        fi
    else
        msg_info "Skipping firewall (container environment)"
    fi

    # --- fail2ban ---
    if confirm "  Install fail2ban (brute-force protection)?"; then
        install_fail2ban
    fi

    msg_done "Security hardening complete"
}

harden_ssh() {
    local sshd_config="/etc/ssh/sshd_config"
    local sshd_custom="/etc/ssh/sshd_config.d/99-fta-hardening.conf"

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would harden SSH configuration"
        return 0
    fi

    # Ensure OpenSSH server is installed
    if [[ ! -f "$sshd_config" ]]; then
        msg_info "OpenSSH server not found — installing..."
        case "$OS_FAMILY" in
            rhel)   pkg_install openssh-server ;;
            debian) pkg_install openssh-server ;;
        esac
        if [[ ! -f "$sshd_config" ]]; then
            msg_warn "SSH server not available — skipping SSH hardening"
            return 0
        fi
    fi

    backup_file "$sshd_config"

    msg_step "Hardening SSH configuration..."

    # Use sshd_config.d drop-in if supported (OpenSSH 8.2+)
    local use_dropin=false
    if [[ -d /etc/ssh/sshd_config.d ]] && grep -q "^Include" "$sshd_config" 2>/dev/null; then
        use_dropin=true
    fi

    local ssh_config_content="# FTA Server Toolbox — SSH Hardening
# Applied: $(date '+%Y-%m-%d %H:%M:%S')

# Disable password authentication for empty passwords
PermitEmptyPasswords no

# Disable DNS lookups (faster connections)
UseDNS no

# Disable GSSAPI (faster connections if not using Kerberos)
GSSAPIAuthentication no

# Allow root login only with SSH keys
PermitRootLogin prohibit-password

# Enable public key authentication
PubkeyAuthentication yes

# Disable X11 forwarding (unless needed)
X11Forwarding no

# Set login grace time
LoginGraceTime 60

# Limit authentication attempts
MaxAuthTries 4

# Disable TCP forwarding (uncomment if not needed)
# AllowTcpForwarding no

# Client alive settings (disconnect idle sessions after 10 min)
ClientAliveInterval 300
ClientAliveCountMax 2
"

    if [[ "$use_dropin" == true ]]; then
        echo "$ssh_config_content" > "$sshd_custom"
        chmod 600 "$sshd_custom"
        msg_info "SSH hardening applied via drop-in: $sshd_custom"
    else
        # Apply settings directly to sshd_config
        local settings=(
            "PermitEmptyPasswords no"
            "UseDNS no"
            "GSSAPIAuthentication no"
            "PermitRootLogin prohibit-password"
            "PubkeyAuthentication yes"
            "X11Forwarding no"
            "LoginGraceTime 60"
            "MaxAuthTries 4"
            "ClientAliveInterval 300"
            "ClientAliveCountMax 2"
        )
        for setting in "${settings[@]}"; do
            local key=${setting%% *}
            if grep -q "^#*\s*${key}" "$sshd_config"; then
                sed -i "s/^#*\s*${key}.*/${setting}/" "$sshd_config"
            else
                echo "$setting" >> "$sshd_config"
            fi
        done
        msg_info "SSH hardening applied to $sshd_config"
    fi

    # Restart SSH
    if ! is_container; then
        if systemctl restart sshd &>/dev/null || systemctl restart ssh &>/dev/null; then
            msg_ok "SSH service restarted"
        else
            msg_warn "Could not restart SSH service"
        fi
    fi

    msg_ok "SSH hardened"
    msg_warn "⚠  Ensure you have SSH key access before disconnecting!"
}

configure_firewall() {
    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would configure firewall"
        return 0
    fi

    msg_step "Configuring firewall..."

    case "$OS_FAMILY" in
        rhel)
            # firewalld
            if ! command_exists firewall-cmd; then
                pkg_install firewalld
            fi
            systemctl start firewalld &>/dev/null
            systemctl enable firewalld &>/dev/null

            # Allow essential services
            firewall-cmd --permanent --add-service=ssh &>/dev/null
            firewall-cmd --permanent --add-service=http &>/dev/null
            firewall-cmd --permanent --add-service=https &>/dev/null

            # Allow Portainer if Docker is installed
            if command_exists docker; then
                firewall-cmd --permanent --add-port=9443/tcp &>/dev/null
            fi

            firewall-cmd --reload &>/dev/null
            msg_ok "firewalld configured (SSH, HTTP, HTTPS allowed)"
            msg_info "Add more rules: firewall-cmd --permanent --add-port=PORT/tcp"
            ;;
        debian)
            # ufw
            if ! command_exists ufw; then
                pkg_install ufw
            fi
            ufw default deny incoming &>/dev/null
            ufw default allow outgoing &>/dev/null
            ufw allow ssh &>/dev/null
            ufw allow http &>/dev/null
            ufw allow https &>/dev/null

            if command_exists docker; then
                ufw allow 9443/tcp &>/dev/null
            fi

            echo "y" | ufw enable &>/dev/null
            msg_ok "ufw configured (SSH, HTTP, HTTPS allowed)"
            msg_info "Add more rules: ufw allow PORT/tcp"
            ;;
    esac
}

install_fail2ban() {
    if command_exists fail2ban-client; then
        msg_skip "fail2ban"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would install fail2ban"
        return 0
    fi

    msg_step "Installing fail2ban..."
    pkg_install fail2ban

    if ! command_exists fail2ban-client; then
        msg_warn "fail2ban not available in repositories — skipping"
        return 0
    fi

    # Create local configuration
    mkdir -p /etc/fail2ban
    local jail_local="/etc/fail2ban/jail.local"
    if [[ ! -f "$jail_local" ]]; then
        cat > "$jail_local" << 'F2B_EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = auto

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
maxretry = 3
F2B_EOF
        # Adjust logpath for RHEL
        if [[ "$OS_FAMILY" == "rhel" ]]; then
            sed -i 's|/var/log/auth.log|/var/log/secure|' "$jail_local"
        fi
    fi

    if ! is_container; then
        systemctl enable fail2ban &>/dev/null
        systemctl start fail2ban &>/dev/null
    fi

    msg_ok "fail2ban installed and configured"
}

# =============================================================================
# SECTION 14: PERFORMANCE TUNING
# =============================================================================

module_performance() {
    msg_header "⚡ Performance Tuning"

    msg "  This module will optimize:"
    msg "    • Kernel network parameters (TCP BBR, buffers)"
    msg "    • System file descriptor limits"
    msg "    • I/O and memory settings"
    msg ""

    if ! confirm "Apply performance tuning?"; then
        msg_info "Skipped"
        return 0
    fi

    if is_container; then
        msg_warn "Running inside a container — kernel tuning will be limited"
        if ! confirm "  Continue with available tuning?" "N"; then
            return 0
        fi
    fi

    # --- Kernel Parameters ---
    if confirm "  Tune kernel network parameters (TCP BBR, buffers)?"; then
        tune_kernel
    fi

    # --- System Limits ---
    if confirm "  Increase system file descriptor limits?"; then
        tune_limits
    fi

    msg_done "Performance tuning complete"
}

tune_kernel() {
    local sysctl_file="/etc/sysctl.d/99-fta-performance.conf"

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would apply kernel tuning to $sysctl_file"
        return 0
    fi

    msg_step "Applying kernel parameter tuning..."

    # Ensure directory exists
    mkdir -p /etc/sysctl.d 2>/dev/null || true

    # Check BBR availability
    local bbr_available=true
    if ! grep -q 'bbr' /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
        # Try to load the module
        modprobe tcp_bbr 2>/dev/null || bbr_available=false
    fi

    cat > "$sysctl_file" << 'SYSCTL_EOF'
# =============================================================================
# FTA Server Toolbox — Performance Tuning
# =============================================================================

# --- Network Performance ---
# Enable IP forwarding (required for Docker/containers)
net.ipv4.ip_forward = 1

# Increase connection backlog
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# TCP connection optimization
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Increase max TIME_WAIT sockets
net.ipv4.tcp_max_tw_buckets = 2000000

# --- Buffer Sizes ---
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_mem = 786432 1048576 26777216

# --- Congestion Control ---
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# --- Memory ---
vm.overcommit_memory = 1
vm.swappiness = 10
vm.dirty_ratio = 60
vm.dirty_background_ratio = 2

# --- Security (network) ---
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
SYSCTL_EOF

    # If BBR is not available, comment it out
    if [[ "$bbr_available" == false ]]; then
        sed -i 's/^net.ipv4.tcp_congestion_control/#&/' "$sysctl_file"
        sed -i 's/^net.core.default_qdisc/#&/' "$sysctl_file"
        msg_warn "BBR not available on this kernel — skipped congestion control"
    fi

    # Apply settings
    if ! is_container; then
        sysctl -p "$sysctl_file" &>/dev/null && msg_ok "Kernel parameters applied"
    else
        msg_info "Kernel parameters saved to $sysctl_file (will apply on next boot on bare metal)"
    fi
}

tune_limits() {
    local limits_file="/etc/security/limits.d/99-fta-limits.conf"

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would apply system limits to $limits_file"
        return 0
    fi

    msg_step "Configuring system limits..."

    mkdir -p /etc/security/limits.d 2>/dev/null || true
    cat > "$limits_file" << 'LIMITS_EOF'
# FTA Server Toolbox — System Limits
*     soft    nofile    1048576
*     hard    nofile    1048576
*     soft    nproc     65536
*     hard    nproc     65536
root  soft    nofile    1048576
root  hard    nofile    1048576
root  soft    nproc     65536
root  hard    nproc     65536
LIMITS_EOF

    # Also update systemd defaults if present
    local systemd_conf="/etc/systemd/system.conf"
    if [[ -f "$systemd_conf" ]] && ! is_container; then
        backup_file "$systemd_conf"
        if ! grep -q "DefaultLimitNOFILE=1048576" "$systemd_conf"; then
            sed -i 's/^#*DefaultLimitNOFILE=.*/DefaultLimitNOFILE=1048576/' "$systemd_conf" 2>/dev/null || \
                echo "DefaultLimitNOFILE=1048576" >> "$systemd_conf"
        fi
        systemctl daemon-reload &>/dev/null || true
    fi

    msg_ok "System limits configured (nofile: 1048576, nproc: 65536)"
}

# =============================================================================
# SECTION 15: TIMEZONE MODULE
# =============================================================================

module_timezone() {
    msg_header "🕐 Timezone & NTP Configuration"

    if is_container; then
        msg_warn "Timezone changes in containers may not persist"
    fi

    local current_tz
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "Unknown")
    msg_info "Current timezone: ${BOLD}$current_tz${RESET}"
    msg ""

    if ! confirm "Configure timezone?"; then
        msg_info "Skipped"
        return 0
    fi

    msg ""
    msg "  Select timezone:"
    msg "    ${CYAN}1${RESET}) America/New_York      (US Eastern)"
    msg "    ${CYAN}2${RESET}) America/Chicago        (US Central)"
    msg "    ${CYAN}3${RESET}) America/Denver         (US Mountain)"
    msg "    ${CYAN}4${RESET}) America/Los_Angeles    (US Pacific)"
    msg "    ${CYAN}5${RESET}) UTC"
    msg "    ${CYAN}6${RESET}) Europe/London"
    msg "    ${CYAN}7${RESET}) Europe/Berlin"
    msg "    ${CYAN}8${RESET}) Asia/Shanghai"
    msg "    ${CYAN}9${RESET}) Asia/Tokyo"
    msg "    ${CYAN}0${RESET}) Custom (enter manually)"
    msg ""

    local target_tz=""
    if [[ "$AUTO_YES" == true ]]; then
        target_tz="UTC"
    else
        read -rp "  Select [5]: " tz_choice
        case "${tz_choice:-5}" in
            1) target_tz="America/New_York" ;;
            2) target_tz="America/Chicago" ;;
            3) target_tz="America/Denver" ;;
            4) target_tz="America/Los_Angeles" ;;
            5) target_tz="UTC" ;;
            6) target_tz="Europe/London" ;;
            7) target_tz="Europe/Berlin" ;;
            8) target_tz="Asia/Shanghai" ;;
            9) target_tz="Asia/Tokyo" ;;
            0)
                read -rp "  Enter timezone (e.g., Asia/Tokyo): " target_tz
                ;;
            *) target_tz="UTC" ;;
        esac
    fi

    if [[ -z "$target_tz" ]]; then
        msg_warn "No timezone selected"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would set timezone to $target_tz"
        return 0
    fi

    if [[ "$current_tz" == "$target_tz" ]]; then
        msg_ok "Timezone is already set to $target_tz"
    else
        timedatectl set-timezone "$target_tz" 2>/dev/null || \
            ln -sf "/usr/share/zoneinfo/$target_tz" /etc/localtime
        msg_ok "Timezone set to $target_tz"
    fi

    # --- NTP Sync ---
    msg_step "Ensuring NTP time synchronization..."
    if ! is_container; then
        case "$OS_FAMILY" in
            rhel)
                if systemctl is-active chronyd &>/dev/null; then
                    msg_skip "chronyd (already active)"
                else
                    systemctl enable --now chronyd &>/dev/null
                    msg_ok "chronyd enabled and started"
                fi
                ;;
            debian)
                timedatectl set-ntp true &>/dev/null 2>&1 || true
                if systemctl is-active systemd-timesyncd &>/dev/null; then
                    msg_ok "NTP synchronization active"
                elif systemctl is-active chronyd &>/dev/null; then
                    msg_ok "chronyd active"
                else
                    pkg_install chrony &>/dev/null
                    systemctl enable --now chronyd &>/dev/null || true
                    msg_ok "chrony installed and started"
                fi
                ;;
        esac
    else
        msg_info "NTP configuration skipped (container environment)"
    fi

    msg_done "Timezone & NTP configuration complete"
}

# =============================================================================
# SECTION 16: SWAP MODULE
# =============================================================================

module_swap() {
    msg_header "💾 Swap Management"

    if is_container; then
        msg_warn "Swap configuration inside containers is not supported"
        return 0
    fi

    # Show current swap
    local swap_total
    swap_total=$(free -m | awk '/^Swap:/{print $2}')
    if [[ "$swap_total" -gt 0 ]]; then
        msg_info "Current swap: $(free -h | awk '/^Swap:/{printf "%s total, %s used", $2, $3}')"
    else
        msg_info "No swap currently configured"
    fi

    msg ""
    if ! confirm "Configure swap?"; then
        msg_info "Skipped"
        return 0
    fi

    # Recommend swap size based on RAM
    local ram_mb
    ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    local recommended_gb=2
    if [[ "$ram_mb" -le 2048 ]]; then
        recommended_gb=2
    elif [[ "$ram_mb" -le 8192 ]]; then
        recommended_gb=4
    elif [[ "$ram_mb" -le 16384 ]]; then
        recommended_gb=8
    else
        recommended_gb=8
    fi

    msg_info "System RAM: $(free -h | awk '/^Mem:/{print $2}')"
    msg_info "Recommended swap: ${recommended_gb}G"
    msg ""

    local swap_size="${recommended_gb}G"
    if [[ "$AUTO_YES" != true ]]; then
        read -rp "  Enter swap size (e.g., 2G, 4G) [${recommended_gb}G]: " user_swap
        [[ -n "$user_swap" ]] && swap_size="$user_swap"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would create ${swap_size} swap file"
        return 0
    fi

    local swap_file="/swapfile"

    # Remove existing swap if needed
    if [[ -f "$swap_file" ]]; then
        if confirm "  Existing swap file found. Replace it?" "N"; then
            swapoff "$swap_file" 2>/dev/null || true
            rm -f "$swap_file"
        else
            msg_info "Keeping existing swap"
            return 0
        fi
    fi

    msg_step "Creating ${swap_size} swap file..."

    # Use fallocate (faster) or dd
    if command_exists fallocate; then
        fallocate -l "$swap_size" "$swap_file" 2>/dev/null || \
            dd if=/dev/zero of="$swap_file" bs=1M count=$((${swap_size%G} * 1024)) status=progress 2>/dev/null
    else
        dd if=/dev/zero of="$swap_file" bs=1M count=$((${swap_size%G} * 1024)) status=progress 2>/dev/null
    fi

    chmod 600 "$swap_file"
    mkswap "$swap_file" &>/dev/null
    swapon "$swap_file" &>/dev/null

    # Add to fstab if not present
    if ! grep -q "$swap_file" /etc/fstab 2>/dev/null; then
        backup_file /etc/fstab
        echo "$swap_file  none  swap  sw  0  0" >> /etc/fstab
    fi

    msg_ok "Swap file created and activated: $swap_size"
    msg_info "Current swap: $(free -h | awk '/^Swap:/{printf "%s total", $2}')"

    msg_done "Swap configuration complete"
}

# =============================================================================
# SECTION 17: DNS MODULE
# =============================================================================

# Configure DNS resolver servers.
# Supports five presets (Cloudflare, Google, OpenDNS, DNSPod, DigitalOcean)
# plus manual custom entry.  Applies changes through the appropriate backend:
#   - systemd-resolved  → /etc/systemd/resolved.conf (Ubuntu / modern Debian)
#   - NetworkManager    → nmcli (RHEL family)
#   - fallback          → /etc/resolv.conf direct write
# Original config is backed up before any modification.
module_dns() {
    msg_header "🌍 DNS Configuration"

    # --- Show current DNS ---
    local current_dns=""
    if command_exists resolvectl && systemctl is-active systemd-resolved &>/dev/null; then
        current_dns=$(resolvectl dns 2>/dev/null | head -5)
    elif [[ -f /etc/resolv.conf ]]; then
        current_dns=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd ', ')
    fi

    if [[ -n "$current_dns" ]]; then
        msg_info "Current DNS: ${BOLD}${current_dns}${RESET}"
    else
        msg_info "Current DNS: Unknown"
    fi
    msg ""

    if ! confirm "Configure DNS servers?"; then
        msg_info "Skipped"
        return 0
    fi

    msg ""
    msg "  Select DNS preset:"
    msg "    ${CYAN}1${RESET}) Cloudflare       (1.1.1.1 / 1.0.0.1)"
    msg "    ${CYAN}2${RESET}) Google            (8.8.8.8 / 8.8.4.4)"
    msg "    ${CYAN}3${RESET}) OpenDNS           (208.67.222.222 / 208.67.220.220)"
    msg "    ${CYAN}4${RESET}) DNSPod            (119.29.29.29 / 119.28.28.28)"
    msg "    ${CYAN}5${RESET}) DigitalOcean      (67.207.67.2 / 67.207.67.3)"
    msg "    ${CYAN}0${RESET}) Custom (enter manually)"
    msg ""

    local dns1="" dns2=""
    if [[ "$AUTO_YES" == true ]]; then
        # Default to Cloudflare in auto mode
        dns1="1.1.1.1"
        dns2="1.0.0.1"
    else
        read -rp "  Select [1]: " dns_choice
        case "${dns_choice:-1}" in
            1) dns1="1.1.1.1";         dns2="1.0.0.1" ;;
            2) dns1="8.8.8.8";         dns2="8.8.4.4" ;;
            3) dns1="208.67.222.222";  dns2="208.67.220.220" ;;
            4) dns1="119.29.29.29";    dns2="119.28.28.28" ;;
            5) dns1="67.207.67.2";     dns2="67.207.67.3" ;;
            0)
                read -rp "  Primary DNS: " dns1
                read -rp "  Secondary DNS (optional): " dns2
                ;;
            *) dns1="1.1.1.1"; dns2="1.0.0.1" ;;
        esac
    fi

    if [[ -z "$dns1" ]]; then
        msg_warn "No DNS server specified"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would set DNS to: ${dns1}${dns2:+ / $dns2}"
        return 0
    fi

    msg_step "Setting DNS to: ${dns1}${dns2:+ / $dns2}..."

    # --- Apply via systemd-resolved (Ubuntu / modern Debian) ---
    if systemctl is-active systemd-resolved &>/dev/null; then
        backup_file /etc/systemd/resolved.conf
        local dns_line="$dns1"
        [[ -n "$dns2" ]] && dns_line="$dns1 $dns2"

        # Update or insert DNS= and FallbackDNS= in resolved.conf
        if grep -q '^DNS=' /etc/systemd/resolved.conf 2>/dev/null; then
            sed -i "s/^DNS=.*/DNS=$dns_line/" /etc/systemd/resolved.conf
        elif grep -q '^#DNS=' /etc/systemd/resolved.conf 2>/dev/null; then
            sed -i "s/^#DNS=.*/DNS=$dns_line/" /etc/systemd/resolved.conf
        else
            sed -i "/^\[Resolve\]/a DNS=$dns_line" /etc/systemd/resolved.conf
        fi

        systemctl restart systemd-resolved &>/dev/null
        msg_ok "DNS configured via systemd-resolved"

    # --- Apply via NetworkManager (RHEL family) ---
    elif command_exists nmcli && systemctl is-active NetworkManager &>/dev/null; then
        local active_conn
        active_conn=$(nmcli -t -f NAME,TYPE connection show --active | grep -E ':ethernet|:wifi' | head -1 | cut -d: -f1)
        if [[ -n "$active_conn" ]]; then
            local dns_servers="$dns1"
            [[ -n "$dns2" ]] && dns_servers="$dns1 $dns2"
            nmcli connection modify "$active_conn" ipv4.dns "$dns_servers" &>/dev/null
            nmcli connection modify "$active_conn" ipv4.ignore-auto-dns yes &>/dev/null
            nmcli connection up "$active_conn" &>/dev/null
            msg_ok "DNS configured via NetworkManager ($active_conn)"
        else
            msg_warn "No active NetworkManager connection found — falling back to resolv.conf"
            backup_file /etc/resolv.conf
            {
                echo "# Generated by FTA Server Toolbox"
                echo "nameserver $dns1"
                [[ -n "$dns2" ]] && echo "nameserver $dns2"
            } > /etc/resolv.conf
            msg_ok "DNS written to /etc/resolv.conf"
        fi

    # --- Fallback: direct resolv.conf ---
    else
        backup_file /etc/resolv.conf
        {
            echo "# Generated by FTA Server Toolbox"
            echo "nameserver $dns1"
            [[ -n "$dns2" ]] && echo "nameserver $dns2"
        } > /etc/resolv.conf
        msg_ok "DNS written to /etc/resolv.conf"
    fi

    # --- Verify ---
    msg_step "Verifying DNS resolution..."
    if command_exists dig; then
        if dig +short +timeout=5 google.com @"$dns1" &>/dev/null; then
            msg_ok "DNS resolution verified"
        else
            msg_warn "DNS verification failed — check your network connectivity"
        fi
    elif command_exists nslookup; then
        if nslookup google.com "$dns1" &>/dev/null; then
            msg_ok "DNS resolution verified"
        else
            msg_warn "DNS verification failed — check your network connectivity"
        fi
    else
        msg_info "No dig/nslookup available — skipping verification"
    fi

    msg_done "DNS configuration complete"
}

# =============================================================================
# SECTION 18: FULL AUTO SETUP WIZARD
# =============================================================================

module_full_setup() {
    msg_header "🚀 Full Auto Setup Wizard"

    msg "  This wizard will guide you through a complete server setup."
    msg "  First, choose which components to include."
    msg ""

    # -------------------------------------------------------------------------
    # Phase 1: Collect user selections (always ask, even with --yes)
    # -------------------------------------------------------------------------
    # Core modules — included by default (Y)
    local do_update="Y" do_network="Y" do_modern="Y"
    local do_security="Y" do_tuning="Y" do_timezone="Y" do_dns="Y"
    # Optional modules — NOT included by default (N)
    local do_nodejs="N" do_docker="N" do_portainer="N" do_watchtower="N" do_swap="N"

    if [[ "$AUTO_YES" == true ]]; then
        # In --yes mode, run core modules automatically but still skip optional ones.
        # User must pass individual module names for optional services.
        msg "  ${BOLD}Core modules${RESET} (auto-included with --yes):"
        msg "    ✅ System Update & Essentials"
        msg "    ✅ Network Diagnostic Tools"
        msg "    ✅ Modern CLI Tools"
        msg "    ✅ Security Hardening"
        msg "    ✅ Performance Tuning"
        msg "    ✅ Timezone & NTP"
        msg "    ✅ DNS Configuration"
        msg ""
        msg "  ${BOLD}Optional modules${RESET} (skipped with --yes, run individually):"
        msg "    ⏭  Node.js         →  ./fta-toolbox.sh --yes nodejs"
        msg "    ⏭  Docker          →  ./fta-toolbox.sh --yes docker"
        msg "    ⏭  Portainer       →  ./fta-toolbox.sh --yes portainer"
        msg "    ⏭  Watchtower      →  ./fta-toolbox.sh --yes watchtower"
        msg "    ⏭  Swap            →  ./fta-toolbox.sh --yes swap"
        msg ""
    else
        msg "  ${BOLD}${CYAN}── Core Modules (recommended) ──${RESET}"
        msg ""
        confirm "  🔄 Update system & install essentials?" && do_update="Y" || do_update="N"
        confirm "  🌐 Install network diagnostic tools?" && do_network="Y" || do_network="N"
        confirm "  🛠️  Install modern CLI tools?" && do_modern="Y" || do_modern="N"
        confirm "  🔒 Apply security hardening?" && do_security="Y" || do_security="N"
        confirm "  ⚡ Apply performance tuning?" && do_tuning="Y" || do_tuning="N"
        confirm "  🕐 Configure timezone & NTP?" && do_timezone="Y" || do_timezone="N"
        confirm "  🌍 Configure DNS servers?" && do_dns="Y" || do_dns="N"

        msg ""
        msg "  ${BOLD}${CYAN}── Optional Services ──${RESET}"
        msg ""
        confirm "  💚 Install Node.js (LTS)?" "N" && do_nodejs="Y" || do_nodejs="N"
        confirm "  🐳 Install Docker Engine?" "N" && do_docker="Y" || do_docker="N"
        if [[ "$do_docker" == "Y" ]] || command_exists docker; then
            confirm "  🏗️  Deploy Portainer (Docker UI)?" "N" && do_portainer="Y" || do_portainer="N"
            confirm "  👀 Deploy Watchtower (auto-updater)?" "N" && do_watchtower="Y" || do_watchtower="N"
        fi
        confirm "  💾 Configure swap?" "N" && do_swap="Y" || do_swap="N"

        # Show summary
        msg ""
        msg "  ${BOLD}${CYAN}── Setup Plan ──${RESET}"
        msg ""
        [[ "$do_update" == "Y" ]]    && msg "    ✅ System Update"     || msg "    ⏭  System Update"
        [[ "$do_network" == "Y" ]]   && msg "    ✅ Network Tools"     || msg "    ⏭  Network Tools"
        [[ "$do_modern" == "Y" ]]    && msg "    ✅ Modern CLI Tools"  || msg "    ⏭  Modern CLI Tools"
        [[ "$do_nodejs" == "Y" ]]    && msg "    ✅ Node.js"           || msg "    ⏭  Node.js"
        [[ "$do_docker" == "Y" ]]     && msg "    ✅ Docker"            || msg "    ⏭  Docker"
        [[ "$do_portainer" == "Y" ]]  && msg "    ✅ Portainer"         || msg "    ⏭  Portainer"
        [[ "$do_watchtower" == "Y" ]] && msg "    ✅ Watchtower"        || msg "    ⏭  Watchtower"
        [[ "$do_security" == "Y" ]]   && msg "    ✅ Security"          || msg "    ⏭  Security"
        [[ "$do_tuning" == "Y" ]]    && msg "    ✅ Performance"       || msg "    ⏭  Performance"
        [[ "$do_timezone" == "Y" ]]  && msg "    ✅ Timezone"          || msg "    ⏭  Timezone"
        [[ "$do_dns" == "Y" ]]       && msg "    ✅ DNS"               || msg "    ⏭  DNS"
        [[ "$do_swap" == "Y" ]]      && msg "    ✅ Swap"              || msg "    ⏭  Swap"
        msg ""

        if ! confirm "Proceed with this plan?"; then
            msg_info "Wizard cancelled"
            return 0
        fi
    fi

    # -------------------------------------------------------------------------
    # Phase 2: Execute selected modules
    # -------------------------------------------------------------------------
    # Enable wizard mode so module entry-guard confirms are auto-accepted,
    # but configuration prompts (timezone, node version, swap size) still appear.
    local saved_wizard="$WIZARD_ACTIVE"
    WIZARD_ACTIVE=true

    local step=0 total=0
    [[ "$do_update" == "Y" ]]    && ((total++))
    [[ "$do_network" == "Y" ]]   && ((total++))
    [[ "$do_modern" == "Y" ]]    && ((total++))
    [[ "$do_nodejs" == "Y" ]]    && ((total++))
    [[ "$do_docker" == "Y" ]]     && ((total++))
    [[ "$do_portainer" == "Y" ]]  && ((total++))
    [[ "$do_watchtower" == "Y" ]] && ((total++))
    [[ "$do_security" == "Y" ]]   && ((total++))
    [[ "$do_tuning" == "Y" ]]    && ((total++))
    [[ "$do_timezone" == "Y" ]]  && ((total++))
    [[ "$do_dns" == "Y" ]]       && ((total++))
    [[ "$do_swap" == "Y" ]]      && ((total++))

    if [[ "$do_update" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: System Update ━━━${RESET}"
        module_update_system
    fi
    if [[ "$do_network" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Network Tools ━━━${RESET}"
        module_network_tools
    fi
    if [[ "$do_modern" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Modern CLI Tools ━━━${RESET}"
        module_modern_tools
    fi
    if [[ "$do_nodejs" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Node.js ━━━${RESET}"
        module_nodejs
    fi
    if [[ "$do_docker" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Docker Engine ━━━${RESET}"
        module_docker
    fi
    if [[ "$do_portainer" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Portainer ━━━${RESET}"
        if command_exists docker; then
            module_portainer
        else
            msg_info "Docker not installed — skipping Portainer"
        fi
    fi
    if [[ "$do_watchtower" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Watchtower ━━━${RESET}"
        if command_exists docker; then
            module_watchtower
        else
            msg_info "Docker not installed — skipping Watchtower"
        fi
    fi
    if [[ "$do_security" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Security Hardening ━━━${RESET}"
        module_security
    fi
    if [[ "$do_tuning" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Performance Tuning ━━━${RESET}"
        module_performance
    fi
    if [[ "$do_timezone" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Timezone & NTP ━━━${RESET}"
        module_timezone
    fi
    if [[ "$do_dns" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: DNS Configuration ━━━${RESET}"
        module_dns
    fi
    if [[ "$do_swap" == "Y" ]]; then
        ((step++)); msg ""; msg "  ${BOLD}${CYAN}━━━ Step ${step}/${total}: Swap ━━━${RESET}"
        module_swap
    fi

    WIZARD_ACTIVE="$saved_wizard"

    msg ""
    msg_header "🎉 Setup Complete!"
    msg ""
    msg "  Your server has been configured with the FTA Server Toolbox."
    msg "  ${YELLOW}Please review the changes and reboot when convenient.${RESET}"
    msg ""
    msg "  ${DIM}Log file: ${LOG_FILE}${RESET}"
    if [[ -n "${BACKUP_DIR:-}" ]]; then
        msg "  ${DIM}Backups: ${BACKUP_DIR}${RESET}"
    fi
    msg ""
}

# =============================================================================
# SECTION 19: SELF-UPDATE
# =============================================================================

self_update() {
    msg_header "📦 Self-Update"

    if [[ "$DRY_RUN" == true ]]; then
        msg_info "[DRY-RUN] Would download latest version from GitHub"
        return 0
    fi

    msg_step "Checking for updates..."
    ensure_tmp
    local new_script="$TMP_DIR/fta-toolbox-new.sh"

    if ! download_file "$SELF_URL" "$new_script"; then
        msg_err "Failed to download latest version"
        return 1
    fi

    # Check if file is valid (has our header)
    if ! grep -q "TOOLBOX_VERSION" "$new_script"; then
        msg_err "Downloaded file does not appear to be valid"
        return 1
    fi

    local new_version
    new_version=$(grep -m1 'readonly TOOLBOX_VERSION=' "$new_script" | cut -d'"' -f2)

    if [[ "$new_version" == "$TOOLBOX_VERSION" ]]; then
        msg_ok "Already running the latest version ($TOOLBOX_VERSION)"
        return 0
    fi

    msg_info "New version available: $new_version (current: $TOOLBOX_VERSION)"
    if confirm "Update to v${new_version}?"; then
        local self_path
        self_path=$(readlink -f "$0")
        cp "$new_script" "$self_path"
        chmod +x "$self_path"
        msg_ok "Updated to v${new_version}"
        msg_info "Please restart the script to use the new version"
        exit 0
    fi
}

# =============================================================================
# SECTION 20: MENU SYSTEM
# =============================================================================

show_menu() {
    clear 2>/dev/null || true
    msg_banner

    msg "    ${BOLD}1${RESET})  📋  System Information"
    msg "    ${BOLD}2${RESET})  🔄  Update System & Essentials"
    msg "    ${BOLD}3${RESET})  🌐  Network Diagnostic Tools"
    msg "    ${BOLD}4${RESET})  🛠️   Modern CLI Tools"
    msg "    ${BOLD}5${RESET})  💚  Node.js (LTS)"
    msg "    ${BOLD}6${RESET})  🐳  Docker Engine"
    msg "    ${BOLD}7${RESET})  🏗️   Portainer (Docker UI)"
    msg "    ${BOLD}8${RESET})  👀  Watchtower (Auto-updater)"
    msg "    ${BOLD}9${RESET})  🔒  Security Hardening"
    msg "   ${BOLD}10${RESET})  ⚡  Performance Tuning"
    msg "   ${BOLD}11${RESET})  🕐  Timezone & NTP"
    msg "   ${BOLD}12${RESET})  💾  Swap Management"
    msg "   ${BOLD}13${RESET})  🌍  DNS Configuration"
    msg ""
    msg "    ${DIM}─────────────────────────────────────${RESET}"
    msg "   ${BOLD}88${RESET})  🚀  ${GREEN}Full Auto Setup${RESET}"
    msg "   ${BOLD}99${RESET})  📦  Self-Update Script"
    msg "    ${BOLD}0${RESET})  🚪  Exit"
    msg ""
}

handle_choice() {
    local choice=$1
    case "$choice" in
        1)  show_system_info ;;
        2)  module_update_system ;;
        3)  module_network_tools ;;
        4)  module_modern_tools ;;
        5)  module_nodejs ;;
        6)  module_docker ;;
        7)  module_portainer ;;
        8)  module_watchtower ;;
        9)  module_security ;;
        10) module_performance ;;
        11) module_timezone ;;
        12) module_swap ;;
        13) module_dns ;;
        88) module_full_setup ;;
        99) self_update ;;
        0|q|Q|exit)
            msg ""
            msg "  ${GREEN}👋 Goodbye! Happy serving!${RESET}"
            msg ""
            exit 0
            ;;
        *)
            msg_warn "Invalid option: $choice"
            ;;
    esac
}

menu_loop() {
    while true; do
        show_menu
        read -rp "  Select an option: " choice
        handle_choice "$choice"
        press_enter
    done
}

# =============================================================================
# SECTION 21: CLI ARGUMENT PARSING & MAIN
# =============================================================================

show_help() {
    cat << 'HELP_EOF'

  🧰 FTA Server Toolbox — Usage

  USAGE:
    fta-toolbox.sh [OPTIONS] [MODULE]

  OPTIONS:
    -h, --help       Show this help message
    -v, --version    Show version
    -y, --yes        Skip all confirmation prompts (auto-accept defaults)
    --dry-run        Preview changes without executing

  MODULES (run non-interactively):
    info             Show system information
    update           Update system & install essential packages
    network          Install network diagnostic tools
    modern           Install modern CLI tools
    nodejs           Install Node.js LTS
    docker           Install Docker Engine
    portainer        Deploy Portainer (Docker UI)
    watchtower       Deploy Watchtower (auto-updater)
    security         Apply security hardening
    tuning           Apply performance tuning
    timezone         Configure timezone & NTP
    swap             Configure swap
    dns              Configure DNS servers
    full             Run full setup wizard

  EXAMPLES:
    # Interactive mode (menu)
    sudo ./fta-toolbox.sh

    # Install modern tools non-interactively
    sudo ./fta-toolbox.sh --yes modern

    # Full setup with auto-accept
    sudo ./fta-toolbox.sh --yes full

    # Preview what full setup would do
    sudo ./fta-toolbox.sh --dry-run --yes full

HELP_EOF
}

main() {
    # Parse arguments (inline to avoid subshell losing variable changes)
    local module=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "$TOOLBOX_NAME v$TOOLBOX_VERSION"
                exit 0
                ;;
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            info|update|network|modern|nodejs|docker|portainer|watchtower|security|tuning|timezone|swap|dns|full)
                module="$1"
                shift
                ;;
            *)
                msg_err "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Pre-flight checks
    ensure_root
    detect_os

    # Initialize log
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    log "=== FTA Server Toolbox v${TOOLBOX_VERSION} started ==="
    log "OS: $OS_PRETTY | Arch: $ARCH | User: $(whoami)"

    # Check internet connectivity
    if ! check_internet; then
        msg_warn "Limited internet — some features may not work"
    fi

    # DRY-RUN notice
    if [[ "$DRY_RUN" == true ]]; then
        msg ""
        msg "  ${YELLOW}${BOLD}🔍 DRY-RUN MODE — No changes will be made${RESET}"
        msg ""
    fi

    # Run specific module or show menu
    if [[ -n "$module" ]]; then
        case "$module" in
            info)      show_system_info ;;
            update)    module_update_system ;;
            network)   module_network_tools ;;
            modern)    module_modern_tools ;;
            nodejs)    module_nodejs ;;
            docker)    module_docker ;;
            portainer)   module_portainer ;;
            watchtower)  module_watchtower ;;
            security)    module_security ;;
            tuning)    module_performance ;;
            timezone)  module_timezone ;;
            swap)      module_swap ;;
            dns)       module_dns ;;
            full)      module_full_setup ;;
        esac
    else
        menu_loop
    fi
}

# --- Entry Point ---
main "$@"
