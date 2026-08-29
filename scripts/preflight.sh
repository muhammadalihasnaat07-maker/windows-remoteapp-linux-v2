#!/usr/bin/env bash
set -u

MIN_FREERDP_VERSION="3.26.0"

PASS=0
WARN=0
FAIL=0

pass() {
    printf 'PASS  %-32s %s\n' "$1" "${2:-}"
    PASS=$((PASS + 1))
}

warn() {
    printf 'WARN  %-32s %s\n' "$1" "${2:-}"
    WARN=$((WARN + 1))
}

fail() {
    printf 'FAIL  %-32s %s\n' "$1" "${2:-}"
    FAIL=$((FAIL + 1))
}

version_ge() {
    local current="$1"
    local required="$2"

    [[ "$(printf '%s\n%s\n' "$required" "$current" | sort -V | head -n1)" == "$required" ]]
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - System Preflight'
echo '============================================================'
echo

# ------------------------------------------------------------
# OS
# ------------------------------------------------------------

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release

    OS_NAME="${PRETTY_NAME:-${NAME:-Unknown}}"

    if [[ "${ID:-}" == "parrot" ]] ||
       [[ "${ID:-}" == "debian" ]] ||
       [[ "${ID:-}" == "ubuntu" ]] ||
       [[ "${ID:-}" == "kali" ]] ||
       [[ "${ID_LIKE:-}" == *debian* ]]; then

        pass "Operating system" "$OS_NAME"
    else
        warn "Operating system" "$OS_NAME (not officially tested)"
    fi
else
    fail "Operating system" "/etc/os-release unavailable"
fi

# ------------------------------------------------------------
# Architecture
# ------------------------------------------------------------

ARCH="$(uname -m)"

if [[ "$ARCH" == "x86_64" ]]; then
    pass "Architecture" "$ARCH"
else
    fail "Architecture" "$ARCH (x86_64 required)"
fi

# ------------------------------------------------------------
# Hardware virtualization
# ------------------------------------------------------------

VIRT_FLAGS="$(grep -Eoc '(vmx|svm)' /proc/cpuinfo 2>/dev/null || true)"

if [[ "$VIRT_FLAGS" =~ ^[0-9]+$ ]] && (( VIRT_FLAGS > 0 )); then
    pass "Hardware virtualization" "$VIRT_FLAGS CPU flags detected"
else
    fail "Hardware virtualization" "VT-x/AMD-V not detected"
fi

# ------------------------------------------------------------
# KVM
# ------------------------------------------------------------

if [[ -e /dev/kvm ]]; then
    if [[ -r /dev/kvm && -w /dev/kvm ]]; then
        pass "/dev/kvm" "present and user-accessible"
    else
        fail "/dev/kvm" "present but current user lacks read/write access"
    fi
else
    fail "/dev/kvm" "missing"
fi

# ------------------------------------------------------------
# TUN
# ------------------------------------------------------------

if [[ -e /dev/net/tun ]]; then
    if [[ -r /dev/net/tun && -w /dev/net/tun ]]; then
        pass "/dev/net/tun" "present and user-accessible"
    else
        fail "/dev/net/tun" "present but not user-accessible"
    fi
else
    fail "/dev/net/tun" "missing"
fi

# ------------------------------------------------------------
# Desktop session
# ------------------------------------------------------------

SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"

if [[ "$SESSION_TYPE" == "x11" ]]; then
    pass "Desktop session" "X11"
else
    fail "Desktop session" "$SESSION_TYPE (X11 required for tested RemoteApp workflow)"
fi

# ------------------------------------------------------------
# Docker CLI
# ------------------------------------------------------------

if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION="$(docker --version 2>/dev/null | head -n1)"
    pass "Docker CLI" "$DOCKER_VERSION"
else
    fail "Docker CLI" "not installed"
fi

# ------------------------------------------------------------
# Docker daemon
# ------------------------------------------------------------

if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        pass "Docker daemon" "running and reachable"
        pass "Docker user access" "works without sudo"
    else
        fail "Docker daemon" "not running or current user cannot access it"
    fi
fi

# ------------------------------------------------------------
# Docker Compose v2
# ------------------------------------------------------------

if command -v docker >/dev/null 2>&1 &&
   docker compose version >/dev/null 2>&1; then

    COMPOSE_VERSION="$(docker compose version 2>/dev/null | head -n1)"

    if docker compose version --short >/dev/null 2>&1; then
        COMPOSE_MAJOR="$(docker compose version --short 2>/dev/null | cut -d. -f1)"

        if [[ "$COMPOSE_MAJOR" =~ ^[0-9]+$ ]] && (( COMPOSE_MAJOR >= 2 )); then
            pass "Docker Compose" "$COMPOSE_VERSION"
        else
            fail "Docker Compose" "$COMPOSE_VERSION (v2 required)"
        fi
    else
        pass "Docker Compose" "$COMPOSE_VERSION"
    fi
else
    fail "Docker Compose" "Compose v2 unavailable"
fi

# ------------------------------------------------------------
# FreeRDP
# ------------------------------------------------------------

FREERDP_BIN=""

if command -v xfreerdp3 >/dev/null 2>&1; then
    FREERDP_BIN="$(command -v xfreerdp3)"
elif command -v xfreerdp >/dev/null 2>&1; then
    FREERDP_BIN="$(command -v xfreerdp)"
fi

if [[ -n "$FREERDP_BIN" ]]; then
    FREERDP_OUTPUT="$("$FREERDP_BIN" /version 2>&1 | head -n1)"

    FREERDP_VERSION="$(
        printf '%s\n' "$FREERDP_OUTPUT" |
        grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' |
        head -n1
    )"

    if [[ -n "$FREERDP_VERSION" ]]; then
        if version_ge "$FREERDP_VERSION" "$MIN_FREERDP_VERSION"; then
            pass "FreeRDP" "$FREERDP_VERSION (>= $MIN_FREERDP_VERSION)"
        else
            fail "FreeRDP" "$FREERDP_VERSION (< $MIN_FREERDP_VERSION)"
        fi
    else
        fail "FreeRDP" "unable to determine version"
    fi
