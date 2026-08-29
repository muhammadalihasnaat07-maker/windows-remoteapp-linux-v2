#!/usr/bin/env bash
set -Eeuo pipefail

MIN_FREERDP_VERSION="3.26.0"
MODE="${1:---check}"

case "$MODE" in
    --check|--install)
        ;;
    *)
        echo "Usage: $0 [--check|--install]" >&2
        exit 2
        ;;
esac

if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: /etc/os-release not found." >&2
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "parrot" &&
      "${ID:-}" != "debian" &&
      "${ID:-}" != "ubuntu" &&
      "${ID:-}" != "kali" &&
      "${ID_LIKE:-}" != *debian* ]]; then
    echo "ERROR: This installer currently supports Debian-family systems only." >&2
    exit 1
fi

if ! command -v apt-cache >/dev/null 2>&1; then
    echo "ERROR: apt-cache is required." >&2
    exit 1
fi

if ! command -v dpkg >/dev/null 2>&1; then
    echo "ERROR: dpkg is required." >&2
    exit 1
fi

if [[ "$MODE" == "--install" && "$EUID" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo "ERROR: sudo is required for installation." >&2
        exit 1
    fi
fi

if [[ "$EUID" -eq 0 ]]; then
    SUDO=()
    TARGET_USER="${SUDO_USER:-root}"
else
    SUDO=(sudo)
    TARGET_USER="$USER"
fi

READY=0
ACTION=0
ERRORS=0

ready() {
    printf 'READY   %-28s %s\n' "$1" "${2:-}"
    READY=$((READY + 1))
}

action() {
    printf 'ACTION  %-28s %s\n' "$1" "${2:-}"
    ACTION=$((ACTION + 1))
}

error() {
    printf 'ERROR   %-28s %s\n' "$1" "${2:-}"
    ERRORS=$((ERRORS + 1))
}

version_ge() {
    dpkg --compare-versions "$1" ge "$2"
}

upstream_major() {
    local version="$1"

    # Remove Debian epoch if present.
    version="${version#*:}"

    printf '%s\n' "$version" |
        grep -Eo '^[0-9]+' |
        head -n1
}

highest_available_version() {
    local package="$1"
    local best=""
    local version=""

    while read -r version; do
        [[ -z "$version" ]] && continue
        [[ "$version" == "(none)" ]] && continue

        if [[ -z "$best" ]] ||
           dpkg --compare-versions "$version" gt "$best"; then
            best="$version"
        fi
    done < <(
        apt-cache madison "$package" 2>/dev/null |
        awk '{print $3}'
    )

    if [[ -z "$best" ]]; then
        best="$(
            apt-cache policy "$package" 2>/dev/null |
            awk '/Candidate:/ {print $2; exit}'
        )"

        [[ "$best" == "(none)" ]] && best=""
    fi

    printf '%s' "$best"
}

find_compose_package() {
    local package version major

    for package in docker-compose-plugin docker-compose; do
        version="$(highest_available_version "$package")"

        [[ -z "$version" ]] && continue

        major="$(upstream_major "$version")"

        if [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 2 )); then
            printf '%s|%s' "$package" "$version"
            return 0
        fi
    done

    return 1
}

find_freerdp_package() {
    local package version upstream

    for package in freerdp3-x11 freerdp-x11; do
        version="$(highest_available_version "$package")"

        [[ -z "$version" ]] && continue

        upstream="$(
            printf '%s\n' "${version#*:}" |
            grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+' |
            head -n1
        )"

        [[ -z "$upstream" ]] && continue

        if version_ge "$upstream" "$MIN_FREERDP_VERSION"; then
            printf '%s|%s|%s' "$package" "$version" "$upstream"
            return 0
        fi
    done

    return 1
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Dependencies'
echo '============================================================'
echo
echo "Mode: $MODE"
echo "OS: ${PRETTY_NAME:-${NAME:-unknown}}"
echo

# ------------------------------------------------------------
# Docker
# ------------------------------------------------------------

