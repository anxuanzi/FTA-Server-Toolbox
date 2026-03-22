#!/usr/bin/env bash
# =============================================================================
# FTA Toolbox — Docker Test Runner
# Usage: ./test/run-tests.sh [centos9|ubuntu2404|all] [module]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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
    centos9)
        build_image "centos9" "Dockerfile.centos9"
        run_test "centos9" "$MODULE"
        ;;
    centos10)
        build_image "centos10" "Dockerfile.centos10"
        run_test "centos10" "$MODULE"
        ;;
    ubuntu2404)
        build_image "ubuntu2404" "Dockerfile.ubuntu2404"
        run_test "ubuntu2404" "$MODULE"
        ;;
    all)
        build_image "centos9" "Dockerfile.centos9"
        build_image "centos10" "Dockerfile.centos10"
        build_image "ubuntu2404" "Dockerfile.ubuntu2404"
        run_test "centos9" "$MODULE"
        run_test "centos10" "$MODULE"
        run_test "ubuntu2404" "$MODULE"
        ;;
    *)
        msg "Usage: $0 [centos9|centos10|ubuntu2404|all] [module]"
        msg "Modules: info, update, network, modern, nodejs, security, tuning, timezone, full"
        exit 1
        ;;
esac