else
    fail "FreeRDP" "xfreerdp3/xfreerdp not installed"
fi

# ------------------------------------------------------------
# RAM
# ------------------------------------------------------------

RAM_GIB="$(awk '/MemTotal:/ {printf "%d", $2 / 1024 / 1024}' /proc/meminfo)"

if [[ "$RAM_GIB" =~ ^[0-9]+$ ]] && (( RAM_GIB >= 8 )); then
    pass "System RAM" "${RAM_GIB} GiB"
else
    warn "System RAM" "${RAM_GIB:-unknown} GiB (8+ GiB recommended)"
fi

# ------------------------------------------------------------
# Disk
# ------------------------------------------------------------

FREE_DISK_GIB="$(
    df --output=avail -BG "$HOME" 2>/dev/null |
    tail -n1 |
    tr -dc '0-9'
)"

if [[ "$FREE_DISK_GIB" =~ ^[0-9]+$ ]]; then
    if (( FREE_DISK_GIB >= 40 )); then
        pass "Free disk space" "${FREE_DISK_GIB} GiB"
    else
        fail "Free disk space" \
            "${FREE_DISK_GIB} GiB (minimum 40 GiB required)"
    fi
else
    fail "Free disk space" "unable to determine"
fi

# ------------------------------------------------------------
# Package candidates
# ------------------------------------------------------------

echo
echo '---------------- APT package candidates ----------------'

if command -v apt-cache >/dev/null 2>&1; then
    for pkg in \
        docker.io \
        docker-compose \
        docker-compose-plugin \
        freerdp3-x11 \
        freerdp-x11
    do
        CANDIDATE="$(
            apt-cache policy "$pkg" 2>/dev/null |
            awk '/Candidate:/ {print $2; exit}'
        )"

        if [[ -n "$CANDIDATE" && "$CANDIDATE" != "(none)" ]]; then
            printf '%-24s %s\n' "$pkg" "$CANDIDATE"
        else
            printf '%-24s %s\n' "$pkg" "not available"
        fi
    done
else
    echo "apt-cache not available; package candidate check skipped."
fi

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo '============================================================'
echo " PASS: $PASS"
echo " WARN: $WARN"
echo " FAIL: $FAIL"
echo '============================================================'

if (( FAIL > 0 )); then
    echo
    echo "System is NOT ready for Windows RemoteApp setup."
    echo "Resolve the FAIL items before continuing."
    exit 1
fi

echo
echo "System is ready for Windows RemoteApp setup."

if (( WARN > 0 )); then
    echo "Warnings should be reviewed, but they do not block setup."
fi

exit 0