DOCKER_NEEDED=0

if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION="$(docker --version 2>/dev/null | head -n1)"
    ready "Docker" "$DOCKER_VERSION"
else
    DOCKER_NEEDED=1

    DOCKER_PACKAGE_VERSION="$(highest_available_version docker.io)"

    if [[ -n "$DOCKER_PACKAGE_VERSION" ]]; then
        action "Docker" \
            "install docker.io $DOCKER_PACKAGE_VERSION"
    else
        error "Docker" "docker.io unavailable from configured repositories"
    fi
fi

# ------------------------------------------------------------
# Docker Compose v2
# ------------------------------------------------------------

COMPOSE_NEEDED=0
COMPOSE_PACKAGE=""
COMPOSE_PACKAGE_VERSION=""

if command -v docker >/dev/null 2>&1 &&
   docker compose version >/dev/null 2>&1; then

    COMPOSE_VERSION="$(
        docker compose version --short 2>/dev/null ||
        docker compose version 2>/dev/null |
        grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' |
        head -n1
    )"

    COMPOSE_MAJOR="$(
        printf '%s\n' "$COMPOSE_VERSION" |
        grep -Eo '^[0-9]+' |
        head -n1
    )"

    if [[ "$COMPOSE_MAJOR" =~ ^[0-9]+$ ]] &&
       (( COMPOSE_MAJOR >= 2 )); then
        ready "Docker Compose" "v$COMPOSE_VERSION"
    else
        COMPOSE_NEEDED=1
    fi
else
    COMPOSE_NEEDED=1
fi

if (( COMPOSE_NEEDED == 1 )); then
    if COMPOSE_RESULT="$(find_compose_package)"; then
        IFS='|' read -r \
            COMPOSE_PACKAGE \
            COMPOSE_PACKAGE_VERSION \
            <<< "$COMPOSE_RESULT"

        action "Docker Compose" \
            "install $COMPOSE_PACKAGE $COMPOSE_PACKAGE_VERSION"
    else
        error "Docker Compose" \
            "no Compose v2 package found in configured repositories"
    fi
fi

# ------------------------------------------------------------
# FreeRDP >= 3.26
# ------------------------------------------------------------

FREERDP_NEEDED=0
FREERDP_PACKAGE=""
FREERDP_PACKAGE_VERSION=""

FREERDP_BIN=""

if command -v xfreerdp3 >/dev/null 2>&1; then
    FREERDP_BIN="$(command -v xfreerdp3)"
elif command -v xfreerdp >/dev/null 2>&1; then
    FREERDP_BIN="$(command -v xfreerdp)"
fi

if [[ -n "$FREERDP_BIN" ]]; then
    FREERDP_VERSION="$(
        "$FREERDP_BIN" /version 2>&1 |
        grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' |
        head -n1
    )"

    if [[ -n "$FREERDP_VERSION" ]] &&
       version_ge "$FREERDP_VERSION" "$MIN_FREERDP_VERSION"; then
        ready "FreeRDP" \
            "$FREERDP_VERSION (>= $MIN_FREERDP_VERSION)"
    else
        FREERDP_NEEDED=1

        action "FreeRDP" \
            "${FREERDP_VERSION:-unknown} is below required $MIN_FREERDP_VERSION"
    fi
else
    FREERDP_NEEDED=1
    action "FreeRDP" "not installed"
fi

if (( FREERDP_NEEDED == 1 )); then
    if FREERDP_RESULT="$(find_freerdp_package)"; then
        IFS='|' read -r \
            FREERDP_PACKAGE \
            FREERDP_PACKAGE_VERSION \
            FREERDP_AVAILABLE_VERSION \
            <<< "$FREERDP_RESULT"

        action "FreeRDP package" \
            "$FREERDP_PACKAGE $FREERDP_PACKAGE_VERSION (upstream $FREERDP_AVAILABLE_VERSION)"
    else
        error "FreeRDP package" \
            "no version >= $MIN_FREERDP_VERSION found in configured repositories"
    fi
