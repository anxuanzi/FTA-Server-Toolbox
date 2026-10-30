#!/usr/bin/env bash
# =============================================================================
# FTA Toolbox — Docker Test Runner
# Usage: ./test/run-tests.sh [centos9|centos10|fedora|ubuntu2404|ubuntu2604|all] [module]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ALL_TARGETS=(centos9 centos10 fedora ubuntu2404 ubuntu2604)

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

msg() { printf "%b\n" "$*"; }

build_image() {
    local name=$1
    local dockerfile=$2
    msg "${CYAN}▶${RESET} Building ${BOLD}${name}${RESET} image..."
    docker build -t "fta-test-${name}" \
        -f "${SCRIPT_DIR}/${dockerfile}" \
        "$PROJECT_DIR" \
        --quiet
    msg "${GREEN}✅${RESET} Image fta-test-${name} built"
}

run_test() {
    local name=$1
    local module=${2:-info}
    msg ""
    msg "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    msg "${BOLD} Testing: ${name} — module: ${module}${RESET}"
    msg "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    msg ""

    docker run --rm \
        "fta-test-${name}" \
        /root/fta-toolbox.sh --yes "$module"

    local rc=$?
    if [[ $rc -eq 0 ]]; then
        msg "${GREEN}✅ ${name} — ${module}: PASSED${RESET}"
    else
        msg "${RED}❌ ${name} — ${module}: FAILED (exit code: ${rc})${RESET}"
    fi
    return $rc
}

# Parse arguments
TARGET="${1:-all}"
MODULE="${2:-info}"

case "$TARGET" in
    centos9|centos10|fedora|ubuntu2404|ubuntu2604)
        build_image "$TARGET" "Dockerfile.${TARGET}"
        run_test "$TARGET" "$MODULE"
        ;;
    all)
        for t in "${ALL_TARGETS[@]}"; do
            build_image "$t" "Dockerfile.${t}"
        done
        for t in "${ALL_TARGETS[@]}"; do
            run_test "$t" "$MODULE"
        done
        ;;
    *)
        msg "Usage: $0 [centos9|centos10|fedora|ubuntu2404|ubuntu2604|all] [module]"
        msg "Modules: info, update, network, modern, nodejs, docker, portainer, watchtower, security, tuning, timezone, swap, dns, firewall, disk, full"
        exit 1
        ;;
esac