fi

# ------------------------------------------------------------
# Supporting utilities
# ------------------------------------------------------------

REQUIRED_UTILS=(
    curl
    git
    util-linux
)

INSTALL_UTILS=()

for package in "${REQUIRED_UTILS[@]}"; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null |
       grep -q 'install ok installed'; then
        ready "$package" "installed"
    else
        candidate="$(highest_available_version "$package")"

        if [[ -n "$candidate" ]]; then
            action "$package" "install $candidate"
            INSTALL_UTILS+=("$package")
        else
            error "$package" "package unavailable"
        fi
    fi
done

# ------------------------------------------------------------
# Check-only summary
# ------------------------------------------------------------

if [[ "$MODE" == "--check" ]]; then
    echo
    echo '============================================================'
    echo " READY:  $READY"
    echo " ACTION: $ACTION"
    echo " ERROR:  $ERRORS"
    echo '============================================================'

    if (( ERRORS > 0 )); then
        echo
        echo "Required dependency versions are unavailable."
        exit 1
    fi

    if (( ACTION > 0 )); then
        echo
        echo "Dependency changes are required."
        echo "Run:"
        echo "  ./scripts/install-dependencies.sh --install"
        exit 2
    fi

    echo
    echo "All required dependencies are already satisfied."
    exit 0
fi

# ------------------------------------------------------------
# Install mode
# ------------------------------------------------------------

if (( ERRORS > 0 )); then
    echo
    echo "Cannot install because one or more required packages"
    echo "are unavailable from the configured repositories."
    exit 1
fi

echo
echo '---------------- Installing dependencies ----------------'

"${SUDO[@]}" apt-get update

if (( DOCKER_NEEDED == 1 )); then
    "${SUDO[@]}" apt-get install -y docker.io
fi

if (( COMPOSE_NEEDED == 1 )); then
    "${SUDO[@]}" apt-get install -y \
        "${COMPOSE_PACKAGE}=${COMPOSE_PACKAGE_VERSION}"
fi

if (( FREERDP_NEEDED == 1 )); then
    "${SUDO[@]}" apt-get install -y \
        "${FREERDP_PACKAGE}=${FREERDP_PACKAGE_VERSION}"
fi

if (( ${#INSTALL_UTILS[@]} > 0 )); then
    "${SUDO[@]}" apt-get install -y "${INSTALL_UTILS[@]}"
fi

# ------------------------------------------------------------
# Docker service
# ------------------------------------------------------------

if command -v systemctl >/dev/null 2>&1; then
    "${SUDO[@]}" systemctl enable --now docker
fi

# ------------------------------------------------------------
# User permissions
# ------------------------------------------------------------

LOGIN_REFRESH_REQUIRED=0

if getent group docker >/dev/null 2>&1; then
    if ! id -nG "$TARGET_USER" |
         tr ' ' '\n' |
         grep -qx docker; then

        "${SUDO[@]}" usermod -aG docker "$TARGET_USER"
        LOGIN_REFRESH_REQUIRED=1

        echo "Added $TARGET_USER to docker group."
    fi
fi

if [[ -e /dev/kvm ]] &&
   getent group kvm >/dev/null 2>&1; then

    if ! id -nG "$TARGET_USER" |
         tr ' ' '\n' |
         grep -qx kvm; then

        "${SUDO[@]}" usermod -aG kvm "$TARGET_USER"
        LOGIN_REFRESH_REQUIRED=1

        echo "Added $TARGET_USER to kvm group."
    fi
fi

echo
echo '============================================================'
echo ' Dependency installation completed.'
echo '============================================================'

if (( LOGIN_REFRESH_REQUIRED == 1 )); then
    echo
    echo "IMPORTANT:"
    echo "Your group memberships changed."
    echo "Log out and back in before continuing."
fi

echo
echo "After installation/re-login, verify with:"
echo "  ./scripts/preflight.sh"
